-- Agreed amount: the poster sets it when accepting a worker (never below the
-- posted minimum). The worker confirms it, which locks it. A job cannot be
-- marked complete until the amount is locked.

alter table public.jobs
  add column agreed_amount numeric(10, 2),
  add column amount_confirmed boolean not null default false;

-- Jobs accepted before this migration keep working: use the minimum pay.
update public.jobs
set agreed_amount = min_pay, amount_confirmed = true
where status in ('in_progress', 'completed') and agreed_amount is null;

-- accept_application now takes the agreed amount (defaults to the minimum).
drop function public.accept_application(uuid);

create or replace function public.accept_application(
  p_application_id uuid,
  p_amount numeric default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  v_applicant uuid;
  v_min numeric;
  v_amount numeric;
begin
  select a.job_id, a.applicant_id, j.min_pay
    into v_job_id, v_applicant, v_min
  from public.applications a
  join public.jobs j on j.id = a.job_id
  where a.id = p_application_id
    and a.status = 'pending'
    and j.status = 'open'
    and j.poster_id = auth.uid();

  if v_job_id is null then
    raise exception 'Application not found or not allowed';
  end if;

  v_amount := coalesce(p_amount, v_min);
  if v_amount < v_min then
    raise exception 'The agreed amount cannot be below the minimum pay';
  end if;
  if v_amount > 99999999 then
    raise exception 'Amount is too large';
  end if;

  update public.applications set status = 'accepted'
  where id = p_application_id;

  update public.applications set status = 'rejected'
  where job_id = v_job_id and id <> p_application_id and status = 'pending';

  update public.jobs
  set status = 'in_progress', worker_id = v_applicant,
      agreed_amount = v_amount, amount_confirmed = false
  where id = v_job_id;
end;
$$;

revoke all on function public.accept_application(uuid, numeric) from public, anon;
grant execute on function public.accept_application(uuid, numeric) to authenticated;

-- Poster changes the proposed amount, only until the worker confirms.
create or replace function public.set_agreed_amount(
  p_job_id uuid,
  p_amount numeric
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_min numeric;
begin
  select min_pay into v_min from public.jobs
  where id = p_job_id
    and poster_id = auth.uid()
    and status = 'in_progress'
    and not amount_confirmed;

  if not found then
    raise exception 'The amount can no longer be changed';
  end if;

  if p_amount is null or p_amount < v_min then
    raise exception 'The agreed amount cannot be below the minimum pay';
  end if;
  if p_amount > 99999999 then
    raise exception 'Amount is too large';
  end if;

  update public.jobs set agreed_amount = p_amount where id = p_job_id;
end;
$$;

revoke all on function public.set_agreed_amount(uuid, numeric) from public, anon;
grant execute on function public.set_agreed_amount(uuid, numeric) to authenticated;

-- The accepted worker confirms the amount, which locks it.
create or replace function public.confirm_amount(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.jobs set amount_confirmed = true
  where id = p_job_id
    and worker_id = auth.uid()
    and status = 'in_progress'
    and agreed_amount is not null
    and not amount_confirmed;

  if not found then
    raise exception 'Nothing to confirm';
  end if;
end;
$$;

revoke all on function public.confirm_amount(uuid) from public, anon;
grant execute on function public.confirm_amount(uuid) to authenticated;

-- mark_complete now requires the amount to be locked first.
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

  if not v_job.amount_confirmed then
    raise exception 'The agreed amount must be confirmed by the worker first';
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
