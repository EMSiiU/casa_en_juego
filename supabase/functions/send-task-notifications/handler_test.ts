import {
  createHandler,
  isRelevant,
  type PushContext,
  type PushJob,
  type PushSender,
  type PushStore,
} from "./handler.ts";
import { buildMessage, FcmSender } from "./fcm_sender.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const secret = "test-secret-with-at-least-thirty-two-characters";
const job: PushJob = {
  id: "job-id",
  device_id: "device-id",
  recipient_id: "reviewer",
  task_log_id: "log-id",
  kind: "submitted",
  attempts: 1,
  lease_id: "lease-id",
};
const context: PushContext = {
  token: "registered-fid",
  deviceUserId: "reviewer",
  notificationsEnabled: true,
  taskUserId: "author",
  taskStatus: "pending",
  seasonActive: true,
};

class FakeStore implements PushStore {
  jobs = [job];
  claims = 0;
  value: PushContext | null = context;
  updates: { status: string; error?: string }[] = [];
  removed: string[] = [];
  async claim() {
    this.claims++;
    return this.jobs;
  }
  async context() {
    return this.value;
  }
  async settle(
    _job: PushJob,
    status: "sent" | "skipped" | "pending" | "failed",
    error?: string,
  ) {
    this.updates.push({ status, error });
  }
  async removeDevice(_job: PushJob, token: string) {
    this.removed.push(token);
  }
}

function request(header = secret) {
  return new Request("https://worker.test", {
    method: "POST",
    headers: { "x-notification-secret": header },
  });
}

Deno.test("Unknown callers cannot claim jobs even with a valid-looking webhook body", async () => {
  const store = new FakeStore();
  const handler = createHandler(store, { send: async () => "sent" }, secret);
  assert((await handler(request("public-anon-key"))).status === 401);
  assert(store.claims === 0);
  assert((await handler(new Request("https://worker.test"))).status === 405);
});

Deno.test("Preferences, account ownership and resolved requests are checked at delivery time", () => {
  assert(isRelevant(job, context));
  assert(!isRelevant(job, { ...context, notificationsEnabled: false }));
  assert(!isRelevant(job, { ...context, deviceUserId: "someone-else" }));
  assert(!isRelevant(job, { ...context, taskStatus: "approved" }));
  assert(!isRelevant(job, { ...context, seasonActive: false }));
  assert(!isRelevant(job, { ...context, taskUserId: job.recipient_id }));
  const decision = {
    ...job,
    kind: "approved" as const,
    recipient_id: "author",
  };
  assert(
    isRelevant(decision, {
      ...context,
      deviceUserId: "author",
      taskStatus: "approved",
      seasonActive: false,
    }),
  );
  assert(
    !isRelevant(decision, {
      ...context,
      deviceUserId: "author",
      taskStatus: "rejected",
    }),
  );
});

Deno.test("Disabled recipients are skipped without contacting FCM", async () => {
  const store = new FakeStore();
  store.value = { ...context, notificationsEnabled: false };
  let sends = 0;
  const sender: PushSender = {
    send: async () => {
      sends++;
      return "sent";
    },
  };
  assert(
    (await createHandler(store, sender, secret)(request())).status === 200,
  );
  assert(sends === 0 && store.updates[0].status === "skipped");
});

Deno.test("Successful delivery is persisted and temporary failures stop after five attempts", async () => {
  for (
    const [result, attempts, expected] of [["sent", 1, "sent"], [
      "retry",
      1,
      "pending",
    ], ["retry", 5, "failed"]] as const
  ) {
    const store = new FakeStore();
    store.jobs = [{ ...job, attempts }];
    await createHandler(store, { send: async () => result }, secret)(request());
    assert(store.updates[0].status === expected);
  }
});

Deno.test("Unregistered installations are removed rather than retried", async () => {
  const store = new FakeStore();
  await createHandler(store, { send: async () => "unregistered" }, secret)(
    request(),
  );
  assert(store.removed[0] === context.token && store.updates.length === 0);
});

Deno.test("Transport errors are retried without leaking their contents", async () => {
  const store = new FakeStore();
  const response = await createHandler(store, {
    send: async () => {
      throw new Error("private-key-and-token");
    },
  }, secret)(request());
  assert(response.status === 200);
  assert(
    store.updates[0].status === "pending" &&
      store.updates[0].error === "delivery_error",
  );
  assert(!(await response.text()).includes("private-key"));
});

Deno.test("FCM payload uses a registered FID, recipient validation and a stable replacement tag", () => {
  const { message } = buildMessage(job, context.token);
  assert(message.fid === context.token);
  assert(message.data.recipient_id === job.recipient_id);
  assert(message.android.notification.tag === job.id);
  assert(message.apns.headers["apns-collapse-id"] === job.id);
});

Deno.test("OAuth signs the assertion, caches its token and handles unregistered FIDs", async () => {
  const keys = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const rawKey = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", keys.privateKey),
  );
  const account = {
    project_id: "test-project",
    client_email: "sender@test-project.iam.gserviceaccount.com",
    private_key: `-----BEGIN PRIVATE KEY-----\n${
      btoa(String.fromCharCode(...rawKey))
    }\n-----END PRIVATE KEY-----`,
  };
  let authorizations = 0;
  let deliveries = 0;
  const mockFetch: typeof fetch = async (url, options) => {
    if (String(url).includes("oauth2.googleapis.com")) {
      authorizations++;
      const assertion = (options!.body as URLSearchParams).get("assertion")!;
      const parts = assertion.split(".");
      const signature = Uint8Array.from(
        atob(parts[2].replaceAll("-", "+").replaceAll("_", "/")),
        (char) => char.charCodeAt(0),
      );
      assert(
        await crypto.subtle.verify(
          "RSASSA-PKCS1-v1_5",
          keys.publicKey,
          signature,
          new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
        ),
      );
      const claims = JSON.parse(
        atob(parts[1].replaceAll("-", "+").replaceAll("_", "/")),
      );
      assert(
        claims.iss === account.client_email && claims.exp - claims.iat === 3600,
      );
      return Response.json({
        access_token: "oauth-access-token",
        expires_in: 3600,
      });
    }
    deliveries++;
    assert(
      new Headers(options!.headers).get("Authorization") ===
        "Bearer oauth-access-token",
    );
    assert(JSON.parse(options!.body as string).message.fid === context.token);
    return deliveries === 1
      ? Response.json({ name: "message-id" })
      : Response.json({ error: { details: [{ errorCode: "UNREGISTERED" }] } }, {
        status: 404,
      });
  };
  const sender = new FcmSender(account, mockFetch);
  assert(await sender.send(job, context.token) === "sent");
  assert(await sender.send(job, context.token) === "unregistered");
  assert(authorizations === 1);
});
