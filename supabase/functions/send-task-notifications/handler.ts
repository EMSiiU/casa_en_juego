export type PushJob = {
  id: string;
  device_id: string;
  recipient_id: string;
  task_log_id: string;
  kind: "submitted" | "approved" | "rejected";
  attempts: number;
  lease_id: string;
};

export type PushContext = {
  token: string;
  deviceUserId: string;
  notificationsEnabled: boolean;
  taskUserId: string;
  taskStatus: string;
  seasonActive: boolean;
};

export interface PushStore {
  claim(): Promise<PushJob[]>;
  context(job: PushJob): Promise<PushContext | null>;
  settle(
    job: PushJob,
    status: "sent" | "skipped" | "pending" | "failed",
    error?: string,
  ): Promise<void>;
  removeDevice(job: PushJob, token: string): Promise<void>;
}

export interface PushSender {
  send(
    job: PushJob,
    token: string,
  ): Promise<"sent" | "unregistered" | "retry" | "failed">;
}

export function isRelevant(job: PushJob, context: PushContext): boolean {
  if (
    !context.notificationsEnabled || context.deviceUserId !== job.recipient_id
  ) return false;
  return job.kind === "submitted"
    ? context.seasonActive && context.taskStatus === "pending" &&
      context.taskUserId !== job.recipient_id
    : context.taskUserId === job.recipient_id &&
      context.taskStatus === job.kind;
}

async function matchesSecret(
  actual: string,
  expected: string,
): Promise<boolean> {
  if (expected.length < 32 || !actual) return false;
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all(
    [actual, expected].map(async (value) =>
      new Uint8Array(
        await crypto.subtle.digest("SHA-256", encoder.encode(value)),
      )
    ),
  );
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

export function createHandler(
  store: PushStore,
  sender: PushSender,
  secret: string,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }
    if (
      !await matchesSecret(
        request.headers.get("x-notification-secret") ?? "",
        secret,
      )
    ) {
      return new Response("Unauthorized", { status: 401 });
    }
    try {
      const jobs = await store.claim();
      const results = await Promise.all(jobs.map(async (job) => {
        try {
          const context = await store.context(job);
          if (!context || !isRelevant(job, context)) {
            await store.settle(job, "skipped");
            return "skipped";
          }
          const result = await sender.send(job, context.token);
          if (result === "unregistered") {
            await store.removeDevice(job, context.token);
            return "skipped";
          }
          const status = result === "retry"
            ? (job.attempts >= 5 ? "failed" : "pending")
            : result;
          await store.settle(
            job,
            status,
            result === "sent" ? undefined : "fcm_rejected",
          );
          return status;
        } catch (_) {
          // Se registra un código fijo; nunca respuestas que contengan tokens o claves.
          const status = job.attempts >= 5 ? "failed" : "pending";
          await store.settle(job, status, "delivery_error");
          return status;
        }
      }));
      return Response.json({ processed: results.length });
    } catch (_) {
      // El arrendamiento permite recuperar el trabajo si tampoco se pudo guardar el reintento.
      return Response.json({ error: "notification_worker_unavailable" }, {
        status: 503,
      });
    }
  };
}
