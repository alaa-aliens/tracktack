-- TrackTack schema (run once in Supabase SQL editor)
create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique default upper(substr(md5(random()::text),1,6)),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);
create table if not exists public.members (
  business_id uuid references public.businesses(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text default 'member',
  primary key (business_id, user_id)
);
create table if not exists public.business_data (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now(),
  updated_by uuid
);

alter table public.businesses enable row level security;
alter table public.members enable row level security;
alter table public.business_data enable row level security;

create or replace function public.is_member(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.members where business_id = b and user_id = auth.uid());
$$;

drop policy if exists "members read business" on public.businesses;
create policy "members read business" on public.businesses for select using (public.is_member(id));
drop policy if exists "create business" on public.businesses;
create policy "create business" on public.businesses for insert with check (auth.uid() = created_by);
drop policy if exists "members update business" on public.businesses;
create policy "members update business" on public.businesses for update using (public.is_member(id));

drop policy if exists "read own memberships" on public.members;
create policy "read own memberships" on public.members for select using (user_id = auth.uid() or public.is_member(business_id));
drop policy if exists "creator adds self" on public.members;
create policy "creator adds self" on public.members for insert with check (
  user_id = auth.uid() and exists(select 1 from public.businesses where id = business_id and created_by = auth.uid())
);

drop policy if exists "members rw data" on public.business_data;
create policy "members rw data" on public.business_data for all using (public.is_member(business_id)) with check (public.is_member(business_id));

-- Join a business with its code
create or replace function public.join_business(code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare b uuid;
begin
  select id into b from public.businesses where join_code = upper(trim(code));
  if b is null then raise exception 'Invalid code'; end if;
  insert into public.members(business_id, user_id) values (b, auth.uid()) on conflict do nothing;
  return b;
end $$;

-- Storage bucket for receipt photos
insert into storage.buckets (id, name, public) values ('receipts','receipts', false) on conflict (id) do nothing;
drop policy if exists "members read receipts" on storage.objects;
create policy "members read receipts" on storage.objects for select using (
  bucket_id = 'receipts' and public.is_member((storage.foldername(name))[1]::uuid));
drop policy if exists "members write receipts" on storage.objects;
create policy "members write receipts" on storage.objects for insert with check (
  bucket_id = 'receipts' and public.is_member((storage.foldername(name))[1]::uuid));
drop policy if exists "members delete receipts" on storage.objects;
create policy "members delete receipts" on storage.objects for delete using (
  bucket_id = 'receipts' and public.is_member((storage.foldername(name))[1]::uuid));
