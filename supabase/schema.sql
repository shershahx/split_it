-- Split It database schema
<<<<<<< HEAD
-- Run this entire file as the database owner in Supabase Dashboard > SQL Editor.
-- Atomic and rerunnable. Back up first; an existing reversed friendship duplicate
-- must be reconciled before the unique unordered-pair index can be created.
begin;
=======
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- INITIAL BOOTSTRAP ONLY: then apply every file in migrations/ in order.
-- On existing projects apply new migrations, not this bootstrap again.
-- Rerunning this file alone restores obsolete membership/invitation policies.
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  description text check (description is null or char_length(description) <= 500),
  image_url text,
  currency text not null default 'USD'
    check (currency ~ '^[A-Z]{3}$'),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  email text not null,
  invited_by uuid not null references public.profiles(id),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  unique (group_id, email)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  description text not null check (char_length(description) between 1 and 200),
  amount_minor bigint not null check (amount_minor > 0),
  paid_by uuid not null references public.profiles(id),
  expense_date timestamptz not null default now(),
  receipt_path text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expense_splits (
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  amount_minor bigint not null check (amount_minor >= 0),
  primary key (expense_id, user_id)
);

create table if not exists public.settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  paid_by uuid not null references public.profiles(id),
  paid_to uuid not null references public.profiles(id),
  amount_minor bigint not null check (amount_minor > 0),
  settled_at timestamptz not null default now(),
  note text check (note is null or char_length(note) <= 300),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (paid_by <> paid_to)
);

<<<<<<< HEAD
-- Keep these per-record limits aligned with Money.maxMinorUnits in Dart.
-- Revalidate existing data; never silently clamp a historical ledger amount.
alter table public.expenses drop constraint if exists expenses_amount_minor_max;
alter table public.expenses add constraint expenses_amount_minor_max
  check (amount_minor <= 999999999999);
alter table public.expense_splits drop constraint if exists expense_splits_amount_minor_max;
alter table public.expense_splits add constraint expense_splits_amount_minor_max
  check (amount_minor <= 999999999999);
alter table public.settlements drop constraint if exists settlements_amount_minor_max;
alter table public.settlements add constraint settlements_amount_minor_max
  check (amount_minor <= 999999999999);

