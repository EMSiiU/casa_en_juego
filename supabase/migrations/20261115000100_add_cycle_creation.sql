-- Apply after the personal accounts, daily limits and push reminder migrations.
begin;

-- A group keeps its catalog and members between seasons.
create table private.cycle_groups (
  id uuid primary key default gen_random_uuid()
);
revoke all on private.cycle_groups from public, anon, authenticated;
insert into private.cycle_groups(id) values ('00000000-0000-0000-0000-000000000001');

alter table public.users add column cycle_group_id uuid references private.cycle_groups(id);
update public.users set cycle_group_id = '00000000-0000-0000-0000-000000000001'
where is_household_member;
alter table public.users add constraint users_cycle_membership
  check (is_household_member = (cycle_group_id is not null));
create index users_cycle_group_id on public.users(cycle_group_id);

-- The constant defaults also backfill existing rows, without firing the close-season trigger.
alter table public.tasks add column cycle_group_id uuid not null
  default '00000000-0000-0000-0000-000000000001' references private.cycle_groups(id);
alter table public.seasons add column cycle_group_id uuid not null
  default '00000000-0000-0000-0000-000000000001' references private.cycle_groups(id);
alter table public.seasons add column planned_duration_days integer
  check (planned_duration_days > 0);
create index tasks_cycle_group_id on public.tasks(cycle_group_id);
create index seasons_cycle_group_id on public.seasons(cycle_group_id);
drop index public.seasons_single_active;
create unique index seasons_one_active_per_group
  on public.seasons(cycle_group_id) where status = 'active';

create function private.current_cycle_group_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select profile.cycle_group_id
  from public.users profile join auth.users account on account.id = profile.id
  where profile.id = auth.uid() and account.email_confirmed_at is not null;
$$;
revoke all on function private.current_cycle_group_id() from public;
grant execute on function private.current_cycle_group_id() to authenticated;

alter table public.tasks alter column cycle_group_id set default private.current_cycle_group_id();
alter table public.seasons alter column cycle_group_id set default private.current_cycle_group_id();
revoke insert, update on public.tasks, public.seasons from authenticated;
grant insert (name, points, icon_name, is_active, is_daily_limited),
  update (name, points, icon_name, is_active, is_daily_limited) on public.tasks to authenticated;
grant insert (name), update (status) on public.seasons to authenticated;

alter policy users_read on public.users
  using (id = (select auth.uid()) or cycle_group_id = (select private.current_cycle_group_id()));
alter policy tasks_read on public.tasks
  using (cycle_group_id = (select private.current_cycle_group_id()));
alter policy tasks_insert on public.tasks with check (
  cycle_group_id = (select private.current_cycle_group_id()) and (select private.is_admin())
);
alter policy tasks_update on public.tasks using (
  cycle_group_id = (select private.current_cycle_group_id()) and (select private.is_admin())
) with check (
  cycle_group_id = (select private.current_cycle_group_id()) and (select private.is_admin())
);
alter policy seasons_read on public.seasons
  using (cycle_group_id = (select private.current_cycle_group_id()));
alter policy seasons_insert on public.seasons with check (
  cycle_group_id = (select private.current_cycle_group_id()) and (select private.is_admin())
);
alter policy seasons_update on public.seasons using (
  cycle_group_id = (select private.current_cycle_group_id()) and (select private.is_admin())
) with check (
  cycle_group_id = (select private.current_cycle_group_id()) and (select private.is_admin())
);

-- The subqueries see only seasons in the caller's group, through seasons_read.
alter policy task_logs_read on public.task_logs
  using (exists (select 1 from public.seasons where id = task_logs.season_id));
alter policy task_logs_insert on public.task_logs with check (
  user_id = (select auth.uid()) and status = 'pending'
  and exists (select 1 from public.seasons where id = task_logs.season_id)
);
alter policy task_logs_review on public.task_logs using (
  user_id <> (select auth.uid()) and status = 'pending'
  and exists (select 1 from public.seasons where id = task_logs.season_id)
) with check (
  user_id <> (select auth.uid()) and approved_by = (select auth.uid())
  and status in ('approved', 'rejected')
  and exists (select 1 from public.seasons where id = task_logs.season_id)
);

