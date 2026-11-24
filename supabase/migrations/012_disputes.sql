-- Non-payment disputes. Payment happens off-app, so the app only records the
-- agreed amount and lets a worker report non-payment.
--   worker reports (within 14 days of completion)
--   -> poster may submit proof (a receipt reference)
--   -> admin settles: proof valid = paid; no valid proof = poster suspended.

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.jobs (id) on delete cascade,
  job_title text not null,
  worker_id uuid not null references public.profiles (id) on delete cascade,
  worker_name text not null default '',
  poster_id uuid not null references public.profiles (id) on delete cascade,
  poster_name text not null default '',
  amount numeric(10, 2) not null,
  details text check (details is null or length(details) <= 1000),
  proof text check (proof is null or length(proof) <= 1000),
  status text not null default 'open'
    check (status in ('open', 'proof_submitted', 'resolved_paid', 'resolved_unpaid')),
  admin_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.disputes enable row level security;

-- The two people involved and admins can read. Nobody writes directly.
create policy "participants and admins read disputes"
  on public.disputes for select
  to authenticated
  using (worker_id = auth.uid() or poster_id = auth.uid() or public.is_admin());

create or replace function public.report_nonpayment(
  p_job_id uuid,
  p_details text default null
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

  select full_name into v_worker from public.profiles where id = v_job.worker_id;
  select full_name into v_poster from public.profiles where id = v_job.poster_id;

  insert into public.disputes
    (job_id, job_title, worker_id, worker_name, poster_id, poster_name, amount, details)
  values
    (v_job.id, v_job.title, v_job.worker_id, coalesce(v_worker, ''),
     v_job.poster_id, coalesce(v_poster, ''),
     coalesce(v_job.agreed_amount, v_job.min_pay), nullif(trim(p_details), ''));
end;
$$;

revoke all on function public.report_nonpayment(uuid, text) from public, anon;
grant execute on function public.report_nonpayment(uuid, text) to authenticated;

-- The poster answers the report with proof of payment.
create or replace function public.submit_payment_proof(
  p_dispute_id uuid,
  p_proof text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_proof is null or length(trim(p_proof)) < 5 then
    raise exception 'Describe your proof in at least 5 characters';
  end if;
  if length(p_proof) > 1000 then
    raise exception 'Proof is too long (1000 max)';
  end if;

  update public.disputes
  set proof = trim(p_proof), status = 'proof_submitted'
  where id = p_dispute_id
    and poster_id = auth.uid()
    and status = 'open';

  if not found then
    raise exception 'Proof can no longer be submitted for this report';
  end if;
end;
$$;

revoke all on function public.submit_payment_proof(uuid, text) from public, anon;
grant execute on function public.submit_payment_proof(uuid, text) to authenticated;

-- Admin settles a dispute. If unpaid, the poster is suspended.
create or replace function public.resolve_dispute(
  p_dispute_id uuid,
  p_paid boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_poster uuid;
begin
  if not public.is_admin() then
    raise exception 'Not allowed';
  end if;

  update public.disputes
  set status = case when p_paid then 'resolved_paid' else 'resolved_unpaid' end,
      admin_note = nullif(trim(p_note), ''),
      resolved_at = now()
  where id = p_dispute_id and status in ('open', 'proof_submitted')
  returning poster_id into v_poster;

  if not found then
    raise exception 'Dispute not found or already resolved';
  end if;

  if not p_paid then
    update public.profiles set status = 'suspended'
    where id = v_poster and role <> 'admin';
  end if;
end;
$$;

revoke all on function public.resolve_dispute(uuid, boolean, text) from public, anon;
grant execute on function public.resolve_dispute(uuid, boolean, text) to authenticated;
