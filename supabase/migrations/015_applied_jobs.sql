-- Keep the job's title on each application so "Applied jobs" can list it even
-- after the job is no longer open (users cannot read closed jobs they did not
-- post or win).

alter table public.applications
  add column job_title text not null default '';

update public.applications a
set job_title = j.title
from public.jobs j
where j.id = a.job_id;

-- Same trigger function as 006, now also copying the job title.
create or replace function public.before_application_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select full_name into new.applicant_name
  from public.profiles where id = new.applicant_id;

  select title into new.job_title
  from public.jobs where id = new.job_id;

  return new;
end;
$$;
