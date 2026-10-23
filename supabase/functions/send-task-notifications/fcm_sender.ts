import type { PushJob, PushSender } from "./handler.ts";

export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll(
    "/",
    "_",
  ).replaceAll("=", "");
}

export function buildMessage(job: PushJob, token: string) {
  const body = job.kind === "reminder"
    ? "Hoy todavía no tienes tareas pendientes o aprobadas. ¡Anímate a sumar en casa!"
    : job.kind === "submitted"
    ? "Hay una nueva tarea por revisar."
    : job.kind === "approved"
    ? "Una de tus tareas fue aprobada. ¡Tu esfuerzo suma!"
    : "Una de tus tareas fue rechazada. Consulta tu actividad.";
  const expiresAt = job.expires_at
    ? Date.parse(job.expires_at)
    : Date.now() + 86400000;
  const ttl = Math.max(
    0,
    Math.min(86400, Math.floor((expiresAt - Date.now()) / 1000)),
  );
  return {
    message: {
      // El SDK Flutter actual registra FIDs para los envíos directos de FCM v1.
      fid: token,
      notification: { title: "Casa en Juego", body },
      data: {
        notification_id: job.id,
        kind: job.kind,
        recipient_id: job.recipient_id,
      },
      android: {
        priority: "high",
        ttl: `${ttl}s`,
        notification: {
          tag: job.id,
          icon: "ic_notification",
          color: "#CBBDF8",
        },
      },
      apns: {
        headers: {
          "apns-collapse-id": job.id,
          "apns-expiration": String(Math.floor(expiresAt / 1000)),
        },
        payload: { aps: { sound: "default" } },
      },
    },
  };
}

export class FcmSender implements PushSender {
  private accessToken?: { value: string; expiresAt: number };
  private authorization?: Promise<string>;
  constructor(
    private account: ServiceAccount,
    private request: typeof fetch = fetch,
  ) {}

  private async authorize(): Promise<string> {
    if (this.accessToken && this.accessToken.expiresAt > Date.now()) {
      return this.accessToken.value;
    }
    if (this.authorization) return this.authorization;
    this.authorization = this.exchangeToken();
    try {
      return await this.authorization;
    } finally {
      this.authorization = undefined;
    }
  }

  private async exchangeToken(): Promise<string> {
    const encoder = new TextEncoder();
    const now = Math.floor(Date.now() / 1000);
    const header = base64Url(
      encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
    );
    const claims = base64Url(encoder.encode(JSON.stringify({
      iss: this.account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })));
    const pem = this.account.private_key.replace(/-----[^-]+-----/g, "")
      .replace(/\s/g, "");
    const key = await crypto.subtle.importKey(
      "pkcs8",
      Uint8Array.from(atob(pem), (char) => char.charCodeAt(0)),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const signingInput = `${header}.${claims}`;
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      encoder.encode(signingInput),
    );
    const response = await this.request("https://oauth2.googleapis.com/token", {
      method: "POST",
      signal: AbortSignal.timeout(10000),
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: `${signingInput}.${base64Url(new Uint8Array(signature))}`,
      }),
    });
    if (!response.ok) throw new Error("oauth_failed");
    const data = await response.json();
    if (
      typeof data.access_token !== "string" ||
      !Number.isFinite(data.expires_in) || data.expires_in <= 60
    ) throw new Error("oauth_invalid");
    this.accessToken = {
      value: data.access_token,
      expiresAt: Date.now() + (data.expires_in - 60) * 1000,
    };
    return data.access_token;
  }

  async send(
    job: PushJob,
    token: string,
  ): Promise<"sent" | "unregistered" | "retry" | "failed"> {
    const authorization = await this.authorize();
    const response = await this.request(
      `https://fcm.googleapis.com/v1/projects/${
        encodeURIComponent(this.account.project_id)
      }/messages:send`,
      {
        method: "POST",
        signal: AbortSignal.timeout(10000),
        headers: {
          Authorization: `Bearer ${authorization}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(buildMessage(job, token)),
      },
    );
    if (response.ok) return "sent";
    const data = await response.json().catch(() => ({}));
    const details = data.error?.details;
    if (
      Array.isArray(details) &&
      details.some((detail: { errorCode?: string }) =>
        ["UNREGISTERED", "INSTALLATION_ID_NOT_REGISTERED"].includes(
          detail.errorCode ?? "",
        )
      )
    ) return "unregistered";
    if ([401, 403, 429].includes(response.status) || response.status >= 500) {
      if (response.status === 401) this.accessToken = undefined;
      return "retry";
    }
    return "failed";
  }
}
