-- Job posts: any verified user can post; signed-in users can read open jobs.

create or replace function public.is_verified()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'verified'
  );
$$;

revoke all on function public.is_verified() from public, anon;
grant execute on function public.is_verified() to authenticated;

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  poster_name text not null default '',
  title text not null check (length(trim(title)) between 3 and 100),
  description text not null check (length(trim(description)) between 10 and 2000),
  category text not null check (category in (
    'Desk work', 'Academic help', 'Tech help', 'Creative and designs',
    'Manual labor', 'Delivery and errands', 'Event support',
    'Sales and promotion', 'Personal services', 'Others')),
  min_pay numeric(10, 2) not null check (min_pay >= 0),
  negotiable boolean not null default false,
  location text not null check (length(trim(location)) between 2 and 150),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

-- Copy the poster's name onto the job (other users cannot read profiles).
create or replace function public.set_job_poster_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select full_name into new.poster_name
  from public.profiles where id = new.poster_id;
  return new;
end;
$$;

create trigger jobs_set_poster_name
  before insert on public.jobs
  for each row execute function public.set_job_poster_name();

alter table public.jobs enable row level security;

create policy "read open jobs or own jobs"
  on public.jobs for select
  to authenticated
  using (status = 'open' or poster_id = auth.uid());

create policy "verified users post own jobs"
  on public.jobs for insert
  to authenticated
  with check (poster_id = auth.uid() and public.is_verified());
