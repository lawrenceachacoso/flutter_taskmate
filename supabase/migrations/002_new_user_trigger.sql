create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := new.raw_user_meta_data ->> 'role';
  v_name text := new.raw_user_meta_data ->> 'full_name';
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

  insert into public.profiles (id, full_name, role)
  values (new.id, trim(v_name), v_role);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();