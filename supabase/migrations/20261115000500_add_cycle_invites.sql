begin;

create table private.cycle_invites (
  season_id uuid primary key references public.seasons(id) on delete cascade,
  code text not null unique default upper(left(replace(gen_random_uuid()::text, '-', ''), 12))
);
revoke all on private.cycle_invites from public, anon, authenticated;

create function public.get_or_create_cycle_invite(p_season_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  invite_code text;
begin
  perform 1 from public.seasons season
  where season.id = p_season_id and season.status = 'active'
    and season.cycle_group_id = private.current_cycle_group_id()
    and private.is_admin()
  for share;
  if not found then raise exception 'CYCLE_INVITE_ADMIN_REQUIRED' using errcode = '42501'; end if;

  insert into private.cycle_invites(season_id) values (p_season_id)
  on conflict (season_id) do update set season_id = excluded.season_id
  returning code into invite_code;
  return invite_code;
end;
$$;

create function public.join_cycle_by_code(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  invite_code text := regexp_replace(upper(p_code), '[[:space:]-]', '', 'g');
  target_season uuid;
  target_group uuid;
  current_group uuid;
begin
  if invite_code is null or invite_code !~ '^[0-9A-F]{12}$' then
    raise exception 'CYCLE_INVITE_INVALID' using errcode = '22023';
  end if;

  -- Lock the active cycle before the profile, in the same order as closing.
  select season.id, season.cycle_group_id into target_season, target_group
  from private.cycle_invites invite join public.seasons season on season.id = invite.season_id
  where invite.code = invite_code and season.status = 'active'
  for share of season;
  if not found then raise exception 'CYCLE_INVITE_INVALID' using errcode = '22023'; end if;

  select profile.cycle_group_id into current_group
  from public.users profile join auth.users account on account.id = profile.id
  where profile.id = account_id and account.email_confirmed_at is not null
  for update of profile;
  if not found then raise exception 'CYCLE_PROFILE_UNAVAILABLE' using errcode = '42501'; end if;
  if current_group = target_group then return target_season; end if;
  if current_group is not null then
    raise exception 'CYCLE_MEMBERSHIP_EXISTS' using errcode = '23505';
  end if;

  -- The existing membership trigger records participation for the closed-cycle history.
  update public.users set cycle_group_id = target_group, is_household_member = true, role = 'sibling'
  where id = account_id;
  return target_season;
end;
$$;

revoke all on function public.get_or_create_cycle_invite(uuid), public.join_cycle_by_code(text) from public, anon;
grant execute on function public.get_or_create_cycle_invite(uuid), public.join_cycle_by_code(text) to authenticated;
notify pgrst, 'reload schema';
commit;
