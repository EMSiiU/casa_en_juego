begin;

alter table public.seasons add column planned_end_date date;

create or replace function private.validate_season() returns trigger
language plpgsql set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then
    if new.status <> 'active' then raise exception 'El ciclo debe iniciar activo'; end if;
    new.start_date := clock_timestamp();
    new.end_date := null;
    if new.planned_end_date is not null then
      if not isfinite(new.planned_end_date)
          or new.planned_end_date <= (new.start_date at time zone 'America/Mexico_City')::date then
        raise exception 'CYCLE_END_DATE_INVALID' using errcode = '22023';
      end if;
      new.planned_duration_days :=
        new.planned_end_date - (new.start_date at time zone 'America/Mexico_City')::date;
    end if;
  else
    if old.status <> 'active' or new.status <> 'closed' then
      raise exception 'Solo se permite cerrar el ciclo activo';
    end if;
    new.name := old.name;
    new.start_date := old.start_date;
    new.end_date := clock_timestamp();
    new.planned_end_date := old.planned_end_date;
    new.planned_duration_days := old.planned_duration_days;
  end if;
  return new;
end;
$$;

create function private.create_first_cycle(p_name text, p_duration_days integer, p_planned_end_date date)
returns uuid language plpgsql set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  clean_name text := regexp_replace(p_name, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  group_id uuid;
  season_id uuid;
begin
  if clean_name is null or char_length(clean_name) not between 1 and 100
      or clean_name ~ '[[:cntrl:]]'
      or (p_planned_end_date is null and (p_duration_days is null or p_duration_days < 1)) then
    raise exception 'CYCLE_DETAILS_INVALID' using errcode = '22023';
  end if;

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
  insert into public.seasons(name, cycle_group_id, planned_duration_days, planned_end_date)
    values (clean_name, group_id, p_duration_days, p_planned_end_date) returning id into season_id;
  update public.users set cycle_group_id = group_id, is_household_member = true, role = 'admin'
    where id = account_id;
  return season_id;
end;
$$;
revoke all on function private.create_first_cycle(text, integer, date) from public, anon, authenticated;

-- Preserve the earlier client contract for users who still run that version.
create or replace function public.create_first_cycle(p_name text, p_duration_days integer) returns uuid
language sql security definer set search_path = '' as $$
  select private.create_first_cycle(p_name, p_duration_days, null::date);
$$;

create function public.create_first_cycle(p_name text, p_planned_end_date date) returns uuid
language sql security definer set search_path = '' as $$
  select private.create_first_cycle(p_name, null::integer, p_planned_end_date);
$$;
revoke all on function public.create_first_cycle(text, date) from public, anon;
grant execute on function public.create_first_cycle(text, date) to authenticated;

notify pgrst, 'reload schema';
commit;
