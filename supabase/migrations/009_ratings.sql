-- Ratings: after a job is completed, the poster and the worker each rate the
-- other once (1-5 stars + optional comment), within 7 days of completion.

alter table public.jobs add column completed_at timestamptz;

-- Jobs completed before this migration get a fresh 7-day window.
update public.jobs set completed_at = now()
where status = 'completed' and completed_at is null;

-- mark_complete now also records when the job was completed.
create or replace function public.mark_complete(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
begin
  select * into v_job from public.jobs
  where id = p_job_id
    and status = 'in_progress'
    and (poster_id = auth.uid() or worker_id = auth.uid());

  if not found then
    raise exception 'Job not found or not in progress';
  end if;

  if v_job.poster_id = auth.uid() then
    update public.jobs set poster_done = true where id = p_job_id;
  else
    update public.jobs set worker_done = true where id = p_job_id;
  end if;

  update public.jobs set status = 'completed', completed_at = now()
  where id = p_job_id and poster_done and worker_done;
end;
$$;

-- Running average kept on the profile.
alter table public.profiles
  add column rating_avg numeric(3, 2) not null default 0,
  add column rating_count integer not null default 0;

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  rater_id uuid not null references public.profiles (id) on delete cascade,
  rater_name text not null default '',
  ratee_id uuid not null references public.profiles (id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  comment text check (comment is null or length(comment) <= 500),
  created_at timestamptz not null default now(),
  unique (job_id, rater_id),
  check (rater_id <> ratee_id)
);

alter table public.ratings enable row level security;

-- Anyone signed in can read ratings. There is NO insert/update/delete policy,
-- so users can only add a rating through submit_rating() below.
create policy "signed-in users read ratings"
  on public.ratings for select
  to authenticated
  using (true);

create or replace function public.update_rating_average()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set rating_avg = round(
        ((rating_avg * rating_count) + new.stars)::numeric / (rating_count + 1), 2),
      rating_count = rating_count + 1
  where id = new.ratee_id;
  return new;
end;
$$;

create trigger ratings_update_average
  after insert on public.ratings
  for each row execute function public.update_rating_average();

create or replace function public.submit_rating(
  p_job_id uuid,
  p_stars integer,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
  v_ratee uuid;
  v_name text;
begin
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Stars must be between 1 and 5';
  end if;

  if p_comment is not null and length(p_comment) > 500 then
    raise exception 'Comment is too long (500 max)';
  end if;

  select * into v_job from public.jobs
  where id = p_job_id
    and status = 'completed'
    and (poster_id = auth.uid() or worker_id = auth.uid());

  if not found then
    raise exception 'You can only rate after a completed job you took part in';
  end if;

  if v_job.completed_at is null
     or now() > v_job.completed_at + interval '7 days' then
    raise exception 'The 7-day rating window has closed';
  end if;

  v_ratee := case when v_job.poster_id = auth.uid()
                  then v_job.worker_id else v_job.poster_id end;

  select full_name into v_name from public.profiles where id = auth.uid();

  insert into public.ratings (job_id, rater_id, rater_name, ratee_id, stars, comment)
  values (p_job_id, auth.uid(), coalesce(v_name, ''), v_ratee, p_stars,
          nullif(trim(p_comment), ''));
end;
$$;

revoke all on function public.submit_rating(uuid, integer, text) from public, anon;
grant execute on function public.submit_rating(uuid, integer, text) to authenticated;

-- Safe public view of verified users: name and rating only (no ID photo,
-- phone, etc.). Views run with their owner's rights, so this bypasses the
-- private-profile rule for just these columns.
create view public.public_profiles as
  select id, full_name, rating_avg, rating_count
  from public.profiles
  where status = 'verified';

revoke all on public.public_profiles from public, anon;
grant select on public.public_profiles to authenticated;
