-- Applications: verified users apply to open jobs; the poster accepts one.

alter table public.jobs
  add column worker_id uuid references public.profiles (id),
  add column applicant_count integer not null default 0;

-- The accepted worker must still be able to read the job after it leaves 'open'.
drop policy "read open jobs or own jobs" on public.jobs;
create policy "read open, own or accepted jobs"
  on public.jobs for select
  to authenticated
  using (status = 'open' or poster_id = auth.uid() or worker_id = auth.uid());

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  applicant_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  applicant_name text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  unique (job_id, applicant_id)
);

-- Copy the applicant's name (others cannot read profiles) and bump the count.
create or replace function public.before_application_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select full_name into new.applicant_name
  from public.profiles where id = new.applicant_id;
  return new;
end;
$$;

create or replace function public.after_application_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.jobs set applicant_count = applicant_count + 1
  where id = new.job_id;
  return new;
end;
$$;

create trigger applications_before_insert
  before insert on public.applications
  for each row execute function public.before_application_insert();

create trigger applications_after_insert
  after insert on public.applications
  for each row execute function public.after_application_insert();

alter table public.applications enable row level security;

-- Applicants see their own applications; posters see applications to their jobs.
create policy "read own or received applications"
  on public.applications for select
  to authenticated
  using (
    applicant_id = auth.uid()
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.poster_id = auth.uid()
    )
  );

-- Verified users may apply to someone else's open job, as themselves.
create policy "verified users apply to open jobs"
  on public.applications for insert
  to authenticated
  with check (
    applicant_id = auth.uid()
    and public.is_verified()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id and j.status = 'open' and j.poster_id <> auth.uid()
    )
  );

-- The poster accepts one applicant: job goes in_progress, others are rejected.
create or replace function public.accept_application(p_application_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  v_applicant uuid;
begin
  select a.job_id, a.applicant_id into v_job_id, v_applicant
  from public.applications a
  join public.jobs j on j.id = a.job_id
  where a.id = p_application_id
    and a.status = 'pending'
    and j.status = 'open'
    and j.poster_id = auth.uid();

  if v_job_id is null then
    raise exception 'Application not found or not allowed';
  end if;

  update public.applications set status = 'accepted'
  where id = p_application_id;

  update public.applications set status = 'rejected'
  where job_id = v_job_id and id <> p_application_id and status = 'pending';

  update public.jobs set status = 'in_progress', worker_id = v_applicant
  where id = v_job_id;
end;
$$;

revoke all on function public.accept_application(uuid) from public, anon;
grant execute on function public.accept_application(uuid) to authenticated;