=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
create table if not exists public.friendships (
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create index if not exists group_members_user_id_idx
  on public.group_members(user_id);
create index if not exists group_invites_email_idx
  on public.group_invites(lower(email));
create index if not exists expenses_group_date_idx
  on public.expenses(group_id, expense_date desc);
create index if not exists expenses_paid_by_idx
  on public.expenses(paid_by);
create index if not exists expense_splits_user_id_idx
  on public.expense_splits(user_id);
create index if not exists settlements_group_date_idx
  on public.settlements(group_id, settled_at desc);
create index if not exists friendships_addressee_idx
  on public.friendships(addressee_id, status);

create or replace function public.is_group_member(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members
    where group_id = target_group_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_group_admin(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members
    where group_id = target_group_id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
  );
$$;

create or replace function public.is_group_owner(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members
    where group_id = target_group_id
      and user_id = auth.uid()
      and role = 'owner'
  );
$$;

create or replace function public.shares_group_with(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() = other_user_id or exists (
    select 1
    from public.group_members mine
    join public.group_members theirs using (group_id)
    where mine.user_id = auth.uid()
      and theirs.user_id = other_user_id
  );
$$;

revoke all on function public.is_group_member(uuid) from public;
revoke all on function public.is_group_admin(uuid) from public;
revoke all on function public.is_group_owner(uuid) from public;
revoke all on function public.shares_group_with(uuid) from public;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_admin(uuid) to authenticated;
grant execute on function public.is_group_owner(uuid) to authenticated;
grant execute on function public.shares_group_with(uuid) to authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

<<<<<<< HEAD
-- Shared projection for signup, Auth updates, and missing-profile backfill.
-- Missing names use the email prefix (or User); explicitly invalid names never
-- silently fall back or truncate. PostgreSQL char_length counts Unicode codepoints.
create or replace function public._profile_metadata(p_metadata jsonb, p_email text)
returns table (display_name text, avatar_url text)
language plpgsql immutable set search_path = '' as $$
begin
  p_metadata := coalesce(p_metadata, '{}'::jsonb);
  if jsonb_typeof(p_metadata) is distinct from 'object' then
    raise exception 'User metadata must be an object' using errcode = '22023';
  end if;
  if p_metadata ? 'display_name' then
    if jsonb_typeof(p_metadata -> 'display_name') is distinct from 'string' then
      raise exception 'Display name must be a string of 1 to 80 characters' using errcode = '22023';
    end if;
    display_name := p_metadata ->> 'display_name';
  else
    display_name := coalesce(nullif(split_part(p_email, '@', 1), ''), 'User');
  end if;
  display_name := regexp_replace(display_name, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  if char_length(display_name) not between 1 and 80 then
    raise exception 'Display name must be between 1 and 80 characters' using errcode = '22023';
  end if;
  if p_metadata ? 'avatar_url'
     and jsonb_typeof(p_metadata -> 'avatar_url') not in ('string', 'null') then
    raise exception 'Avatar URL must be a string or null' using errcode = '22023';
  end if;
  avatar_url := p_metadata ->> 'avatar_url';
  return next;
end;
$$;

-- The Auth write and this profile upsert share one transaction. Any validation
-- or profile-write failure aborts the Auth change too; clients must not dual-write
-- profiles or attempt a separate best-effort metadata rollback.
=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
<<<<<<< HEAD
set search_path = ''
as $$
begin
  insert into public.profiles as p (id, display_name, avatar_url)
  select new.id, m.display_name, m.avatar_url
  from public._profile_metadata(new.raw_user_meta_data, new.email) m
  on conflict (id) do update
    set display_name = excluded.display_name, avatar_url = excluded.avatar_url
    where p.display_name is distinct from excluded.display_name
       or p.avatar_url is distinct from excluded.avatar_url;
=======
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    left(
      coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
        split_part(coalesce(new.email, 'User'), '@', 1)
      ),
      80
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.handle_updated_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set
    display_name = left(
      coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
        display_name
      ),
      80
    ),
    avatar_url = new.raw_user_meta_data ->> 'avatar_url'
  where id = new.id;
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
  return new;
end;
$$;

create or replace function public.add_group_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.group_members (group_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

create or replace function public.protect_group_identity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id <> old.id or new.created_by <> old.created_by then
    raise exception 'Group identity fields cannot be changed';
  end if;
  return new;
end;
$$;

create or replace function public.protect_expense_identity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id <> old.id
     or new.group_id <> old.group_id
     or new.created_by <> old.created_by then
    raise exception 'Expense identity fields cannot be changed';
  end if;
  return new;
end;
$$;

<<<<<<< HEAD
=======
create or replace function public.protect_friendship_identity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.requester_id <> old.requester_id
     or new.addressee_id <> old.addressee_id
     or new.created_at <> old.created_at then
    raise exception 'Friendship identity fields cannot be changed';
  end if;
  return new;
end;
$$;

>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

<<<<<<< HEAD
drop trigger if exists on_auth_user_metadata_updated on auth.users;
create trigger on_auth_user_metadata_updated
  after update of raw_user_meta_data, email on auth.users
  for each row
  when (old.raw_user_meta_data is distinct from new.raw_user_meta_data
        or old.email is distinct from new.email)
  execute function public.handle_new_user();

insert into public.profiles (id, display_name, avatar_url)
select u.id, m.display_name, m.avatar_url
from auth.users u
cross join lateral public._profile_metadata(u.raw_user_meta_data, u.email) m
where not exists (select 1 from public.profiles p where p.id = u.id)
=======
drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of raw_user_meta_data on auth.users
  for each row execute function public.handle_updated_user();

insert into public.profiles (id, display_name, avatar_url)
select
  id,
  left(
    coalesce(
      nullif(trim(raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(email, 'User'), '@', 1)
    ),
    80
  ),
  raw_user_meta_data ->> 'avatar_url'
from auth.users
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
on conflict (id) do nothing;

drop trigger if exists on_group_created on public.groups;
create trigger on_group_created
  after insert on public.groups
  for each row execute function public.add_group_owner();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
drop trigger if exists groups_set_updated_at on public.groups;
create trigger groups_set_updated_at
  before update on public.groups
  for each row execute function public.set_updated_at();
drop trigger if exists groups_protect_identity on public.groups;
create trigger groups_protect_identity
  before update on public.groups
  for each row execute function public.protect_group_identity();
drop trigger if exists expenses_set_updated_at on public.expenses;
create trigger expenses_set_updated_at
  before update on public.expenses
  for each row execute function public.set_updated_at();
drop trigger if exists expenses_protect_identity on public.expenses;
create trigger expenses_protect_identity
  before update on public.expenses
  for each row execute function public.protect_expense_identity();
drop trigger if exists friendships_set_updated_at on public.friendships;
create trigger friendships_set_updated_at
  before update on public.friendships
  for each row execute function public.set_updated_at();
<<<<<<< HEAD
=======
drop trigger if exists friendships_protect_identity on public.friendships;
create trigger friendships_protect_identity
  before update on public.friendships
  for each row execute function public.protect_friendship_identity();
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;
alter table public.friendships enable row level security;

<<<<<<< HEAD
-- PostgreSQL 15+ security_invoker preserves the caller's underlying RLS.
-- Children are scalar SQL aggregates, NOT PostgREST embedded resources, so API
-- row caps cannot truncate members/splits. Each parent and its children use one
-- statement snapshot, including single-record reads during concurrent edits.
create or replace view public.group_records with (security_invoker = true) as
select g.*, array(
  select gm.user_id from public.group_members gm
  where gm.group_id = g.id order by gm.user_id
) as member_ids
from public.groups g;

create or replace view public.expense_records with (security_invoker = true) as
select e.*, coalesce((
  select jsonb_agg(jsonb_build_object('user_id', s.user_id, 'amount_minor', s.amount_minor)
                   order by s.user_id)
  from public.expense_splits s where s.expense_id = e.id
), '[]'::jsonb) as expense_splits
from public.expenses e;

revoke all on public.group_records, public.expense_records from public, anon, authenticated;
grant select on public.group_records, public.expense_records to authenticated;

=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
drop policy if exists "profiles visible to collaborators" on public.profiles;
create policy "profiles visible to collaborators"
on public.profiles for select to authenticated
using (public.shares_group_with(id));
<<<<<<< HEAD
-- Auth metadata is authoritative; clients cannot diverge the public profile.
drop policy if exists "users update own profile" on public.profiles;
=======
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

drop policy if exists "members view groups" on public.groups;
create policy "members view groups"
on public.groups for select to authenticated
using (public.is_group_member(id));
drop policy if exists "users create groups" on public.groups;
create policy "users create groups"
on public.groups for insert to authenticated
with check (created_by = auth.uid());
drop policy if exists "admins update groups" on public.groups;
create policy "admins update groups"
on public.groups for update to authenticated
using (public.is_group_admin(id))
with check (public.is_group_admin(id));
drop policy if exists "owners delete groups" on public.groups;
create policy "owners delete groups"
on public.groups for delete to authenticated
using (public.is_group_owner(id));

drop policy if exists "members view memberships" on public.group_members;
create policy "members view memberships"
on public.group_members for select to authenticated
using (public.is_group_member(group_id));
drop policy if exists "admins add members" on public.group_members;
create policy "admins add members"
on public.group_members for insert to authenticated
with check (
  public.is_group_admin(group_id)
  and (role = 'member' or public.is_group_owner(group_id))
);
drop policy if exists "admins update memberships" on public.group_members;
create policy "admins update memberships"
on public.group_members for update to authenticated
using (public.is_group_owner(group_id))
with check (public.is_group_owner(group_id));
drop policy if exists "admins remove members" on public.group_members;
create policy "admins remove members"
on public.group_members for delete to authenticated
using (
  (public.is_group_admin(group_id) and role <> 'owner')
  or (user_id = auth.uid() and role <> 'owner')
);

drop policy if exists "admins manage invites" on public.group_invites;
create policy "admins manage invites"
on public.group_invites for all to authenticated
using (
  public.is_group_admin(group_id)
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
)
with check (
  public.is_group_admin(group_id)
  and invited_by = auth.uid()
);

<<<<<<< HEAD
=======
create or replace function public.accept_group_invite(invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  accepted_group_id uuid;
begin
  select group_id
  into accepted_group_id
  from public.group_invites
  where id = invite_id
    and status = 'pending'
    and expires_at > now()
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  for update;

  if accepted_group_id is null then
    raise exception 'Invitation is invalid or expired';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (accepted_group_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  update public.group_invites
  set status = 'accepted'
  where id = invite_id;

  return accepted_group_id;
end;
$$;

revoke all on function public.accept_group_invite(uuid) from public;
grant execute on function public.accept_group_invite(uuid) to authenticated;

>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
drop policy if exists "members view expenses" on public.expenses;
create policy "members view expenses"
on public.expenses for select to authenticated
using (public.is_group_member(group_id));
drop policy if exists "members create expenses" on public.expenses;
create policy "members create expenses"
on public.expenses for insert to authenticated
with check (
  public.is_group_member(group_id)
  and created_by = auth.uid()
  and exists (
    select 1 from public.group_members
    where group_id = expenses.group_id and user_id = paid_by
  )
);
drop policy if exists "creators or admins update expenses" on public.expenses;
create policy "creators or admins update expenses"
on public.expenses for update to authenticated
using (created_by = auth.uid() or public.is_group_admin(group_id))
with check (
  public.is_group_member(group_id)
  and (created_by = auth.uid() or public.is_group_admin(group_id))
<<<<<<< HEAD
=======
  and exists (
    select 1 from public.group_members
    where group_id = expenses.group_id and user_id = paid_by
  )
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
);
drop policy if exists "creators or admins delete expenses" on public.expenses;
create policy "creators or admins delete expenses"
on public.expenses for delete to authenticated
<<<<<<< HEAD
using (
  public.is_group_member(group_id)
  and (created_by = auth.uid() or public.is_group_admin(group_id))
);
=======
using (created_by = auth.uid() or public.is_group_admin(group_id));
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

drop policy if exists "members view splits" on public.expense_splits;
create policy "members view splits"
on public.expense_splits for select to authenticated
using (
  exists (
    select 1 from public.expenses
    where id = expense_id and public.is_group_member(group_id)
  )
);
drop policy if exists "expense creators manage splits" on public.expense_splits;
create policy "expense creators manage splits"
on public.expense_splits for all to authenticated
using (
  exists (
    select 1 from public.expenses
    where id = expense_id
      and (created_by = auth.uid() or public.is_group_admin(group_id))
  )
)
with check (
  exists (
    select 1
    from public.expenses e
    join public.group_members gm
      on gm.group_id = e.group_id and gm.user_id = expense_splits.user_id
    where e.id = expense_id and e.created_by = auth.uid()
  )
);

drop policy if exists "members view settlements" on public.settlements;
create policy "members view settlements"
on public.settlements for select to authenticated
using (public.is_group_member(group_id));
drop policy if exists "members create settlements" on public.settlements;
create policy "members create settlements"
on public.settlements for insert to authenticated
with check (
  public.is_group_member(group_id)
  and created_by = auth.uid()
  and paid_by = auth.uid()
  and exists (
    select 1 from public.group_members
    where group_id = settlements.group_id and user_id = paid_to
  )
);
drop policy if exists "creators or admins delete settlements" on public.settlements;
create policy "creators or admins delete settlements"
on public.settlements for delete to authenticated
<<<<<<< HEAD
using (public.is_group_member(group_id) and paid_by = auth.uid()
       and created_by = auth.uid());
=======
using (created_by = auth.uid() or public.is_group_admin(group_id));
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

drop policy if exists "participants view friendships" on public.friendships;
create policy "participants view friendships"
on public.friendships for select to authenticated
<<<<<<< HEAD
using (
  addressee_id = auth.uid()
  or (status = 'accepted' and requester_id = auth.uid())
);
drop policy if exists "users request friendships" on public.friendships;
create policy "users request friendships"
on public.friendships for insert to authenticated
with check (requester_id = auth.uid());
=======
using (auth.uid() in (requester_id, addressee_id));
drop policy if exists "users request friendships" on public.friendships;
create policy "users request friendships"
on public.friendships for insert to authenticated
with check (requester_id = auth.uid() and status = 'pending');
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
drop policy if exists "addressees answer friendships" on public.friendships;
create policy "addressees answer friendships"
on public.friendships for update to authenticated
using (addressee_id = auth.uid())
with check (addressee_id = auth.uid());
drop policy if exists "participants delete friendships" on public.friendships;
create policy "participants delete friendships"
on public.friendships for delete to authenticated
using (auth.uid() in (requester_id, addressee_id));

<<<<<<< HEAD
-- RPCs are the only untrusted write boundary for these tables. RLS alone
-- cannot ensure a complete expense and its splits are saved atomically.
-- Remove legacy write policies as well as grants, so even a column-level grant
-- cannot accidentally reopen the old nontransactional/direct-acceptance paths.
drop policy if exists "users create groups" on public.groups;
drop policy if exists "admins update groups" on public.groups;
drop policy if exists "admins add members" on public.group_members;
drop policy if exists "admins update memberships" on public.group_members;
drop policy if exists "admins remove members" on public.group_members;
drop policy if exists "members create expenses" on public.expenses;
drop policy if exists "creators or admins update expenses" on public.expenses;
drop policy if exists "expense creators manage splits" on public.expense_splits;
drop policy if exists "members create settlements" on public.settlements;
drop policy if exists "users request friendships" on public.friendships;
drop policy if exists "addressees answer friendships" on public.friendships;
drop policy if exists "participants delete friendships" on public.friendships;
revoke create on schema public from public, anon, authenticated;
revoke all on public.profiles, public.groups, public.group_members,
  public.group_invites, public.expenses, public.expense_splits,
  public.settlements, public.friendships from public, anon, authenticated;
grant usage on schema public to authenticated;
grant select on public.profiles, public.groups, public.group_members,
  public.group_invites, public.expenses, public.expense_splits,
  public.settlements, public.friendships to authenticated;
-- Table-level REVOKE does not remove previous column-level UPDATE grants.
revoke update (display_name, avatar_url) on public.profiles from public, anon, authenticated;
grant delete on public.groups, public.expenses, public.settlements to authenticated;

create unique index if not exists friendships_unordered_pair_idx
  on public.friendships (least(requester_id, addressee_id),
                         greatest(requester_id, addressee_id));

-- Internal helper: caller must hold the group row lock and authorize its admin.
-- An existing member is never removed or demoted by a stale client snapshot.
create or replace function public._add_group_members(p_group_id uuid, p_member_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_member_ids is null or array_position(p_member_ids, null) is not null then
    raise exception 'Member IDs must not be null' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_member_ids) as m(id)
    where not exists (
      select 1 from public.group_members gm
      where gm.group_id = p_group_id and gm.user_id = m.id
    ) and not exists (
      select 1 from public.friendships f
      where f.status = 'accepted' and
        ((f.requester_id = auth.uid() and f.addressee_id = m.id)
         or (f.addressee_id = auth.uid() and f.requester_id = m.id))
    )
  ) then
    raise exception 'New members must be accepted friends' using errcode = '42501';
  end if;
  insert into public.group_members (group_id, user_id)
  select p_group_id, m.id from unnest(p_member_ids) as m(id)
  on conflict (group_id, user_id) do nothing;
end;
$$;

create or replace function public.create_group(
  p_id uuid, p_name text, p_description text, p_image_url text,
  p_currency text, p_member_ids uuid[], p_created_by uuid
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or p_created_by is distinct from auth.uid() then
    raise exception 'Create groups only as yourself' using errcode = '42501';
  end if;
  insert into public.groups (id, name, description, image_url, currency, created_by)
  values (p_id, trim(p_name), p_description, p_image_url, p_currency, auth.uid());
  -- The existing owner trigger inserts the creator before any additional members.
  perform public._add_group_members(p_id, p_member_ids);
end;
$$;

create or replace function public.update_group(
  p_id uuid, p_name text, p_description text, p_image_url text,
  p_currency text, p_member_ids uuid[], p_created_by uuid
) returns void language plpgsql security definer set search_path = '' as $$
declare g public.groups%rowtype;
begin
  select * into g from public.groups where id = p_id for update;
  if not found or public.is_group_admin(p_id) is not true then
    raise exception 'Group admin access required' using errcode = '42501';
  end if;
  if p_created_by is distinct from g.created_by then
    raise exception 'Group creator cannot change' using errcode = '22023';
  end if;
  if p_currency is distinct from g.currency and (
    exists (select 1 from public.expenses where group_id = p_id)
    or exists (select 1 from public.settlements where group_id = p_id)
  ) then
    raise exception 'Cannot change currency after financial activity' using errcode = '22023';
  end if;
  update public.groups set name = trim(p_name), description = p_description,
    image_url = p_image_url, currency = p_currency where id = p_id;
  perform public._add_group_members(p_id, p_member_ids);
end;
$$;

create or replace function public.add_group_member(p_group_id uuid, p_member_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.groups where id = p_group_id for update;
  if not found or public.is_group_admin(p_group_id) is not true then
    raise exception 'Group admin access required' using errcode = '42501';
  end if;
  perform public._add_group_members(p_group_id, array[p_member_id]);
end;
$$;

create or replace function public.save_expense(
  p_id uuid, p_group_id uuid, p_description text, p_amount_minor bigint,
  p_paid_by uuid, p_expense_date timestamptz, p_receipt_path text,
  p_created_by uuid, p_splits jsonb
) returns void language plpgsql security definer set search_path = '' as $$
declare
  previous public.expenses%rowtype;
  split_count integer;
  unique_count integer;
  split_total numeric;
begin
  -- Serialize writes within a group, including metadata/currency changes.
  perform 1 from public.groups where id = p_group_id for update;
  if not found or public.is_group_member(p_group_id) is not true then
    raise exception 'Group membership required' using errcode = '42501';
  end if;
  select * into previous from public.expenses where id = p_id for update;
  if found then
    if previous.group_id is distinct from p_group_id
       or previous.created_by is distinct from p_created_by
       or (previous.created_by is distinct from auth.uid()
           and public.is_group_admin(p_group_id) is not true) then
      raise exception 'Expense identity or permission mismatch' using errcode = '42501';
    end if;
  elsif p_created_by is distinct from auth.uid() then
    raise exception 'Create expenses only as yourself' using errcode = '42501';
  end if;
  if p_amount_minor is null or p_amount_minor not between 1 and 999999999999
     or p_expense_date is null or not isfinite(p_expense_date) then
    raise exception 'Invalid amount or date' using errcode = '22023';
  end if;
  if not exists (select 1 from public.group_members
                 where group_id = p_group_id and user_id = p_paid_by) then
    raise exception 'Payer must belong to the group' using errcode = '22023';
  end if;
  if jsonb_typeof(p_splits) is distinct from 'array' then
    raise exception 'Splits must be an array' using errcode = '22023';
  end if;
  -- Validate numeric JSON before bigint conversion (Postgres would round 1.5).
  if exists (
    select 1 from jsonb_array_elements(p_splits) s
    where jsonb_typeof(s) is distinct from 'object'
      or jsonb_typeof(s -> 'user_id') is distinct from 'string'
      or jsonb_typeof(s -> 'amount_minor') is distinct from 'number'
  ) then
    raise exception 'Malformed split' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_splits) s
    where (s ->> 'amount_minor')::numeric < 0
      or (s ->> 'amount_minor')::numeric > 999999999999
      or trunc((s ->> 'amount_minor')::numeric) <> (s ->> 'amount_minor')::numeric
  ) then
    raise exception 'Splits require nonnegative integer cents' using errcode = '22023';
  end if;
  select count(*), count(distinct (s ->> 'user_id')::uuid),
         sum((s ->> 'amount_minor')::numeric)
    into split_count, unique_count, split_total
    from jsonb_array_elements(p_splits) s;
  if split_count = 0 or split_count <> unique_count
     or split_total is distinct from p_amount_minor::numeric then
    raise exception 'Unique splits must sum exactly to the amount' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_splits) s
    where not exists (select 1 from public.group_members gm
      where gm.group_id = p_group_id and gm.user_id = (s ->> 'user_id')::uuid)
  ) then
    raise exception 'All split participants must belong to the group' using errcode = '22023';
  end if;
  insert into public.expenses
    (id, group_id, description, amount_minor, paid_by, expense_date, receipt_path, created_by)
  values (p_id, p_group_id, trim(p_description), p_amount_minor, p_paid_by,
          p_expense_date, p_receipt_path, p_created_by)
  on conflict (id) do update set description = excluded.description,
    amount_minor = excluded.amount_minor, paid_by = excluded.paid_by,
    expense_date = excluded.expense_date, receipt_path = excluded.receipt_path
  where expenses.group_id = p_group_id and expenses.created_by = p_created_by
    and (expenses.created_by = auth.uid() or public.is_group_admin(p_group_id));
  if not found then
    raise exception 'Concurrent expense identity mismatch' using errcode = '42501';
  end if;
  delete from public.expense_splits where expense_id = p_id;
  insert into public.expense_splits (expense_id, user_id, amount_minor)
  select p_id, (s ->> 'user_id')::uuid, (s ->> 'amount_minor')::numeric::bigint
  from jsonb_array_elements(p_splits) s;
end;
$$;

create or replace function public.save_settlement(
  p_id uuid, p_group_id uuid, p_paid_by uuid, p_paid_to uuid,
  p_amount_minor bigint, p_settled_at timestamptz, p_note text
) returns void language plpgsql security definer set search_path = '' as $$
declare previous public.settlements%rowtype;
begin
  perform 1 from public.groups where id = p_group_id for update;
  if not found or public.is_group_member(p_group_id) is not true
     or p_paid_by is distinct from auth.uid() then
    raise exception 'Record only your own group payments' using errcode = '42501';
  end if;
  if p_amount_minor is null or p_amount_minor not between 1 and 999999999999
     or p_paid_to is not distinct from p_paid_by
     or p_settled_at is null or not isfinite(p_settled_at)
     or not exists (select 1 from public.group_members
                    where group_id = p_group_id and user_id = p_paid_to) then
    raise exception 'Invalid payment amount, recipient, or date' using errcode = '22023';
  end if;
  select * into previous from public.settlements where id = p_id for update;
  if found and (previous.group_id is distinct from p_group_id
    or previous.paid_by is distinct from auth.uid()
    or previous.created_by is distinct from auth.uid()) then
    raise exception 'Payment identity or permission mismatch' using errcode = '42501';
  end if;
  insert into public.settlements
    (id, group_id, paid_by, paid_to, amount_minor, settled_at, note, created_by)
  values (p_id, p_group_id, auth.uid(), p_paid_to, p_amount_minor, p_settled_at, p_note, auth.uid())
  on conflict (id) do update set paid_to = excluded.paid_to,
    amount_minor = excluded.amount_minor, settled_at = excluded.settled_at, note = excluded.note
  where settlements.group_id = p_group_id and settlements.paid_by = auth.uid()
    and settlements.created_by = auth.uid();
  if not found then
    raise exception 'Concurrent payment identity mismatch' using errcode = '42501';
  end if;
end;
$$;

-- No UUID/profile/email is returned from lookup. Missing, unconfirmed, self,
-- blocked, declined, duplicate, and reverse-pending requests all return void.
-- A reverse request does NOT imply acceptance; only the addressee can accept.
-- Outgoing pending targets are hidden in reads, including the underlying table,
-- to avoid turning requests/listing into an account-email lookup service.
create or replace function public.add_friend_by_email(p_email text)
returns void language plpgsql security definer set search_path = '' as $$
declare target_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to request friendship' using errcode = '42501';
  end if;
  if p_email is null or char_length(trim(p_email)) > 254
     or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'A valid email is required' using errcode = '22023';
  end if;
  select id into target_id from auth.users
    where lower(email) = lower(trim(p_email)) and email_confirmed_at is not null;
  if target_id is null or target_id = auth.uid() then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    least(auth.uid(), target_id)::text || greatest(auth.uid(), target_id)::text, 0));
  if exists (select 1 from public.friendships
    where least(requester_id, addressee_id) = least(auth.uid(), target_id)
      and greatest(requester_id, addressee_id) = greatest(auth.uid(), target_id)) then
    return;
  end if;
  insert into public.friendships (requester_id, addressee_id, status)
  values (auth.uid(), target_id, 'pending');
end;
$$;

create or replace function public.list_friends(p_user_id uuid)
returns table (id uuid, display_name text, email text, avatar_url text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'View only your own friends' using errcode = '42501';
  end if;
  return query
  select p.id, p.display_name, u.email::text, p.avatar_url
  from public.friendships f
  join public.profiles p on p.id = case when f.requester_id = auth.uid()
    then f.addressee_id else f.requester_id end
  join auth.users u on u.id = p.id
  where f.status = 'accepted' and auth.uid() in (f.requester_id, f.addressee_id)
  order by p.display_name, p.id;
end;
$$;

create or replace function public.list_friend_requests()
returns table (requester_id uuid, addressee_id uuid, display_name text,
               avatar_url text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select f.requester_id, f.addressee_id, p.display_name, p.avatar_url, f.created_at
  from public.friendships f
  join public.profiles p on p.id = case when f.requester_id = auth.uid()
    then f.addressee_id else f.requester_id end
  where f.status = 'pending' and f.addressee_id = auth.uid()
  order by f.created_at desc;
$$;

create or replace function public.respond_friend_request(p_requester_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or p_accept is null then
    raise exception 'Sign in and choose a response' using errcode = '42501';
  end if;
  update public.friendships set status = case when p_accept then 'accepted' else 'declined' end
  where requester_id = p_requester_id and addressee_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'No incoming pending request' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.remove_friend(p_friend_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in to remove friendship' using errcode = '42501';
  end if;
  delete from public.friendships where status <> 'blocked' and
    ((requester_id = auth.uid() and addressee_id = p_friend_id)
     or (addressee_id = auth.uid() and requester_id = p_friend_id));
end;
$$;

-- Never rely on Supabase default function privileges: PUBLIC gets EXECUTE by
-- default, and projects may also have explicit anon/authenticated defaults.
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as signature, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any (array[
      '_profile_metadata', '_add_group_members', 'create_group', 'update_group', 'add_group_member',
      'save_expense', 'save_settlement', 'add_friend_by_email', 'list_friends',
      'list_friend_requests', 'respond_friend_request', 'remove_friend',
      'is_group_member', 'is_group_admin', 'is_group_owner', 'shares_group_with',
      'set_updated_at', 'handle_new_user', 'add_group_owner',
      'protect_group_identity', 'protect_expense_identity'
    ])
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.signature);
    if f.proname <> all (array['_profile_metadata', '_add_group_members', 'set_updated_at',
      'handle_new_user', 'add_group_owner', 'protect_group_identity', 'protect_expense_identity']) then
      execute format('grant execute on function %s to authenticated', f.signature);
    end if;
  end loop;
end;
$$;

=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
-- Realtime is opt-in. These blocks are safe to rerun.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'expenses'
  ) then
    alter publication supabase_realtime add table public.expenses;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'settlements'
  ) then
    alter publication supabase_realtime add table public.settlements;
  end if;
end
$$;
<<<<<<< HEAD

notify pgrst, 'reload schema';
commit;
=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
