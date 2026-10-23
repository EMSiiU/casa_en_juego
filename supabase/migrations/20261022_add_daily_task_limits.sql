-- Ejecutar en SQL Editor después de la migración de points_snapshot.
-- No volver a ejecutar phase_2.sql ni la migración anterior después de esta.
begin;
lock table public.task_logs in access exclusive mode;
alter table public.tasks add column if not exists is_daily_limited boolean not null default false;
alter table public.task_logs add column if not exists requested_day date;
alter table public.task_logs add column if not exists daily_limit_applied boolean not null default false;
drop trigger if exists task_logs_validate on public.task_logs;

-- El historial se conserva, incluso si antes se registraba varias veces al día.
update public.task_logs
set requested_day = (requested_at at time zone 'America/Mexico_City')::date
where requested_day is null;
alter table public.task_logs alter column requested_day set not null;

-- Solo las tareas indicadas se restringen inicialmente. Las demás son repetibles.
update public.tasks set is_daily_limited = true
where translate(lower(name), 'áéíóúñ', 'aeioun') ~
  '(^barrer([[:space:]]|$)|^(lavar|limpiar)[[:space:]].*banos?([[:space:]]|$)|^(tender|hacer)[[:space:]].*camas?([[:space:]]|$)|^(limpiar|ordenar)[[:space:]].*mis[[:space:]]+cosas([[:space:]]|$))';

create index if not exists task_logs_daily_lookup
  on public.task_logs(user_id, task_id, requested_day)
  where status in ('pending', 'approved');
create unique index if not exists task_logs_daily_limit
  on public.task_logs(user_id, task_id, requested_day)
  where daily_limit_applied and status in ('pending', 'approved');

create or replace function private.validate_task_log() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  task_daily boolean;
begin
  perform 1 from public.seasons where id = new.season_id and status = 'active' for share;
  if not found then raise exception 'La temporada debe estar activa'; end if;
  if TG_OP = 'INSERT' then
    select points, is_daily_limited into new.points_snapshot, task_daily
    from public.tasks where id = new.task_id and is_active for share;
    if not found then raise exception 'La tarea debe estar activa'; end if;
    -- Serializa envíos concurrentes de la misma persona y tarea.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text || ':' || new.task_id::text, 0));
    new.status := 'pending';
    new.requested_at := clock_timestamp();
    new.requested_day := (new.requested_at at time zone 'America/Mexico_City')::date;
    new.daily_limit_applied := task_daily;
    new.approved_by := null;
    new.resolved_at := null;
    -- El límite cruza temporadas y excluye las solicitudes rechazadas.
    if task_daily and exists (
      select 1 from public.task_logs
      where user_id = new.user_id and task_id = new.task_id
        and requested_day = new.requested_day and status in ('pending', 'approved')
    ) then raise exception 'TASK_DAILY_LIMIT_REACHED'; end if;
  else
    if old.status <> 'pending' or new.status not in ('approved', 'rejected') then
      raise exception 'Solo se pueden resolver solicitudes pendientes';
    end if;
    if auth.uid() is null or auth.uid() = old.user_id then
      raise exception 'Otro miembro debe revisar la solicitud';
    end if;
    new.approved_by := auth.uid();
    new.resolved_at := clock_timestamp();
  end if;
  return new;
end;
$$;
revoke all on function private.validate_task_log() from public;
create trigger task_logs_validate before insert or update on public.task_logs
  for each row execute function private.validate_task_log();

-- RLS sigue controlando el acceso; solo se devuelve el estado del usuario actual.
create or replace function public.get_task_submission_status() returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  server_time timestamptz := statement_timestamp();
  server_day date := (server_time at time zone 'America/Mexico_City')::date;
  blocked_ids jsonb;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  select coalesce(jsonb_agg(distinct log.task_id), '[]'::jsonb) into blocked_ids
  from public.task_logs log join public.tasks task on task.id = log.task_id
  where log.user_id = auth.uid() and task.is_daily_limited
    and log.requested_day = server_day and log.status in ('pending', 'approved');
  return jsonb_build_object(
    'server_now', server_time,
    'resets_at', (server_day + 1)::timestamp at time zone 'America/Mexico_City',
    'blocked_task_ids', blocked_ids
  );
end;
$$;
revoke all on function public.get_task_submission_status() from public;
grant execute on function public.get_task_submission_status() to authenticated;
notify pgrst, 'reload schema';
commit;

-- Revisar qué tareas quedaron limitadas; el administrador puede cambiarlas.
select name, is_daily_limited from public.tasks order by name;
