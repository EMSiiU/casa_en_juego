type Config = {
  supabaseUrl: string;
  supabaseKey: string;
  stripeSecretKey: string;
  stripePublishableKey: string;
  familyPrice: string;
};

type Subscription = {
  id: string;
  status: string;
  metadata: { plan?: string };
  latest_invoice?: { confirmation_secret?: { client_secret?: string } };
};

class PaymentError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

export function createHandler(config: Config, request: typeof fetch = fetch) {
  const json = (body: object, status = 200) =>
    Response.json(body, { status, headers: cors });

  async function stripe<T>(
    path: string,
    params: Record<string, string> = {},
    idempotencyKey?: string,
  ): Promise<T> {
    const form = new URLSearchParams(params);
    const response = await request(
      `https://api.stripe.com/v1/${path}${idempotencyKey ? "" : `?${form}`}`,
      {
        method: idempotencyKey ? "POST" : "GET",
        headers: {
          Authorization: `Bearer ${config.stripeSecretKey}`,
          "Stripe-Version": "2025-06-30.basil",
          "Content-Type": "application/x-www-form-urlencoded",
          ...(idempotencyKey ? { "Idempotency-Key": idempotencyKey } : {}),
        },
        body: idempotencyKey ? form : undefined,
        signal: AbortSignal.timeout(12000),
      },
    );
    if (!response.ok) {
      // Los errores de Stripe pueden incluir detalles de configuración privados.
      throw new PaymentError(
        502,
        "No pudimos preparar la suscripción de prueba. Revisa la configuración de Stripe.",
      );
    }
    return await response.json() as T;
  }

  return async (incoming: Request): Promise<Response> => {
    if (incoming.method === "OPTIONS") {
      return new Response(null, { headers: cors });
    }
    if (incoming.method !== "POST") {
      return json({ error: "Método no permitido." }, 405);
    }
    try {
      const authorization = incoming.headers.get("Authorization") ?? "";
      if (!authorization.startsWith("Bearer ")) {
        throw new PaymentError(401, "Inicia sesión para probar el pago.");
      }
      if (!config.supabaseUrl || !config.supabaseKey) {
        throw new PaymentError(
          503,
          "La configuración de acceso está incompleta.",
        );
      }
      const auth = await request(`${config.supabaseUrl}/auth/v1/user`, {
        headers: { Authorization: authorization, apikey: config.supabaseKey },
        signal: AbortSignal.timeout(8000),
      });
      if (!auth.ok) {
        throw new PaymentError(
          401,
          "Tu sesión venció. Vuelve a iniciar sesión.",
        );
      }
      const user = await auth.json() as {
        id?: string;
        email?: string;
        email_confirmed_at?: string;
      };
      if (
        !user.id || !/^[a-f0-9-]{36}$/i.test(user.id) ||
        !user.email_confirmed_at
      ) {
        throw new PaymentError(
          403,
          "Confirma tu correo antes de probar el pago.",
        );
      }
      if (
        !config.stripeSecretKey.startsWith("sk_test_") ||
        !config.stripePublishableKey.startsWith("pk_test_") ||
        !config.familyPrice.startsWith("price_")
      ) {
        throw new PaymentError(
          503,
          "Configura las tres credenciales de Stripe del entorno de pruebas.",
        );
      }

      const body = await incoming.text();
      let action: unknown;
      try {
        action = body ? JSON.parse(body)?.action ?? "checkout" : "checkout";
      } catch {
        throw new PaymentError(400, "Solicitud no válida.");
      }
      if (action !== "status" && action !== "checkout") {
        throw new PaymentError(400, "Acción no válida.");
      }
      if (action === "status") {
        // Consultar no crea clientes, facturas ni suscripciones.
        const customers = await stripe<{ data: { id: string }[] }>(
          "customers/search",
          { query: `metadata['supabase_user_id']:'${user.id}'`, limit: "1" },
        );
        if (!customers.data[0]) return json({ plan: "casa" });
        const subscriptions = await stripe<{ data: Subscription[] }>(
          "subscriptions",
          { customer: customers.data[0].id, status: "all", limit: "100" },
        );
        const current = subscriptions.data.find((item) =>
          ["familia", "comunidad"].includes(item.metadata.plan ?? "") &&
          ["active", "trialing"].includes(item.status)
        );
        return json({ plan: current?.metadata.plan ?? "casa" });
      }

      // El precio se elige en el servidor y se contrasta con la tarjeta de Planes.
      const price = await stripe<{
        active: boolean;
        livemode: boolean;
        currency: string;
        unit_amount: number;
        recurring?: { interval: string; interval_count: number };
      }>(`prices/${encodeURIComponent(config.familyPrice)}`);
      if (
        !price.active || price.livemode || price.currency !== "mxn" ||
        price.unit_amount !== 3900 || price.recurring?.interval !== "month" ||
        price.recurring.interval_count !== 1
      ) {
        throw new PaymentError(
          503,
          "El precio de Familia debe ser de prueba, activo y de $39 MXN al mes.",
        );
      }

      const customers = await stripe<{ data: { id: string }[] }>(
        "customers/search",
        {
          query: `metadata['supabase_user_id']:'${user.id}'`,
          limit: "1",
        },
      );
      const customer = customers.data[0] ??
        await stripe<{ id: string }>("customers", {
          "metadata[supabase_user_id]": user.id,
          ...(user.email ? { email: user.email } : {}),
        }, `casa-customer-${user.id}`);
      const subscriptions = await stripe<{ data: Subscription[] }>(
        "subscriptions",
        {
          customer: customer.id,
          status: "all",
          limit: "100",
        },
      );
      const previous = subscriptions.data.find((item) =>
        item.metadata.plan === "familia"
      );
      if (previous && ["active", "trialing"].includes(previous.status)) {
        return json({ status: "active", subscriptionId: previous.id });
      }
      if (
        previous &&
        !["incomplete", "incomplete_expired", "canceled"].includes(
          previous.status,
        )
      ) {
        throw new PaymentError(
          409,
          "La suscripción requiere revisión en el panel de pruebas de Stripe.",
        );
      }

      // Reutiliza la factura pendiente al reabrir la hoja o al repetir la solicitud.
      const subscription = previous?.status === "incomplete"
        ? await stripe<Subscription>(`subscriptions/${previous.id}`, {
          "expand[0]": "latest_invoice.confirmation_secret",
        })
        : await stripe<Subscription>("subscriptions", {
          customer: customer.id,
          "items[0][price]": config.familyPrice,
          payment_behavior: "default_incomplete",
          "payment_settings[payment_method_types][0]": "card",
          "payment_settings[save_default_payment_method]": "on_subscription",
          "metadata[plan]": "familia",
          "metadata[supabase_user_id]": user.id,
          "expand[0]": "latest_invoice.confirmation_secret",
        }, `casa-familia-${user.id}-${previous?.id ?? "first"}`);
      const clientSecret = subscription.latest_invoice?.confirmation_secret
        ?.client_secret;
      if (!clientSecret) {
        throw new PaymentError(
          409,
          "No hay un pago pendiente. Revisa la suscripción en Stripe.",
        );
      }
      return json({
        status: "incomplete",
        subscriptionId: subscription.id,
        clientSecret,
        publishableKey: config.stripePublishableKey,
      });
    } catch (error) {
      return error instanceof PaymentError
        ? json({ error: error.message }, error.status)
        : json({
          error:
            "No pudimos conectar con el servicio de pago. Intenta nuevamente.",
        }, 502);
    }
  };
}
