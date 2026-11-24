-- Contact info: every new account gives a Facebook link and a phone number.
-- The other party sees them only after a job is accepted.

alter table public.profiles
  add column facebook_url text,
  add column phone text;

-- Sign-up trigger, now also reading and validating the two contact fields.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := new.raw_user_meta_data ->> 'role';
  v_name text := new.raw_user_meta_data ->> 'full_name';
  v_fb text := trim(coalesce(new.raw_user_meta_data ->> 'facebook_url', ''));
  v_phone text := trim(coalesce(new.raw_user_meta_data ->> 'phone', ''));
begin
  if v_role is null or v_role not in ('student', 'poster') then
    raise exception 'Invalid role';
  end if;

  if v_role = 'student' and lower(new.email) not like '%@cmu.edu.ph' then
    raise exception 'Students must use a @cmu.edu.ph email';
  end if;

  if v_name is null or length(trim(v_name)) = 0 then
    raise exception 'Full name is required';
  end if;

  if lower(v_fb) !~ '^https?://(www\.|m\.|web\.)?(facebook\.com|fb\.com)/.+' then
    raise exception 'A valid Facebook link is required';
  end if;

  if v_phone !~ '^(\+63|0)9[0-9]{9}$' then
    raise exception 'A valid Philippine mobile number is required';
  end if;

  insert into public.profiles (id, full_name, role, facebook_url, phone)
  values (new.id, trim(v_name), v_role, v_fb, v_phone);

  return new;
end;
$$;

-- Returns the OTHER person's contact details for a job. Only the poster and
-- the accepted worker can call it, and only once the job is accepted.
create or replace function public.get_job_contact(p_job_id uuid)
returns table (full_name text, facebook_url text, phone text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs;
begin
  select * into v_job from public.jobs
  where id = p_job_id
    and status in ('in_progress', 'completed')
    and worker_id is not null
    and (poster_id = auth.uid() or worker_id = auth.uid());

  if not found then
    raise exception 'Contact details are shared only after a job is accepted';
  end if;

  return query
    select p.full_name, p.facebook_url, p.phone
    from public.profiles p
    where p.id = case when v_job.poster_id = auth.uid()
                      then v_job.worker_id else v_job.poster_id end;
end;
$$;

revoke all on function public.get_job_contact(uuid) from public, anon;
grant execute on function public.get_job_contact(uuid) to authenticated;
