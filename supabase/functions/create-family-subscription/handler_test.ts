import { createHandler } from "./handler.ts";

const userId = "00000000-0000-0000-0000-000000000001";
const config = {
  supabaseUrl: "https://auth.example",
  supabaseKey: "public-test-key",
  stripeSecretKey: "sk_test_fixture",
  stripePublishableKey: "pk_test_fixture",
  familyPrice: "price_fixture",
  communityPrice: "price_community",
};

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}

function setup() {
  const calls: Request[] = [];
  let customer = false;
  let subscription = false;
  const state = {
    authenticated: true,
    confirmed: true,
    amount: null as number | null,
    status: "incomplete",
    plan: "familia",
  };
  const payload = () => ({
    id: "sub_fixture",
    status: state.status,
    metadata: { plan: state.plan },
    latest_invoice: {
      confirmation_secret: { client_secret: "pi_fixture_secret_test" },
    },
  });
  const request: typeof fetch = async (input, init) => {
    const call = new Request(input, init);
    calls.push(call.clone());
    const url = new URL(call.url);
    if (url.host === "auth.example") {
      return Response.json({
        id: userId,
        email: "test@example.com",
        email_confirmed_at: state.confirmed ? "2026-11-01" : null,
      }, { status: state.authenticated ? 200 : 401 });
    }
    assert(call.headers.get("Authorization") === "Bearer sk_test_fixture");
    if (
      ["/v1/prices/price_fixture", "/v1/prices/price_community"].includes(
        url.pathname,
      )
    ) {
      return Response.json({
        active: true,
        livemode: false,
        currency: "mxn",
        unit_amount: state.amount ??
          (url.pathname.endsWith("price_community") ? 6900 : 3900),
        recurring: { interval: "month", interval_count: 1 },
      });
    }
    if (url.pathname === "/v1/customers/search") {
      assert(url.searchParams.get("query")?.includes(userId));
      return Response.json({ data: customer ? [{ id: "cus_fixture" }] : [] });
    }
    if (url.pathname === "/v1/customers") {
      const body = new URLSearchParams(await call.text());
      assert(body.get("metadata[supabase_user_id]") === userId);
      customer = true;
      return Response.json({ id: "cus_fixture" });
    }
    if (url.pathname === "/v1/customers/cus_fixture") {
      return Response.json({ id: "cus_fixture", deleted: false });
    }
    if (url.pathname === "/v1/subscriptions" && call.method === "GET") {
      assert(url.searchParams.get("customer") === "cus_fixture");
      return Response.json({ data: subscription ? [payload()] : [] });
    }
    if (url.pathname === "/v1/subscriptions" && call.method === "POST") {
      const body = new URLSearchParams(await call.text());
      const plan = body.get("metadata[plan]");
      assert(plan === "familia" || plan === "comunidad");
      assert(
        body.get("items[0][price]") ===
          (plan === "familia" ? "price_fixture" : "price_community"),
      );
      state.plan = plan;
      assert(body.get("payment_behavior") === "default_incomplete");
      assert(body.get("metadata[supabase_user_id]") === userId);
      assert(
        call.headers.get("Idempotency-Key") ===
          `casa-subscription-${userId}-cus_fixture-${
            subscription ? "sub_fixture" : "first"
          }`,
      );
      subscription = true;
      return Response.json(payload());
    }
    if (url.pathname === "/v1/subscriptions/sub_fixture") {
      return Response.json(payload());
    }
    throw new Error("Unexpected test request");
  };
  const handler = createHandler(config, request);
  const post = (action = "checkout", plan = "familia") =>
    handler(
      new Request("https://function.example", {
        method: "POST",
        headers: { Authorization: "Bearer user-session" },
        body: JSON.stringify({
          action,
          plan,
          amount: 1,
          customer: "cus_foreign",
          price: "price_foreign",
        }),
      }),
    );
  return { handler, request, post, state, calls };
}

Deno.test("Missing and invalid sessions cannot call Stripe", async () => {
  const test = setup();
  assert(
    (await test.handler(
      new Request("https://function.example", { method: "POST" }),
    )).status === 401,
  );
  assert(test.calls.length === 0);
  test.state.authenticated = false;
  assert((await test.post()).status === 401);
  test.state.authenticated = true;
  test.state.confirmed = false;
  assert((await test.post()).status === 403);
  assert(test.calls.every((call) => call.url.startsWith(config.supabaseUrl)));
});

