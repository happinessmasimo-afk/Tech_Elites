-- ============================================================================
-- Agricast Livestock LITE — new Supabase project
-- 001: extensions + profiles (farmer accounts only, no staff/admin/vet roles)
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text,
  phone text,
  location text,
  created_at timestamptz not null default now()
);

comment on table public.profiles is
  'One row per farmer, mirrors auth.users. Created automatically on signup by the trigger below.';

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own" on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up through Supabase Auth.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Shared updated_at trigger function, reused by 002_marketplace.sql
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

grant select, insert, update on public.profiles to authenticated;
