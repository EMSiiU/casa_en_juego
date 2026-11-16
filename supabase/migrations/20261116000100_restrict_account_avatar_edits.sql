begin;

create function private.can_manage_account_avatar()
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from auth.users u
    where u.id = (select auth.uid())
      and u.email_confirmed_at is not null
      and u.raw_app_meta_data ->> 'provider' = 'email'
  );
$$;

revoke all on function private.can_manage_account_avatar() from public;
grant execute on function private.can_manage_account_avatar() to authenticated;

alter policy "Users manage their own account avatar"
on storage.objects
using (
  bucket_id = 'account-avatars'
  and name = (select auth.uid())::text || '/avatar'
  and (select private.can_manage_account_avatar())
)
with check (
  bucket_id = 'account-avatars'
  and name = (select auth.uid())::text || '/avatar'
  and (select private.can_manage_account_avatar())
);

commit;
