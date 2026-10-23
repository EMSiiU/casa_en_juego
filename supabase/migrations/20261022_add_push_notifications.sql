-- Ejecutar después de las migraciones de puntos y límites diarios.
begin;

create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null unique check (length(token) between 10 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);
create index push_devices_user on public.push_devices(user_id);

-- Un trabajo por dispositivo evita reenviar a los dispositivos ya atendidos.
create table public.push_jobs (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.push_devices(id) on delete cascade,
  recipient_id uuid not null references public.users(id) on delete cascade,
  task_log_id uuid not null references public.task_logs(id) on delete cascade,
  kind text not null check (kind in ('submitted', 'approved', 'rejected')),
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'skipped', 'failed')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  available_at timestamptz not null default now(),
  lease_id uuid,
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  last_error text,
  unique(task_log_id, kind, device_id)
);
create index push_jobs_pending on public.push_jobs(available_at)
  where status in ('pending', 'processing');

alter table public.push_devices enable row level security;
alter table public.push_jobs enable row level security;
-- Los clientes no pueden consultar tokens ajenos, crear avisos ni reclamar trabajos.
revoke all on public.push_devices, public.push_jobs from anon, authenticated;
grant all on public.push_devices, public.push_jobs to service_role;

create or replace function public.register_push_device(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_member() then
    raise exception 'Inicia sesión con una cuenta familiar';
  end if;
  if p_token is null or length(p_token) not between 10 and 4096
    or p_platform is null or p_platform not in ('android', 'ios') then
    raise exception 'Dispositivo no válido';
  end if;
  -- Un cambio de cuenta elimina también los avisos pendientes de la cuenta anterior.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_token, 0));
  delete from public.push_devices where token = p_token and user_id <> auth.uid();
  insert into public.push_devices(user_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update set platform = excluded.platform, updated_at = clock_timestamp();
end;
$$;

create or replace function public.unregister_push_device(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.push_devices where token = p_token and user_id = auth.uid();
$$;
revoke all on function public.register_push_device(text, text), public.unregister_push_device(text) from public;
grant execute on function public.register_push_device(text, text), public.unregister_push_device(text) to authenticated;

create or replace function private.enqueue_task_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare event_kind text;
begin
  if TG_OP = 'INSERT' and new.status = 'pending' then
    event_kind := 'submitted';
  elsif TG_OP = 'UPDATE' and old.status = 'pending' and new.status in ('approved', 'rejected') then
    event_kind := new.status;
  else return new;
  end if;
  insert into public.push_jobs(device_id, recipient_id, task_log_id, kind)
  select device.id, device.user_id, new.id, event_kind
  from public.push_devices device join public.users member on member.id = device.user_id
  where member.notifications_enabled and (
    (event_kind = 'submitted' and member.id <> new.user_id)
    or (event_kind <> 'submitted' and member.id = new.user_id)
  ) on conflict (task_log_id, kind, device_id) do nothing;
  return new;
end;
$$;
revoke all on function private.enqueue_task_push() from public;
create trigger task_logs_enqueue_push after insert or update of status on public.task_logs
  for each row execute function private.enqueue_task_push();

create or replace function public.claim_push_jobs(p_limit integer default 10)
returns setof public.push_jobs language plpgsql security definer set search_path = '' as $$
begin
  -- Los trabajos abandonados se recuperan, con un máximo de cinco intentos.
  update public.push_jobs set status = 'failed', completed_at = clock_timestamp(), last_error = 'expired'
  where status in ('pending', 'processing')
    and (locked_until is null or locked_until < now())
    and (attempts >= 5 or created_at < now() - interval '1 day');
  return query
  with candidates as (
    select id from public.push_jobs
    where attempts < 5 and created_at >= now() - interval '1 day'
      and available_at <= now()
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

-- Ambas tablas deben tener RLS activo.
select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename in ('push_devices', 'push_jobs');