Deno.test("Only test credentials and the advertised monthly price are accepted", async () => {
  const test = setup();
  const live = createHandler(
    { ...config, stripeSecretKey: "sk_live_fixture" },
    test.request,
  );
  assert(
    (await live(
      new Request("https://function.example", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
      }),
    )).status === 503,
  );
  test.state.amount = 1;
  assert((await test.post()).status === 503);
  assert(test.calls.every((call) => call.method === "GET"));
});

Deno.test("Server selects identity and price and reuses an incomplete subscription", async () => {
  const test = setup();
  const first = await test.post();
  assert(first.status === 200);
  assert(first.headers.get("Cache-Control") === "no-store");
  const body = await first.json();
  assert(body.clientSecret === "pi_fixture_secret_test");
  assert(body.publishableKey === "pk_test_fixture");
  assert(!JSON.stringify(body).includes(config.stripeSecretKey));
  assert((await test.post()).status === 200);
  assert(
    test.calls.filter((call) =>
      call.method === "POST" && call.url.endsWith("/subscriptions")
    ).length === 1,
  );
  test.state.status = "active";
  const active = await (await test.post()).json();
  assert(active.status === "active" && !active.clientSecret);
});

Deno.test("Transport and provider errors return a safe message", async () => {
  const handler = createHandler(
    config,
    () => Promise.reject(new Error("sensitive-body")),
  );
  const response = await handler(
    new Request("https://function.example", {
      method: "POST",
      headers: { Authorization: "Bearer test" },
    }),
  );
  assert(response.status === 502);
  assert(!(await response.text()).includes("sensitive-body"));
});

Deno.test("Status is read-only and follows active plans and cancellation", async () => {
  const test = setup();
  assert((await (await test.post("status")).json()).plan === "casa");
  assert(test.calls.every((call) => call.method === "GET"));
  await test.post();
  for (const plan of ["familia", "comunidad"]) {
    test.state.status = "active";
    test.state.plan = plan;
    const start = test.calls.length;
    const response = await test.post("status");
    assert(response.status === 200);
    const body = await response.json();
    assert(body.plan === plan && !body.clientSecret);
    assert(test.calls.slice(start).every((call) => call.method === "GET"));
  }
  for (const status of ["canceled", "incomplete", "past_due"]) {
    test.state.status = status;
    assert((await (await test.post("status")).json()).plan === "casa");
  }
  assert((await test.post("unsupported")).status === 400);
});

Deno.test("Comunidad uses its server price and reuses its pending invoice", async () => {
  const test = setup();
  assert((await test.post("checkout", "comunidad")).status === 200);
  assert(test.state.plan === "comunidad");
  assert((await test.post("checkout", "comunidad")).status === 200);
  assert(
    test.calls.filter((call) =>
      call.method === "POST" && call.url.endsWith("/subscriptions")
    ).length === 1,
  );
  test.state.status = "active";
  assert((await (await test.post("status")).json()).plan === "comunidad");
});

Deno.test("Either active plan blocks subscribing to the other plan on the server", async () => {
  for (
    const [first, other] of [["familia", "comunidad"], ["comunidad", "familia"]]
  ) {
    const test = setup();
    await test.post("checkout", first);
    test.state.status = "active";
    const start = test.calls.length;
    const body = await (await test.post("checkout", other)).json();
    assert(
      body.status === "active" && body.plan === first && !body.clientSecret,
    );
    assert(test.calls.slice(start).every((call) => call.method === "GET"));
    test.state.status = "trialing";
    assert(
      (await (await test.post("checkout", other)).json()).status === "active",
    );
  }
});

Deno.test("Pending or delinquent plans require review; canceled plans allow a new subscription", async () => {
  const test = setup();
  await test.post();
  for (const status of ["incomplete", "past_due", "unpaid", "paused"]) {
    test.state.status = status;
    const start = test.calls.length;
    assert((await test.post("checkout", "comunidad")).status === 409);
    assert(test.calls.slice(start).every((call) => call.method === "GET"));
  }
  test.state.status = "canceled";
  assert((await test.post("checkout", "comunidad")).status === 200);
  assert(test.state.plan === "comunidad");
});

