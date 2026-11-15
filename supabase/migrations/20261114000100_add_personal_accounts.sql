-- Apply before enabling public sign-ups. Existing family profiles stay members.
begin;

alter table public.users add column is_household_member boolean not null default true;
alter table public.users alter column is_household_member set default false;

create or replace function private.is_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.users p
    join auth.users a on a.id = p.id
    where p.id = auth.uid() and p.is_household_member
      and a.email_confirmed_at is not null
  );
$$;

create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin' and private.is_member()
  );
$$;

drop policy users_read on public.users;
create policy users_read on public.users for select to authenticated
  using (id = auth.uid() or (is_household_member and private.is_member()));

-- Authenticate and use the verified identity stored in Auth, never a user ID,
-- email address, or role supplied as an RPC parameter.
create function public.ensure_personal_profile() returns void
language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  account_email text;
  account_name text;
begin
  select email, left(btrim(coalesce(raw_user_meta_data->>'name', '')), 100)
    into account_email, account_name
    from auth.users
    where id = account_id and email_confirmed_at is not null;

  if account_email is null then
    raise exception 'ACCOUNT_EMAIL_UNVERIFIED' using errcode = '42501';
  end if;

  insert into public.users (id, name, email, role, notifications_enabled, is_household_member)
    values (
      account_id,
      coalesce(nullif(account_name, ''), split_part(account_email, '@', 1)),
      account_email, 'sibling', false, false
    )
    on conflict (id) do nothing;
end;
$$;

revoke all on function public.ensure_personal_profile() from public;
grant execute on function public.ensure_personal_profile() to authenticated;

commit;
