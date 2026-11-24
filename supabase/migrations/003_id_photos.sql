-- Private bucket for ID photos: not public, max 5 MB, JPG or PNG only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('id-photos', 'id-photos', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

-- A signed-in user may upload only into their own folder: <user_id>/<file>.
create policy "users upload own id photo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'id-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- A signed-in user may read only their own folder.
create policy "users read own id photo"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'id-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- The app cannot update profiles directly (no update policy exists), so the
-- photo path is recorded through this one controlled function. It only touches
-- the caller's own row, only while the account is pending or rejected, and it
-- moves a rejected account back to pending for a fresh review.
create or replace function public.submit_id_photo(p_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if split_part(p_path, '/', 1) <> auth.uid()::text then
    raise exception 'Invalid photo path';
  end if;

  update public.profiles
  set id_photo_path = p_path,
      status = case when status = 'rejected' then 'pending' else status end,
      rejection_reason = case when status = 'rejected' then null else rejection_reason end
  where id = auth.uid()
    and status in ('pending', 'rejected');

  if not found then
    raise exception 'ID photo cannot be submitted in the current status';
  end if;
end;
$$;

revoke all on function public.submit_id_photo(text) from public;
grant execute on function public.submit_id_photo(text) to authenticated;
