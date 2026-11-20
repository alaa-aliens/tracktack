-- Tamm: team, roles and invites. Run AFTER 02-hardening.sql. Safe to run more than once.
-- What it does:
--   1. Adds the Accountant role (can add, edit and export; can't manage the team or delete the shop)
--      and the Staff role (adds sales and expenses from a simple screen; can't edit or delete).
--   2. Invites are tied to an email, work once, and expire after 14 days.
--   3. Anyone invited joins automatically the next time they sign in with that email
--      (Google or password), as long as the email is verified. No code or link needed.
--   4. Rebuilds the team functions the app uses (my_role, team, create_invite, accept_invite,
--      set_role) so they all follow the same rules. The app's calls don't change.

begin;

-- ---------- invites table: make sure every column we rely on exists ----------
create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  email text not null,
  role text not null default 'viewer',
  token text not null unique default encode(gen_random_bytes(18), 'hex'),
  accepted_at timestamptz
);
alter table public.invites add column if not exists created_at timestamptz not null default now();
alter table public.invites add column if not exists expires_at timestamptz not null default now() + interval '14 days';
alter table public.invites add column if not exists invited_by uuid;
alter table public.invites add column if not exists accepted_by uuid;
create index if not exists invites_email on public.invites (lower(email)) where accepted_at is null;
alter table public.invites enable row level security;
drop policy if exists "owner manages invites" on public.invites;
create policy "owner manages invites" on public.invites for all
  using (public.is_owner(business_id)) with check (public.is_owner(business_id));

-- ---------- one list of roles ----------
create or replace function public.valid_role(r text) returns boolean
language sql immutable as $$ select r in ('editor', 'accountant', 'staff', 'viewer') $$;

-- the signed-in user's verified email (null if not verified)
create or replace function public.my_verified_email() returns text
language sql stable security definer set search_path = public, auth as $$
  select lower(email) from auth.users
   where id = auth.uid() and email_confirmed_at is not null;
$$;

-- ---------- drop every old version of the team functions, whatever their arguments ----------
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('my_role', 'team', 'create_invite', 'accept_invite', 'set_role', 'claim_invites')
  loop
    execute 'drop function ' || f.sig;
  end loop;
end $$;

create function public.my_role(b uuid) returns text
language sql stable security definer set search_path = public as $$
  select role from public.members where business_id = b and user_id = auth.uid();
$$;

create function public.team(b uuid) returns table (user_id uuid, email text, role text)
language sql stable security definer set search_path = public, auth as $$
  select m.user_id, u.email::text, m.role
    from public.members m join auth.users u on u.id = m.user_id
   where m.business_id = b and public.is_member(b)
   order by (m.role = 'owner') desc, u.email;
$$;

create function public.create_invite(b uuid, em text, r text) returns text
language plpgsql security definer set search_path = public as $$
declare tk text;
begin
  if not public.is_owner(b) then raise exception 'Only the owner can invite people'; end if;
  if not public.valid_role(r) then raise exception 'Unknown role'; end if;
  em := lower(trim(em));
  if em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a valid email'; end if;
  -- one open invite per email per company: replace an older one
  delete from public.invites where business_id = b and lower(email) = em and accepted_at is null;
  insert into public.invites (business_id, email, role, invited_by)
  values (b, em, r, auth.uid()) returning token into tk;
  return tk;
end $$;

-- join everything this verified email was invited to
create function public.claim_invites() returns int
language plpgsql security definer set search_path = public as $$
declare em text := public.my_verified_email(); i record; n int := 0;
begin
  if auth.uid() is null or em is null then return 0; end if;
  for i in select * from public.invites
            where lower(email) = em and accepted_at is null and expires_at > now()
  loop
    insert into public.members (business_id, user_id, role) values (i.business_id, auth.uid(), i.role)
    on conflict (business_id, user_id) do update set role = excluded.role
      where public.members.role <> 'owner';
    update public.invites set accepted_at = now(), accepted_by = auth.uid() where id = i.id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- invite link (?invite=token): only works for the email it was sent to
create function public.accept_invite(tk text) returns uuid
language plpgsql security definer set search_path = public as $$
declare i record; em text := public.my_verified_email();
begin
  select * into i from public.invites where token = tk;
  if i is null or i.accepted_at is not null or i.expires_at < now() then
    raise exception 'This invite has expired or was already used. Ask the owner for a new one.';
  end if;
  if em is null or lower(i.email) <> em then
    raise exception 'This invite is for %. Sign in with that email to accept it.', i.email;
  end if;
  insert into public.members (business_id, user_id, role) values (i.business_id, auth.uid(), i.role)
  on conflict (business_id, user_id) do update set role = excluded.role
    where public.members.role <> 'owner';
  update public.invites set accepted_at = now(), accepted_by = auth.uid() where id = i.id;
  return i.business_id;
end $$;

-- owner changes someone's role, or removes them (r = 'remove')
create function public.set_role(b uuid, u uuid, r text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(b) then raise exception 'Only the owner can change roles'; end if;
  if u = auth.uid() then raise exception 'You can''t change your own role'; end if;
  if exists (select 1 from public.members where business_id = b and user_id = u and role = 'owner') then
    raise exception 'The owner''s role can''t be changed';
  end if;
  if r = 'remove' then
    delete from public.members where business_id = b and user_id = u;
  elsif public.valid_role(r) then
    update public.members set role = r where business_id = b and user_id = u;
  else
    raise exception 'Unknown role';
  end if;
end $$;

revoke execute on function public.my_role(uuid), public.team(uuid), public.create_invite(uuid, text, text),
  public.claim_invites(), public.accept_invite(text), public.set_role(uuid, uuid, text),
  public.my_verified_email() from anon, public;
grant execute on function public.my_role(uuid), public.team(uuid), public.create_invite(uuid, text, text),
  public.claim_invites(), public.accept_invite(text), public.set_role(uuid, uuid, text) to authenticated;

commit;