Deno.test("Invalid plans, missing price and incorrect Comunidad amount cannot create a subscription", async () => {
  const test = setup();
  assert((await test.post("checkout", "casa")).status === 400);
  assert((await test.post("checkout", "unknown")).status === 400);
  const missing = createHandler(
    { ...config, communityPrice: "" },
    test.request,
  );
  const response = await missing(
    new Request("https://function.example", {
      method: "POST",
      headers: { Authorization: "Bearer user-session" },
      body: JSON.stringify({ plan: "comunidad" }),
    }),
  );
  assert(response.status === 503);
  test.state.amount = 3900;
  assert((await test.post("checkout", "comunidad")).status === 503);
  assert(test.calls.every((call) => call.method === "GET"));
});

Deno.test("Deleted customers can be recreated repeatedly without replaying old subscriptions", async () => {
  const customers = new Map<string, boolean>();
  const subscriptions = new Map<string, object>();
  const cache = new Map<string, { body: string; response: object }>();
  let subscriptionCreates = 0;
  const request: typeof fetch = async (input, init) => {
    const call = new Request(input, init);
    const url = new URL(call.url);
    if (url.host === "auth.example") {
      return Response.json({
        id: userId,
        email: "test@example.com",
        email_confirmed_at: "2026-11-01",
      });
    }
    if (url.pathname.startsWith("/v1/prices/")) {
      return Response.json({
        active: true,
        livemode: false,
        currency: "mxn",
        unit_amount: url.pathname.endsWith("price_community") ? 6900 : 3900,
        recurring: { interval: "month", interval_count: 1 },
      });
    }
    if (url.pathname === "/v1/customers/search") {
      const customer = [...customers].find(([, deleted]) => !deleted);
      return Response.json({ data: customer ? [{ id: customer[0] }] : [] });
    }
    if (url.pathname.startsWith("/v1/customers/")) {
      const id = url.pathname.split("/").pop()!;
      assert(customers.has(id));
      return Response.json({ id, deleted: customers.get(id) });
    }
    if (url.pathname === "/v1/subscriptions" && call.method === "GET") {
      const id = url.searchParams.get("customer")!;
      if (customers.get(id)) {
        return Response.json({ error: "deleted customer" }, { status: 400 });
      }
      return Response.json({
        data: subscriptions.has(id) ? [subscriptions.get(id)] : [],
      });
    }
    if (call.method === "POST") {
      const key = call.headers.get("Idempotency-Key")!;
      const body = await call.text();
      const previous = cache.get(key);
      if (previous) {
        // Stripe returns the original body even after the object has been deleted.
        if (previous.body !== body) {
          return Response.json({ error: "idempotency mismatch" }, {
            status: 400,
          });
        }
        return Response.json(previous.response);
      }
      let response: object;
      if (url.pathname === "/v1/customers") {
        const id = `cus_${customers.size + 1}`;
        customers.set(id, false);
        response = { id };
      } else {
        assert(url.pathname === "/v1/subscriptions");
        const params = new URLSearchParams(body);
        const id = params.get("customer")!;
        assert(customers.get(id) === false);
        subscriptionCreates++;
        response = {
          id: `sub_${subscriptionCreates}`,
          status: "active",
          metadata: { plan: params.get("metadata[plan]") },
          latest_invoice: {
            confirmation_secret: { client_secret: `pi_${id}_secret_test` },
          },
        };
        subscriptions.set(id, response);
      }
      cache.set(key, { body, response });
      return Response.json(response);
    }
    throw new Error("Unexpected request");
  };
  const handler = createHandler(config, request);
  const post = (action: string, plan = "familia") =>
    handler(
      new Request("https://function.example", {
        method: "POST",
        headers: { Authorization: "Bearer user-session" },
        body: JSON.stringify({ action, plan }),
      }),
    );
  for (const [index, plan] of ["familia", "comunidad", "familia"].entries()) {
    const response = await post("checkout", plan);
    assert(response.status === 200, `Checkout failed after ${index} deletions`);
    const body = await response.json();
    assert(body.clientSecret === `pi_cus_${index + 1}_secret_test`);
    assert(subscriptionCreates === index + 1);
    // Reopening while active must not create another customer or subscription.
    assert((await (await post("checkout", plan)).json()).status === "active");
    assert(customers.size === index + 1 && subscriptionCreates === index + 1);
    customers.set(`cus_${index + 1}`, true);
    assert((await (await post("status")).json()).plan === "casa");
  }
});
