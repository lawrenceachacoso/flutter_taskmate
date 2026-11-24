-- 016: profile pictures + picture proof for non-payment reports.

-- ---------------------------------------------------------------------------
-- A) Profile pictures
-- ---------------------------------------------------------------------------
-- PUBLIC bucket: anyone with a picture's link can view it (needed so other
-- users can see avatars). Max 2 MB, JPG or PNG. Files live in <user_id>/.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "users upload own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

alter table public.profiles add column avatar_path text;

-- Profiles have no update policy, so the path is saved through this function.
create or replace function public.set_avatar(p_path text)
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
    raise exception 'Invalid picture path';
  end if;
  update public.profiles set avatar_path = p_path where id = auth.uid();
end;
$$;

revoke all on function public.set_avatar(text) from public, anon;
grant execute on function public.set_avatar(text) to authenticated;

-- Public view gains the picture path (new column goes last).
create or replace view public.public_profiles as
  select id, full_name, rating_avg, rating_count, avatar_path
  from public.profiles
  where status = 'verified';

-- ---------------------------------------------------------------------------
-- B) Picture proof for disputes
-- ---------------------------------------------------------------------------
alter table public.disputes
  add column worker_proof_paths text[] not null default '{}',
  add column poster_proof_paths text[] not null default '{}';

-- True when the signed-in user is the poster or worker of that job, or an
-- admin. The job id arrives as text because it is read from a file path.
create or replace function public.is_job_party(p_job_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin() or exists (
    select 1 from public.jobs j
    where j.id::text = p_job_id
      and (j.poster_id = auth.uid() or j.worker_id = auth.uid())
  );
$$;

revoke all on function public.is_job_party(text) from public, anon;
grant execute on function public.is_job_party(text) to authenticated;

-- Private bucket, max 5 MB, JPG or PNG. Path: <job_id>/<user_id>/<file>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dispute-proof', 'dispute-proof', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "job parties upload dispute proof"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'dispute-proof'
    and (storage.foldername(name))[2] = auth.uid()::text
    and public.is_job_party((storage.foldername(name))[1])
  );

create policy "job parties and admins read dispute proof"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'dispute-proof'
    and public.is_job_party((storage.foldername(name))[1])
  );

-- Replace the two functions with versions that also take picture paths.
drop function public.report_nonpayment(uuid, text);
drop function public.submit_payment_proof(uuid, text);

create or replace function public.report_nonpayment(
  p_job_id uuid,
  p_details text default null,
  p_paths text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
  v_worker text;
  v_poster text;
  v_prefix text;
  v_path text;
begin
  select * into v_job from public.jobs
  where id = p_job_id and status = 'completed' and worker_id = auth.uid();

  if not found then
    raise exception 'Only the worker of a completed job can report non-payment';
  end if;

  if v_job.completed_at is null
     or now() > v_job.completed_at + interval '14 days' then
    raise exception 'The 14-day reporting window has closed';
  end if;

  if p_details is not null and length(p_details) > 1000 then
    raise exception 'Details are too long (1000 max)';
  end if;

  if coalesce(array_length(p_paths, 1), 0) > 5 then
    raise exception 'You can attach up to 5 pictures';
  end if;

  v_prefix := p_job_id::text || '/' || auth.uid()::text || '/';
  foreach v_path in array coalesce(p_paths, '{}') loop
    if left(v_path, length(v_prefix)) <> v_prefix then
      raise exception 'Invalid picture path';
    end if;
  end loop;

  select full_name into v_worker from public.profiles where id = v_job.worker_id;
  select full_name into v_poster from public.profiles where id = v_job.poster_id;

  insert into public.disputes
    (job_id, job_title, worker_id, worker_name, poster_id, poster_name, amount,
     details, worker_proof_paths)
  values
    (v_job.id, v_job.title, v_job.worker_id, coalesce(v_worker, ''),
     v_job.poster_id, coalesce(v_poster, ''),
     coalesce(v_job.agreed_amount, v_job.min_pay), nullif(trim(p_details), ''),
     coalesce(p_paths, '{}'));
end;
$$;

revoke all on function public.report_nonpayment(uuid, text, text[]) from public, anon;
grant execute on function public.report_nonpayment(uuid, text, text[]) to authenticated;

create or replace function public.submit_payment_proof(
  p_dispute_id uuid,
  p_proof text default null,
  p_paths text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  v_prefix text;
  v_path text;
begin
  if (p_proof is null or length(trim(p_proof)) < 5)
     and coalesce(array_length(p_paths, 1), 0) = 0 then
    raise exception 'Write at least 5 characters or attach a picture';
  end if;
  if p_proof is not null and length(p_proof) > 1000 then
    raise exception 'Proof is too long (1000 max)';
  end if;
  if coalesce(array_length(p_paths, 1), 0) > 5 then
    raise exception 'You can attach up to 5 pictures';
  end if;

  select job_id into v_job_id from public.disputes
  where id = p_dispute_id and poster_id = auth.uid() and status = 'open';

  if not found then
    raise exception 'Proof can no longer be submitted for this report';
  end if;

  v_prefix := v_job_id::text || '/' || auth.uid()::text || '/';
  foreach v_path in array coalesce(p_paths, '{}') loop
    if left(v_path, length(v_prefix)) <> v_prefix then
      raise exception 'Invalid picture path';
    end if;
  end loop;

  update public.disputes
  set proof = nullif(trim(p_proof), ''),
      poster_proof_paths = coalesce(p_paths, '{}'),
      status = 'proof_submitted'
  where id = p_dispute_id;
end;
$$;

revoke all on function public.submit_payment_proof(uuid, text, text[]) from public, anon;
grant execute on function public.submit_payment_proof(uuid, text, text[]) to authenticated;
