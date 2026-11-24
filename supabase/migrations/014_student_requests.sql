-- Posters with a non-cmu.edu.ph email can ask to be recognised as students by
-- sending a school ID or a Certificate of Registration (photo, JPG or PNG).
-- An admin reviews it; approval changes the account's role to 'student'.

-- Private bucket for the documents.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('student-docs', 'student-docs', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "users upload own student doc"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'student-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users read own student doc"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'student-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "admins read all student docs"
  on storage.objects for select to authenticated
  using (bucket_id = 'student-docs' and public.is_admin());

create table public.student_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  user_name text not null default '',
  document_path text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

-- A user can have only one pending request at a time.
create unique index student_requests_one_pending
  on public.student_requests (user_id) where status = 'pending';

alter table public.student_requests enable row level security;

create policy "own or admin read student requests"
  on public.student_requests for select
  to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- A verified poster submits a request. Nobody inserts rows directly.
create or replace function public.request_student_status(p_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  select full_name into v_name from public.profiles
  where id = auth.uid() and role = 'poster' and status = 'verified';

  if not found then
    raise exception 'Only verified poster accounts can request student status';
  end if;

  if split_part(p_path, '/', 1) <> auth.uid()::text then
    raise exception 'Invalid document path';
  end if;

  insert into public.student_requests (user_id, user_name, document_path)
  values (auth.uid(), v_name, p_path);
end;
$$;

revoke all on function public.request_student_status(text) from public, anon;
grant execute on function public.request_student_status(text) to authenticated;

-- Admin decision. Approval makes the account a student.
create or replace function public.review_student_request(
  p_request_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
begin
  if not public.is_admin() then
    raise exception 'Not allowed';
  end if;

  if not p_approve and (p_reason is null or length(trim(p_reason)) = 0) then
    raise exception 'A reason is required when rejecting';
  end if;

  update public.student_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
      rejection_reason = case when p_approve then null else trim(p_reason) end,
      reviewed_at = now()
  where id = p_request_id and status = 'pending'
  returning user_id into v_user;

  if not found then
    raise exception 'Request not found or already reviewed';
  end if;

  if p_approve then
    update public.profiles set role = 'student'
    where id = v_user and role = 'poster';
  end if;
end;
$$;

revoke all on function public.review_student_request(uuid, boolean, text) from public, anon;
grant execute on function public.review_student_request(uuid, boolean, text) to authenticated;
