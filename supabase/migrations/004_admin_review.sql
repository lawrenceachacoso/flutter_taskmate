-- Admin review of submitted ID photos.

-- True only for a verified admin. security definer lets the check read
-- public.profiles without tripping over row level security itself.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'verified'
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Admins may read every profile (users still only read their own).
create policy "admins read all profiles"
  on public.profiles for select
  using (public.is_admin());

-- Admins may view every ID photo.
create policy "admins read all id photos"
  on storage.objects for select
  using (bucket_id = 'id-photos' and public.is_admin());

-- Approve or reject a pending profile. Only admins can call it.
create or replace function public.review_profile(
  p_user_id uuid,
  p_decision text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Not allowed';
  end if;

  if p_decision not in ('verified', 'rejected') then
    raise exception 'Invalid decision';
  end if;

  if p_decision = 'rejected'
     and (p_reason is null or length(trim(p_reason)) = 0) then
    raise exception 'A reason is required when rejecting';
  end if;

  update public.profiles
  set status = p_decision,
      rejection_reason = case when p_decision = 'rejected'
                              then trim(p_reason) else null end
  where id = p_user_id
    and status = 'pending'
    and role in ('student', 'poster');

  if not found then
    raise exception 'No pending profile found';
  end if;
end;
$$;

revoke all on function public.review_profile(uuid, text, text) from public, anon;
grant execute on function public.review_profile(uuid, text, text) to authenticated;
