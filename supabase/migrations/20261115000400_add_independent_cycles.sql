begin;

-- Record access independently of the current membership on public.users.
create table private.season_participants (
  season_id uuid not null references public.seasons(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  primary key (season_id, user_id)
);
revoke all on private.season_participants from public, anon, authenticated;
create index season_participants_user_id on private.season_participants(user_id);

create table private.season_task_archive (
  season_id uuid not null references public.seasons(id) on delete cascade,
  task_id uuid not null,
  name text not null,
  points integer not null,
  icon_name text not null,
  is_active boolean not null,
  is_daily_limited boolean not null,
  primary key (season_id, task_id)
);
revoke all on private.season_task_archive from public, anon, authenticated;

lock table public.seasons, public.users, public.tasks, public.task_logs in access exclusive mode;

-- Before this migration, membership was shared by every season in a group.
insert into private.season_participants(season_id, user_id)
select season.id, member.id
from public.seasons season
join public.users member on member.cycle_group_id = season.cycle_group_id
union
select log.season_id, log.user_id from public.task_logs log
union
select log.season_id, log.approved_by from public.task_logs log where log.approved_by is not null;

insert into private.season_task_archive
  (season_id, task_id, name, points, icon_name, is_active, is_daily_limited)
select season.id, task.id, task.name, task.points, task.icon_name, task.is_active, task.is_daily_limited
from public.seasons season
join public.tasks task on task.cycle_group_id = season.cycle_group_id
where season.status = 'closed';

alter table public.task_logs
  add column task_name_snapshot text,
  add column requester_name_snapshot text,
  add column reviewer_name_snapshot text;

-- The existing validator disallows changes to closed or resolved requests.
alter table public.task_logs disable trigger task_logs_validate;
update public.task_logs log
set task_name_snapshot = task.name,
    requester_name_snapshot = requester.name,
    reviewer_name_snapshot = (select reviewer.name from public.users reviewer where reviewer.id = log.approved_by)
from public.tasks task, public.users requester
where task.id = log.task_id and requester.id = log.user_id;
alter table public.task_logs enable trigger task_logs_validate;
alter table public.task_logs
  alter column task_name_snapshot set not null,
  alter column requester_name_snapshot set not null;

create function private.record_task_log_labels() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then
    select name into new.task_name_snapshot from public.tasks where id = new.task_id;
    select name into new.requester_name_snapshot from public.users where id = new.user_id;
  else
    select name into new.reviewer_name_snapshot from public.users where id = new.approved_by;
  end if;
  return new;
end;
$$;
revoke all on function private.record_task_log_labels() from public, anon, authenticated;
-- Alphabetical order places this after task_logs_validate, which sets approved_by.
create trigger task_logs_write_history before insert or update of status on public.task_logs
  for each row execute function private.record_task_log_labels();

create function private.is_cycle_participant(p_season_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.season_participants participant
    join auth.users account on account.id = participant.user_id
    where participant.season_id = p_season_id and participant.user_id = auth.uid()
      and account.email_confirmed_at is not null
  );
$$;
revoke all on function private.is_cycle_participant(uuid) from public, anon;
grant execute on function private.is_cycle_participant(uuid) to authenticated;

create function public.get_closed_cycle_catalog(p_season_id uuid)
returns table (id uuid, name text, points integer, icon_name text, is_active boolean, is_daily_limited boolean)
language sql stable security definer set search_path = '' as $$
  select task.task_id, task.name, task.points, task.icon_name, task.is_active, task.is_daily_limited
  from private.season_task_archive task
  where task.season_id = p_season_id and private.is_cycle_participant(p_season_id);
$$;
revoke all on function public.get_closed_cycle_catalog(uuid) from public, anon;
grant execute on function public.get_closed_cycle_catalog(uuid) to authenticated;

create function private.record_active_cycle_membership() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  active_id uuid;
begin
  select season.id into active_id
  from public.seasons season
  where season.cycle_group_id = new.cycle_group_id and season.status = 'active';
  if not found then
    raise exception 'CYCLE_NOT_ACTIVE' using errcode = '23514';
  end if;
  insert into private.season_participants(season_id, user_id)
    values (active_id, new.id) on conflict do nothing;
  return new;
end;
$$;
revoke all on function private.record_active_cycle_membership() from public, anon, authenticated;
create trigger users_record_active_cycle after update of cycle_group_id on public.users
  for each row when (new.cycle_group_id is not null and old.cycle_group_id is distinct from new.cycle_group_id)
  execute function private.record_active_cycle_membership();

create function private.release_cycle_memberships() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.season_task_archive
    (season_id, task_id, name, points, icon_name, is_active, is_daily_limited)
  select new.id, task.id, task.name, task.points, task.icon_name, task.is_active, task.is_daily_limited
  from public.tasks task where task.cycle_group_id = new.cycle_group_id;
  update public.users
  set cycle_group_id = null, is_household_member = false, role = 'sibling'
  where cycle_group_id = new.cycle_group_id;
  return new;
end;
$$;
revoke all on function private.release_cycle_memberships() from public, anon, authenticated;
create trigger seasons_release_members after update of status on public.seasons
  for each row when (old.status = 'active' and new.status = 'closed')
  execute function private.release_cycle_memberships();

-- Release memberships that previously survived a close, after capturing access.
update public.users member
set cycle_group_id = null, is_household_member = false, role = 'sibling'
where member.cycle_group_id is not null and not exists (
  select 1 from public.seasons season
  where season.cycle_group_id = member.cycle_group_id and season.status = 'active'
);

-- All future cycles start through create_first_cycle, which allocates a fresh group.
revoke insert (name, planned_end_date) on public.seasons from authenticated;
drop policy seasons_insert on public.seasons;
alter policy seasons_read on public.seasons using (
  (status = 'active' and cycle_group_id = (select private.current_cycle_group_id()))
  or (status = 'closed' and private.is_cycle_participant(id))
);

-- Archival read access never supplies write access to the old season or its logs.
alter policy task_logs_insert on public.task_logs with check (
  user_id = (select auth.uid()) and status = 'pending'
  and exists (select 1 from public.seasons where id = task_logs.season_id and status = 'active')
);
alter policy task_logs_review on public.task_logs using (
  user_id <> (select auth.uid()) and status = 'pending'
  and exists (select 1 from public.seasons where id = task_logs.season_id and status = 'active')
) with check (
  user_id <> (select auth.uid()) and approved_by = (select auth.uid())
  and status in ('approved', 'rejected')
  and exists (select 1 from public.seasons where id = task_logs.season_id and status = 'active')
);

-- Client edits serialize with closing. The privileged template seeder runs
-- before a season exists, so only direct authenticated catalog saves need the check.
create function private.lock_open_cycle_for_catalog() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user = 'authenticated' then
    perform 1 from public.seasons
    where cycle_group_id = new.cycle_group_id and status = 'active' for share;
    if not found then raise exception 'CYCLE_NOT_ACTIVE' using errcode = '42501'; end if;
  end if;
  return new;
end;
$$;
revoke all on function private.lock_open_cycle_for_catalog() from public, anon, authenticated;
create trigger tasks_require_open_cycle before insert or update on public.tasks
  for each row execute function private.lock_open_cycle_for_catalog();

notify pgrst, 'reload schema';
commit;
