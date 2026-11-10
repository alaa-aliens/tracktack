-- Tamm: database hardening, part 1.
-- Safe to run more than once. Run it in Supabase > SQL Editor AFTER publishing app version b10.
-- It does not delete any shop data. What it changes:
--   1. Viewers can no longer change a shop's records (until now only the app stopped them, not the database).
--      Owners, editors, accountants and staff can.
--   2. Only the owner can rename the shop, delete all its data, or manage invites.
--   3. Shop codes become 10 characters from a secure random source, and guessing is limited
--      to 10 tries an hour per account. EXISTING SHOP CODES CHANGE (the new one shows in the app).
--   4. Every save keeps the previous version in public.business_data_history, so a bad save,
--      a wipe or a "Reset" can be undone. The last 200 versions per shop are kept.
--   5. The database stamps who saved and when, so that can't be faked from a phone.
--   6. Receipt photos: max 5 MB, images only, and only owners/editors can add or remove them.
--   7. Signed-out visitors can't call any Tamm database function.

begin;

create extension if not exists pgcrypto;

-- ---------- roles ----------
create or replace function public.member_role(b uuid) returns text
language sql stable security definer set search_path = public as $$
  select role from public.members where business_id = b and user_id = auth.uid();
$$;

create or replace function public.can_write(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.member_role(b) in ('owner', 'editor', 'accountant', 'staff'), false);
$$;

create or replace function public.is_owner(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.member_role(b) = 'owner', false);
$$;

-- ---------- start every Tamm table from a clean set of rules ----------
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public' and tablename in ('businesses', 'members', 'business_data', 'invites')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.businesses    enable row level security;
alter table public.members       enable row level security;
alter table public.business_data enable row level security;

-- businesses
create policy "members read shop"   on public.businesses for select using (public.is_member(id) or created_by = auth.uid());
create policy "create own shop"     on public.businesses for insert with check (auth.uid() = created_by);
create policy "owner updates shop"  on public.businesses for update using (public.is_owner(id)) with check (public.is_owner(id));
create policy "owner deletes shop"  on public.businesses for delete using (public.is_owner(id));

-- members
create policy "see own shop team"   on public.members for select using (user_id = auth.uid() or public.is_member(business_id));
create policy "creator joins as owner" on public.members for insert with check (
  user_id = auth.uid() and exists (select 1 from public.businesses where id = business_id and created_by = auth.uid()));
create policy "owner removes, anyone leaves" on public.members for delete using (
  user_id = auth.uid() or (public.is_owner(business_id) and role <> 'owner'));

-- business_data: everyone in the shop reads, only owner/editor writes, only owner wipes
create policy "members read data"   on public.business_data for select using (public.is_member(business_id));
create policy "writers add data"    on public.business_data for insert with check (public.can_write(business_id));
create policy "writers save data"   on public.business_data for update using (public.can_write(business_id)) with check (public.can_write(business_id));
create policy "owner wipes data"    on public.business_data for delete using (public.is_owner(business_id));

-- invites (only if the table exists): owner only. The invite functions keep working.
do $$
begin
  if to_regclass('public.invites') is not null then
    execute 'alter table public.invites enable row level security';
    execute 'create policy "owner manages invites" on public.invites for all using (public.is_owner(business_id)) with check (public.is_owner(business_id))';
  end if;
end $$;

-- ---------- size guard: one shop's data can't exceed 5 MB ----------
alter table public.business_data drop constraint if exists business_data_size;
alter table public.business_data add constraint business_data_size check (pg_column_size(data) < 5000000);

-- ---------- server-side stamps + version history ----------
create table if not exists public.business_data_history (
  id bigserial primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  data jsonb not null,
  saved_at timestamptz,
  saved_by uuid,
  replaced_at timestamptz not null default now(),
  replaced_by uuid,
  action text not null
);
create index if not exists business_data_history_biz on public.business_data_history (business_id, id desc);
alter table public.business_data_history enable row level security;
drop policy if exists "owner reads history" on public.business_data_history;
create policy "owner reads history" on public.business_data_history for select using (public.is_owner(business_id));