-- Before the existing validator reads points, reject mismatched or foreign references.
create function private.check_task_log_cycle_group() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.seasons season
    join public.tasks task on task.cycle_group_id = season.cycle_group_id
    join public.users member on member.cycle_group_id = season.cycle_group_id
    where season.id = new.season_id and task.id = new.task_id and member.id = new.user_id
      and (auth.uid() is null or (member.id = auth.uid()
        and season.cycle_group_id = private.current_cycle_group_id()))
  ) then
    raise exception 'TASK_OUTSIDE_CYCLE_GROUP' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.check_task_log_cycle_group() from public;
create trigger task_logs_check_cycle_group before insert on public.task_logs
  for each row execute function private.check_task_log_cycle_group();

create function public.create_first_cycle(p_name text, p_duration_days integer) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  clean_name text := regexp_replace(p_name, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  group_id uuid;
  season_id uuid;
begin
  if clean_name is null or char_length(clean_name) not between 1 and 100
      or clean_name ~ '[[:cntrl:]]' or p_duration_days is null or p_duration_days < 1 then
    raise exception 'CYCLE_DETAILS_INVALID' using errcode = '22023';
  end if;

  -- Lock the profile so concurrent creation or a future join cannot assign it twice.
  select profile.cycle_group_id into group_id
  from public.users profile join auth.users account on account.id = profile.id
  where profile.id = account_id and account.email_confirmed_at is not null
  for update of profile;
  if not found then
    raise exception 'CYCLE_PROFILE_UNAVAILABLE' using errcode = '42501';
  end if;
  if group_id is not null then
    raise exception 'CYCLE_MEMBERSHIP_EXISTS' using errcode = '23505';
  end if;

  insert into private.cycle_groups default values returning id into group_id;
  insert into public.seasons(name, cycle_group_id, planned_duration_days)
    values (clean_name, group_id, p_duration_days) returning id into season_id;
  update public.users set cycle_group_id = group_id, is_household_member = true, role = 'admin'
    where id = account_id;
  return season_id;
end;
$$;
revoke all on function public.create_first_cycle(text, integer) from public, anon;
grant execute on function public.create_first_cycle(text, integer) to authenticated;

-- The worker runs with elevated privileges, so explicitly scope its recipients.
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
  from public.push_devices device
  join public.users member on member.id = device.user_id
  join public.seasons season on season.id = new.season_id and season.cycle_group_id = member.cycle_group_id
  where member.notifications_enabled and (
    (event_kind = 'submitted' and member.id <> new.user_id)
    or (event_kind <> 'submitted' and member.id = new.user_id)
  ) on conflict (task_log_id, kind, device_id) do nothing;
  return new;
end;
$$;

create or replace function private.enqueue_inactivity_reminders(p_now timestamptz default statement_timestamp())
returns integer language plpgsql security definer set search_path = '' as $$
declare
  local_time timestamp := p_now at time zone 'America/Mexico_City';
  local_day date := local_time::date;
  local_hour integer := extract(hour from local_time)::integer;
  inserted_count integer;
  slot_time timestamptz;
begin
  if local_hour not in (18, 20) or extract(minute from local_time) <> 0 then return 0; end if;
  slot_time := date_trunc('hour', local_time) at time zone 'America/Mexico_City';
  with active_seasons as materialized (
    select id, cycle_group_id from public.seasons where status = 'active' for share
  )
  insert into public.push_jobs(device_id, recipient_id, kind, reminder_day, reminder_hour,
    reminder_season_id, available_at, expires_at)
  select device.id, device.user_id, 'reminder', local_day, local_hour,
    season.id, p_now, slot_time + interval '30 minutes'
  from public.push_devices device
  join public.users member on member.id = device.user_id
  join active_seasons season on season.cycle_group_id = member.cycle_group_id
  where member.notifications_enabled and not exists (
    select 1 from public.task_logs log
    where log.user_id = member.id and log.requested_day = local_day
      and log.status in ('pending', 'approved')
  ) on conflict (device_id, reminder_day, reminder_hour) where kind = 'reminder' do nothing;
  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function private.push_reminder_context(p_job_id uuid, p_lease_id uuid,
  p_now timestamptz default statement_timestamp())
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'token', device.token, 'deviceUserId', device.user_id,
    'notificationsEnabled', member.notifications_enabled,
    'reminderEligible', member.notifications_enabled
      and job.recipient_id = device.user_id
      and season.status = 'active' and season.cycle_group_id = member.cycle_group_id
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

notify pgrst, 'reload schema';
commit;
