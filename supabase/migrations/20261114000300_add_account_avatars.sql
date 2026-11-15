begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'account-avatars', 'account-avatars', false, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
);

create policy "Users manage their own account avatar"
on storage.objects for all to authenticated
using (bucket_id = 'account-avatars' and name = (select auth.uid())::text || '/avatar')
with check (bucket_id = 'account-avatars' and name = (select auth.uid())::text || '/avatar');

commit;
