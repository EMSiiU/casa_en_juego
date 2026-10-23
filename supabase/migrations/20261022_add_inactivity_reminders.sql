-- Ejecutar después de desplegar la Edge Function actualizada para recordatorios.
-- La programación se activa aparte con enable_inactivity_reminders.sql.
begin;

alter table public.push_jobs alter column task_log_id drop not null;
alter table public.push_jobs drop constraint push_jobs_kind_check;
alter table public.push_jobs add constraint push_jobs_kind_check
  check (kind in ('submitted', 'approved', 'rejected', 'reminder'));
alter table public.push_jobs
  add column reminder_day date,
  add column reminder_hour integer,
  add column reminder_season_id uuid references public.seasons(id),
  add column expires_at timestamptz;
update public.push_jobs set expires_at = created_at + interval '1 day';
alter table public.push_jobs alter column expires_at set default (now() + interval '1 day');
alter table public.push_jobs alter column expires_at set not null;
alter table public.push_jobs add constraint push_jobs_event_shape check (
  (kind = 'reminder' and task_log_id is null and reminder_day is not null
    and reminder_hour is not null and reminder_hour in (18, 20) and reminder_season_id is not null)
  or (kind <> 'reminder' and task_log_id is not null and reminder_day is null
    and reminder_hour is null and reminder_season_id is null)
);
create unique index push_jobs_reminder_slot
  on public.push_jobs(device_id, reminder_day, reminder_hour) where kind = 'reminder';
create index task_logs_daily_activity on public.task_logs(user_id, requested_day)
  where status in ('pending', 'approved');

create or replace function private.enqueue_inactivity_reminders(p_now timestamptz default statement_timestamp())
returns integer language plpgsql security definer set search_path = '' as $$
declare
  local_time timestamp := p_now at time zone 'America/Mexico_City';
  local_day date := local_time::date;
  local_hour integer := extract(hour from local_time)::integer;
  active_season uuid;
  inserted_count integer;
  slot_time timestamptz;
begin
  -- Cron llama cada hora; solo se generan avisos a las 18:00 y a las 20:00 locales.
  if local_hour not in (18, 20) or extract(minute from local_time) <> 0 then return 0; end if;
  select id into active_season from public.seasons where status = 'active' for share;
  if active_season is null then return 0; end if;
  slot_time := date_trunc('hour', local_time) at time zone 'America/Mexico_City';
  insert into public.push_jobs(device_id, recipient_id, kind, reminder_day, reminder_hour,
    reminder_season_id, available_at, expires_at)
  select device.id, device.user_id, 'reminder', local_day, local_hour,
    active_season, p_now, slot_time + interval '30 minutes'
  from public.push_devices device join public.users member on member.id = device.user_id
  where member.notifications_enabled and not exists (
    select 1 from public.task_logs log
    where log.user_id = member.id and log.requested_day = local_day
      and log.status in ('pending', 'approved')
  ) on conflict (device_id, reminder_day, reminder_hour) where kind = 'reminder' do nothing;
  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;
revoke all on function private.enqueue_inactivity_reminders(timestamptz) from public, anon, authenticated;

create or replace function private.push_reminder_context(p_job_id uuid, p_lease_id uuid,
  p_now timestamptz default statement_timestamp())
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'token', device.token, 'deviceUserId', device.user_id,
    'notificationsEnabled', member.notifications_enabled,
    'reminderEligible', member.notifications_enabled
      and job.recipient_id = device.user_id
      and season.status = 'active'
      and job.reminder_day = (p_now at time zone 'America/Mexico_City')::date
      and job.available_at <= p_now and job.expires_at > p_now
      and not exists (
        select 1 from public.task_logs log
        where log.user_id = job.recipient_id and log.requested_day = job.reminder_day
          and log.status in ('pending', 'approved')
      )
  )
  from public.push_jobs job
  join public.push_devices device on device.id = job.device_id
  join public.users member on member.id = job.recipient_id
  join public.seasons season on season.id = job.reminder_season_id
  where job.id = p_job_id and job.lease_id = p_lease_id and job.status = 'processing'
    and job.kind = 'reminder';
$$;
revoke all on function private.push_reminder_context(uuid, uuid, timestamptz) from public, anon, authenticated;

create or replace function public.get_push_reminder_context(p_job_id uuid, p_lease_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  -- El cliente no puede cambiar el reloj ni solicitar información de la cola.
  select private.push_reminder_context(p_job_id, p_lease_id);
$$;
revoke all on function public.get_push_reminder_context(uuid, uuid) from public, anon, authenticated;
grant execute on function public.get_push_reminder_context(uuid, uuid) to service_role;

create or replace function public.claim_push_jobs(p_limit integer default 10)
returns setof public.push_jobs language plpgsql security definer set search_path = '' as $$
begin
  update public.push_jobs set status = 'failed', completed_at = clock_timestamp(), last_error = 'expired'
  where status in ('pending', 'processing')
    and (locked_until is null or locked_until < now())
    and (attempts >= 5 or expires_at <= now());
  return query
  with candidates as (
    select id from public.push_jobs
    where attempts < 5 and expires_at > now() and available_at <= now()
      and (status = 'pending' or (status = 'processing' and locked_until < now()))
    order by created_at for update skip locked limit least(greatest(p_limit, 1), 10)
  )
  update public.push_jobs job set status = 'processing', attempts = attempts + 1,
    locked_until = now() + interval '2 minutes', lease_id = gen_random_uuid()
  from candidates where job.id = candidates.id returning job.*;
end;
$$;
revoke all on function public.claim_push_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_push_jobs(integer) to service_role;

notify pgrst, 'reload schema';
commit;
