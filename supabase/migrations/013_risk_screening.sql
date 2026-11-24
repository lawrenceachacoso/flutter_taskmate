-- Risk screening of new job posts, done in the database so the app cannot
-- skip it. Rules live in a table so they can be edited without app changes.
--
--   a "high" rule matches      -> status 'blocked'
--   else a "moderate" matches  -> status 'pending_review' (admin decides)
--   else (low risk)            -> 'open' if the poster is trusted or an admin,
--                                 otherwise 'pending_review'
-- Trusted = at least 3 ratings with an average of 4.0 or more.

-- New job statuses.
alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check check (status in (
  'pending_review', 'open', 'in_progress', 'completed', 'cancelled', 'blocked'));

alter table public.jobs
  add column risk_level text not null default 'low'
    check (risk_level in ('low', 'moderate', 'high')),
  add column risk_reasons text[] not null default '{}',
  add column review_note text;

create table public.risk_rules (
  id bigint generated always as identity primary key,
  target text not null check (target in ('text', 'location')),
  pattern text not null,           -- case-insensitive regular expression
  level text not null check (level in ('moderate', 'high')),
  reason text not null,
  active boolean not null default true
);

-- No policies on purpose: only the database functions below (and you, in the
-- SQL Editor) can read or change the rules.
alter table public.risk_rules enable row level security;

insert into public.risk_rules (target, pattern, level, reason) values
  -- HIGH: prohibited, blocked
  ('text', '\m(take|taking|answer|answering) (my|an|the|our) (exam|exams|quiz|quizzes|test|tests)\M',
    'high', 'Academic dishonesty: taking an exam for someone'),
  ('text', '\m(take|taking|attend|attending|do|doing) (my|an|the) online (class|classes|course|courses)\M',
    'high', 'Academic dishonesty: taking an online class for someone'),
  ('text', '\m(write|writing|do|doing) (my|our) (thesis|capstone|dissertation)\M',
    'high', 'Academic dishonesty: doing a thesis for someone'),
  ('text', '\m(escort|nudes?|sexual|sex|erotic|sugar (daddy|mommy|baby))\M',
    'high', 'Sexual content or services are not allowed'),
  ('text', '\m(shabu|marijuana|cocaine|illegal drugs?|counterfeit|fake (id|ids|diploma|certificate)|gambling|weapons?|explosives?)\M',
    'high', 'Illegal or dangerous work'),
  ('location', '^\s*(tbd|tba|tbc|anywhere|n/?a|none|unknown|\?+|pm me|dm me|message me|will message|to be announced)\s*$',
    'high', 'The meeting place is not specified'),
  -- MODERATE: needs an admin decision
  ('text', '\m(legal advice|medical advice|diagnos(e|is)|prescri(be|ption)|notar(y|ize))\M',
    'moderate', 'May require a professional licence'),
  ('text', '\m(upfront (payment|fee|deposit)|registration fee|processing fee|deposit first|send (money|payment) first|pay first)\M',
    'moderate', 'Asks the worker to pay first'),
  ('text', '\m(investment|crypto|forex|mlm|pyramid|recruit(ing)? (members|downline))\M',
    'moderate', 'Investment or recruitment scheme wording'),
  ('text', '\m(my (house|home|room|condo|apartment|boarding ?house)|residence|overnight|night shift)\M',
    'moderate', 'Work at a private residence or overnight'),
  ('location', '\m(house|home|residence|condo|apartment|boarding ?house|dorm|room)\M',
    'moderate', 'The meeting place may be a private residence');

create or replace function public.screen_new_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_text text := new.title || ' ' || new.description;
  v_high text[];
  v_mod text[];
  v_trusted boolean;
begin
  select coalesce(array_agg(distinct reason), '{}'::text[]) into v_high
  from public.risk_rules
  where active and level = 'high'
    and ((target = 'text' and v_text ~* pattern)
      or (target = 'location' and new.location ~* pattern));

  select coalesce(array_agg(distinct reason), '{}'::text[]) into v_mod
  from public.risk_rules
  where active and level = 'moderate'
    and ((target = 'text' and v_text ~* pattern)
      or (target = 'location' and new.location ~* pattern));

  select (role = 'admin' or (rating_count >= 3 and rating_avg >= 4.0))
    into v_trusted
  from public.profiles where id = new.poster_id;
  v_trusted := coalesce(v_trusted, false);

  new.risk_reasons := v_high || v_mod;

  if cardinality(v_high) > 0 then
    new.risk_level := 'high';
    new.status := 'blocked';
  elsif cardinality(v_mod) > 0 then
    new.risk_level := 'moderate';
    new.status := 'pending_review';
  else
    new.risk_level := 'low';
    new.status := case when v_trusted then 'open' else 'pending_review' end;
  end if;

  return new;
end;
$$;

create trigger jobs_screen_new_job
  before insert on public.jobs
  for each row execute function public.screen_new_job();

-- Admins can read every job (including those waiting for review).
drop policy "read open, own or accepted jobs" on public.jobs;
create policy "read open, own, accepted jobs, or all as admin"
  on public.jobs for select
  to authenticated
  using (
    status = 'open'
    or poster_id = auth.uid()
    or worker_id = auth.uid()
    or public.is_admin()
  );

-- Admin approves or rejects a job that is waiting for review.
create or replace function public.review_job(
  p_job_id uuid,
  p_approve boolean,
  p_note text default null
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

  update public.jobs
  set status = case when p_approve then 'open' else 'blocked' end,
      review_note = nullif(trim(p_note), '')
  where id = p_job_id and status = 'pending_review';

  if not found then
    raise exception 'Job not found or not waiting for review';
  end if;
end;
$$;

revoke all on function public.review_job(uuid, boolean, text) from public, anon;
grant execute on function public.review_job(uuid, boolean, text) to authenticated;
