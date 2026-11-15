begin;

-- Only the owner of a verified account can change the display name.
create function public.rename_my_profile(p_name text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  cleaned_name text := regexp_replace(p_name, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  saved_name text;
begin
  if account_id is null or not exists (
    select 1 from auth.users where id = account_id and email_confirmed_at is not null
  ) then
    raise exception 'ACCOUNT_EMAIL_UNVERIFIED' using errcode = '42501';
  end if;

  if cleaned_name is null or char_length(cleaned_name) not between 1 and 100
      or cleaned_name ~ '[[:cntrl:]]' then
    raise exception 'PROFILE_NAME_INVALID' using errcode = '22023';
  end if;

  update public.users
    set name = cleaned_name
    where id = account_id
    returning name into saved_name;

  if not found then
    raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0002';
  end if;
  return saved_name;
end;
$$;

revoke all on function public.rename_my_profile(text) from public;
grant execute on function public.rename_my_profile(text) to authenticated;

commit;
