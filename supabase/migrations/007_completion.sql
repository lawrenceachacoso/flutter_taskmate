-- Completion: the poster and the worker each confirm; both needed.

alter table public.jobs
  add column poster_done boolean not null default false,
  add column worker_done boolean not null default false;

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

  update public.jobs set status = 'completed'
  where id = p_job_id and poster_done and worker_done;
end;
$$;

revoke all on function public.mark_complete(uuid) from public, anon;
grant execute on function public.mark_complete(uuid) to authenticated;