create or replace function public.business_data_stamp() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end $$;

create or replace function public.business_data_keep_version() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.business_data_history (business_id, data, saved_at, saved_by, replaced_by, action)
  values (old.business_id, old.data, old.updated_at, old.updated_by, auth.uid(), lower(tg_op));
  delete from public.business_data_history h
   where h.business_id = old.business_id
     and h.id < (select min(id) from (select id from public.business_data_history
                  where business_id = old.business_id order by id desc limit 200) k);
  return null;
end $$;

drop trigger if exists business_data_stamp on public.business_data;
create trigger business_data_stamp before insert or update on public.business_data
  for each row execute function public.business_data_stamp();

drop trigger if exists business_data_keep_version on public.business_data;
create trigger business_data_keep_version after update or delete on public.business_data
  for each row execute function public.business_data_keep_version();

-- Owner can put back an older version (newest first: select id, replaced_at from business_data_history ...)
create or replace function public.restore_version(version_id bigint) returns void
language plpgsql security definer set search_path = public as $$
declare h record;
begin
  select * into h from public.business_data_history where id = version_id;
  if h is null or not public.is_owner(h.business_id) then raise exception 'Not allowed'; end if;
  insert into public.business_data (business_id, data) values (h.business_id, h.data)
  on conflict (business_id) do update set data = excluded.data;
end $$;

-- ---------- shop codes: stronger, and guessing is rate-limited ----------
alter table public.businesses alter column join_code set default upper(encode(gen_random_bytes(5), 'hex'));
update public.businesses set join_code = upper(encode(gen_random_bytes(5), 'hex')) where length(join_code) < 10;

create table if not exists public.join_attempts (
  user_id uuid not null,
  at timestamptz not null default now()
);
create index if not exists join_attempts_user on public.join_attempts (user_id, at desc);
alter table public.join_attempts enable row level security;  -- no policies: nobody reads it from the app

create or replace function public.join_business(code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare b uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if (select count(*) from public.join_attempts where user_id = auth.uid() and at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many tries. Wait an hour and try again.';
  end if;
  insert into public.join_attempts (user_id) values (auth.uid());
  delete from public.join_attempts where at < now() - interval '1 day';
  select id into b from public.businesses where join_code = upper(trim(code));
  if b is null then return null; end if;   -- the app shows "Invalid code"; the try still counts
  insert into public.members (business_id, user_id, role) values (b, auth.uid(), 'viewer')
  on conflict do nothing;
  return b;
end $$;

-- ---------- receipt photos ----------
update storage.buckets
   set public = false,
       file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'receipts';

drop policy if exists "members read receipts"   on storage.objects;
drop policy if exists "members write receipts"  on storage.objects;
drop policy if exists "members delete receipts" on storage.objects;
drop policy if exists "writers add receipts"    on storage.objects;
drop policy if exists "writers replace receipts" on storage.objects;
drop policy if exists "writers remove receipts" on storage.objects;

create or replace function public.receipt_shop(name text) returns uuid
language sql immutable as $$
  select case when (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
              then (storage.foldername(name))[1]::uuid end;
$$;

create policy "members read receipts" on storage.objects for select using (
  bucket_id = 'receipts' and public.is_member(public.receipt_shop(name)));
create policy "writers add receipts" on storage.objects for insert with check (
  bucket_id = 'receipts' and public.can_write(public.receipt_shop(name)));
create policy "writers replace receipts" on storage.objects for update using (
  bucket_id = 'receipts' and public.can_write(public.receipt_shop(name))) with check (
  bucket_id = 'receipts' and public.can_write(public.receipt_shop(name)));
create policy "writers remove receipts" on storage.objects for delete using (
  bucket_id = 'receipts' and public.can_write(public.receipt_shop(name)));

-- ---------- signed-out visitors get nothing ----------
revoke all on all tables in schema public from anon;
revoke execute on all functions in schema public from anon, public;
grant execute on all functions in schema public to authenticated;
revoke execute on function public.business_data_stamp() from authenticated;
revoke execute on function public.business_data_keep_version() from authenticated;
alter default privileges in schema public revoke execute on functions from anon, public;

commit;
