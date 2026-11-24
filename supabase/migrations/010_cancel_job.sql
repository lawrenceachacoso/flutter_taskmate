-- Poster cancels their own OPEN job. Pending applicants are rejected.

create or replace function public.cancel_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.jobs set status = 'cancelled'
  where id = p_job_id
    and poster_id = auth.uid()
    and status = 'open';

  if not found then
    raise exception 'Only your own open jobs can be cancelled';
  end if;

  update public.applications set status = 'rejected'
  where job_id = p_job_id and status = 'pending';
end;
$$;

revoke all on function public.cancel_job(uuid) from public, anon;
grant execute on function public.cancel_job(uuid) to authenticated;
