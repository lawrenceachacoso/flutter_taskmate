create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('student', 'poster', 'admin')),
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected', 'suspended')),
  id_photo_path text,
  rejection_reason text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "read own profile"
  on public.profiles for select
  using (auth.uid() = id);