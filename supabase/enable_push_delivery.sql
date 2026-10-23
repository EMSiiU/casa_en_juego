-- Ejecutar DESPUÉS de desplegar send-task-notifications y configurar sus secretos.
-- Crear previamente en Supabase Vault:
-- push_function_url: https://omselvknclwasrypkxhp.supabase.co/functions/v1/send-task-notifications
-- push_webhook_secret: el MISMO secreto de NOTIFICATION_WEBHOOK_SECRET de la Edge Function.
begin;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if not exists (select 1 from vault.decrypted_secrets
    where name = 'push_webhook_secret' and length(decrypted_secret) >= 32)
    or not exists (select 1 from vault.decrypted_secrets
    where name = 'push_function_url' and decrypted_secret ~ '^https://[a-z0-9]+\.supabase\.co/functions/v1/send-task-notifications$') then
    raise exception 'Configura primero push_function_url y push_webhook_secret en Vault';
  end if;
end;
$$;

create or replace function private.wake_push_worker() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from new_jobs) then return null; end if;
  perform net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'push_function_url'),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-notification-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'push_webhook_secret')),
    body := '{}'::jsonb, timeout_milliseconds := 10000
  );
  return null;
exception when others then
  -- Una falla al despertar el worker no revierte la tarea: Cron recupera la cola.
  return null;
end;
$$;
revoke all on function private.wake_push_worker() from public;
drop trigger if exists push_jobs_wake_worker on public.push_jobs;
create trigger push_jobs_wake_worker after insert on public.push_jobs
  referencing new table as new_jobs for each statement execute function private.wake_push_worker();

-- El trabajo periódico reintenta entregas fallidas y recupera workers interrumpidos.
do $$
declare existing_job bigint;
begin
  for existing_job in select jobid from cron.job where jobname = 'send_task_notifications' loop
    perform cron.unschedule(existing_job);
  end loop;
  perform cron.schedule('send_task_notifications', '* * * * *', $command$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'push_function_url'),
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notification-secret',
        (select decrypted_secret from vault.decrypted_secrets where name = 'push_webhook_secret')),
      body := '{}'::jsonb, timeout_milliseconds := 10000
    );
  $command$);
end;
$$;
commit;

select jobname, schedule, active from cron.job where jobname = 'send_task_notifications';
