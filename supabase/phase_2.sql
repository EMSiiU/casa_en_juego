-- Fase 2: ejecutar una sola vez en un proyecto nuevo desde SQL Editor.
-- Antes, crear en Authentication > Users estas cuentas con correo confirmado:
-- carlos@familia.es y ana@familia.es. Elegir sus contraseñas en el dashboard.
-- Desactivar los registros públicos en Authentication > Sign In / Providers.
begin;

create table public.users (
  id uuid primary key references auth.users(id) on delete restrict,
  name text not null check (length(trim(name)) > 0),
  email text not null unique,
  role text not null default 'sibling' check (role in ('admin', 'sibling')),
  notifications_enabled boolean not null default true
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  points integer not null check (points > 0),
  icon_name text not null,
  is_active boolean not null default true
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  start_date timestamptz not null default now(),
  end_date timestamptz,
  status text not null default 'active' check (status in ('active', 'closed')),
  check ((status = 'active' and end_date is null) or
         (status = 'closed' and end_date is not null and end_date >= start_date))
);
create unique index seasons_single_active on public.seasons (status) where status = 'active';

create table public.task_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  task_id uuid not null references public.tasks(id),
  season_id uuid not null references public.seasons(id),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  -- Copia de puntos para conservar el historial al editar el catálogo.
  points_snapshot integer not null check (points_snapshot > 0),
  approved_by uuid references public.users(id),
  resolved_at timestamptz,
  check (approved_by is null or approved_by <> user_id),
  check ((status = 'pending' and approved_by is null and resolved_at is null) or
         (status in ('approved', 'rejected') and approved_by is not null
          and resolved_at is not null and resolved_at >= requested_at))
);
create index task_logs_season_status on public.task_logs(season_id, status);
create index task_logs_user_history on public.task_logs(user_id, requested_at desc);
create index task_logs_task on public.task_logs(task_id);
create index task_logs_reviewer on public.task_logs(approved_by);

-- Funciones privadas para evitar recursión en las políticas de usuarios.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create function private.is_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.users where id = auth.uid());
$$;
create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.users where id = auth.uid() and role = 'admin');
$$;
revoke all on function private.is_member(), private.is_admin() from public;
grant execute on function private.is_member(), private.is_admin() to authenticated;

alter table public.users enable row level security;
alter table public.tasks enable row level security;
alter table public.seasons enable row level security;
alter table public.task_logs enable row level security;

revoke all on public.users, public.tasks, public.seasons, public.task_logs from anon, authenticated;
grant select on public.users, public.tasks, public.seasons, public.task_logs to authenticated;
grant update (notifications_enabled) on public.users to authenticated;
grant insert, update on public.tasks, public.seasons to authenticated;
grant insert (user_id, task_id, season_id), update (status) on public.task_logs to authenticated;

create policy users_read on public.users for select to authenticated using (private.is_member());
create policy users_preferences on public.users for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy tasks_read on public.tasks for select to authenticated using (private.is_member());
create policy tasks_insert on public.tasks for insert to authenticated with check (private.is_admin());
create policy tasks_update on public.tasks for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy seasons_read on public.seasons for select to authenticated using (private.is_member());
create policy seasons_insert on public.seasons for insert to authenticated with check (private.is_admin());
create policy seasons_update on public.seasons for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy task_logs_read on public.task_logs for select to authenticated using (private.is_member());
create policy task_logs_insert on public.task_logs for insert to authenticated
  with check (private.is_member() and user_id = auth.uid() and status = 'pending');
create policy task_logs_review on public.task_logs for update to authenticated
  using (private.is_member() and user_id <> auth.uid() and status = 'pending')
  with check (user_id <> auth.uid() and approved_by = auth.uid() and status in ('approved', 'rejected'));

-- El servidor controla horas y revisor, incluso si se modifica el cliente.
-- El bloqueo del ciclo serializa registros/revisiones con su cierre.
create function private.validate_task_log() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.seasons where id = new.season_id and status = 'active' for share;
  if not found then
    raise exception 'La temporada debe estar activa';
  end if;
  if TG_OP = 'INSERT' then
    select points into new.points_snapshot from public.tasks where id = new.task_id and is_active for share;
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

-- Los ciclos cerrados conservan sus fechas y no se reabren.
create function private.validate_season() returns trigger
language plpgsql set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then
    if new.status <> 'active' then raise exception 'El ciclo debe iniciar activo'; end if;
    new.start_date := clock_timestamp();
    new.end_date := null;
  else
    if old.status <> 'active' or new.status <> 'closed' then
      raise exception 'Solo se permite cerrar el ciclo activo';
    end if;
    new.name := old.name;
    new.start_date := old.start_date;
    new.end_date := clock_timestamp();
  end if;
  return new;
end;
$$;
revoke all on function private.validate_season() from public;
create trigger seasons_validate before insert or update on public.seasons
  for each row execute function private.validate_season();

-- Las cuentas de acceso se crean desde el dashboard, conforme al documento.
do $$
begin
  if (select count(*) from auth.users where email in ('carlos@familia.es', 'ana@familia.es')) <> 2 then
    raise exception 'Crea primero carlos@familia.es y ana@familia.es en Authentication > Users y vuelve a ejecutar el script';
  end if;
end;
$$;
insert into public.users (id, name, email, role)
select id,
  case email when 'carlos@familia.es' then 'Carlos' else 'Ana' end,
  email,
  case email when 'carlos@familia.es' then 'admin' else 'sibling' end
from auth.users where email in ('carlos@familia.es', 'ana@familia.es');

insert into public.tasks (name, points, icon_name) values
  ('Barrer el cuarto', 3, 'broom'),
  ('Lavar los platos', 5, 'utensils'),
  ('Limpiar el baño', 8, 'bathtub');

-- El primer ciclo se iniciará desde administración; no se inventan solicitudes.
commit;

-- Verificación: debe devolver 2 usuarios, 3 tareas, 0 ciclos y 0 solicitudes.
select 'users' as table_name, count(*) as row_count from public.users
union all select 'tasks', count(*) from public.tasks
union all select 'seasons', count(*) from public.seasons
union all select 'task_logs', count(*) from public.task_logs;

