-- Ejecutar en SQL Editor como administrador. No volver a ejecutar phase_2.sql.
-- Las solicitudes anteriores toman los puntos ACTUALES de su tarea.
-- Si el catálogo se editó, revisar esos valores antes de ejecutar la migración.
begin;

lock table public.task_logs in access exclusive mode;

alter table public.task_logs
  add column if not exists points_snapshot integer;

-- El trigger de revisión impediría completar solicitudes de ciclos cerrados.
-- Se repone dentro de esta misma transacción; un error revierte todo el cambio.
drop trigger if exists task_logs_validate on public.task_logs;

update public.task_logs as log
set points_snapshot = task.points
from public.tasks as task
where log.task_id = task.id and log.points_snapshot is null;

alter table public.task_logs alter column points_snapshot set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.task_logs'::regclass
      and conname = 'task_logs_points_snapshot_positive'
  ) then
    alter table public.task_logs
      add constraint task_logs_points_snapshot_positive check (points_snapshot > 0);
  end if;
end;
$$;

create or replace function private.validate_task_log() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.seasons where id = new.season_id and status = 'active' for share;
  if not found then
    raise exception 'La temporada debe estar activa';
  end if;
  if TG_OP = 'INSERT' then
    select points into new.points_snapshot from public.tasks
    where id = new.task_id and is_active for share;
    if not found then raise exception 'La tarea debe estar activa'; end if;
    new.status := 'pending';
    new.requested_at := clock_timestamp();
    new.approved_by := null;
    new.resolved_at := null;
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

-- Refrescar la caché de la API al confirmar la transacción.
notify pgrst, 'reload schema';
commit;

-- Debe aparecer points_snapshot de tipo integer y nullable = NO.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'task_logs'
  and column_name = 'points_snapshot';

-- Ambos contadores deben quedar en cero.
select
  count(*) filter (where points_snapshot is null) as missing_snapshots,
  count(*) filter (where points_snapshot <= 0) as invalid_snapshots
from public.task_logs;
