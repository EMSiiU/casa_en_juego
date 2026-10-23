import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import {
  createHandler,
  type PushContext,
  type PushJob,
  type PushStore,
} from "./handler.ts";
import { FcmSender, type ServiceAccount } from "./fcm_sender.ts";

const secret = Deno.env.get("NOTIFICATION_WEBHOOK_SECRET") ?? "";
const url = Deno.env.get("SUPABASE_URL") ?? "";
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
let account: ServiceAccount | undefined;
try {
  const candidate = JSON.parse(
    Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "{}",
  );
  if (candidate.project_id && candidate.client_email && candidate.private_key) {
    account = candidate;
  }
} catch (_) {
  /* Una configuración incompleta no expone su contenido en los logs. */
}

if (!account || !url || !key || secret.length < 32) {
  Deno.serve(() =>
    Response.json({ error: "notification_configuration_missing" }, {
      status: 503,
    })
  );
} else {
  const client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const store: PushStore = {
    async claim(): Promise<PushJob[]> {
      const { data, error } = await client.rpc("claim_push_jobs", {
        p_limit: 10,
      });
      if (error) throw error;
      return data;
    },
    async context(job): Promise<PushContext | null> {
      const [device, user, log] = await Promise.all([
        client.from("push_devices").select("token,user_id").eq(
          "id",
          job.device_id,
        ).maybeSingle(),
        client.from("users").select("notifications_enabled").eq(
          "id",
          job.recipient_id,
        ).maybeSingle(),
        client.from("task_logs").select("status,user_id,seasons(status)").eq(
          "id",
          job.task_log_id,
        ).maybeSingle(),
      ]);
      for (const result of [device, user, log]) {
        if (result.error) throw result.error;
      }
      if (!device.data || !user.data || !log.data) return null;
      const season = log.data.seasons as unknown as { status: string } | null;
      return {
        token: device.data.token,
        deviceUserId: device.data.user_id,
        notificationsEnabled: user.data.notifications_enabled,
        taskUserId: log.data.user_id,
        taskStatus: log.data.status,
        seasonActive: season?.status === "active",
      };
    },
    async settle(job, status, errorCode) {
      const { error } = await client.from("push_jobs").update({
        status,
        last_error: errorCode ?? null,
        locked_until: null,
        lease_id: null,
        completed_at: status === "pending" ? null : new Date().toISOString(),
        available_at: new Date(Date.now() + 30000 * 2 ** job.attempts)
          .toISOString(),
      }).eq("id", job.id).eq("status", "processing").eq(
        "lease_id",
        job.lease_id,
      );
      if (error) throw error;
    },
    async removeDevice(job, token) {
      const { error } = await client.from("push_devices").delete()
        .eq("id", job.device_id).eq("user_id", job.recipient_id).eq(
          "token",
          token,
        );
      if (error) throw error;
    },
  };
  Deno.serve(createHandler(store, new FcmSender(account), secret));
}
