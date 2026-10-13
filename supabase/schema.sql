-- Split It database schema
-- Run this entire file in Supabase Dashboard > SQL Editor.

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

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

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
drop trigger if exists friendships_protect_identity on public.friendships;
create trigger friendships_protect_identity
  before update on public.friendships
  for each row execute function public.protect_friendship_identity();

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;
alter table public.friendships enable row level security;

drop policy if exists "profiles visible to collaborators" on public.profiles;
create policy "profiles visible to collaborators"
on public.profiles for select to authenticated
using (public.shares_group_with(id));
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

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
  and exists (
    select 1 from public.group_members
    where group_id = expenses.group_id and user_id = paid_by
  )
);
drop policy if exists "creators or admins delete expenses" on public.expenses;
create policy "creators or admins delete expenses"
on public.expenses for delete to authenticated
using (created_by = auth.uid() or public.is_group_admin(group_id));

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
using (created_by = auth.uid() or public.is_group_admin(group_id));

drop policy if exists "participants view friendships" on public.friendships;
create policy "participants view friendships"
on public.friendships for select to authenticated
using (auth.uid() in (requester_id, addressee_id));
drop policy if exists "users request friendships" on public.friendships;
create policy "users request friendships"
on public.friendships for insert to authenticated
with check (requester_id = auth.uid() and status = 'pending');
drop policy if exists "addressees answer friendships" on public.friendships;
create policy "addressees answer friendships"
on public.friendships for update to authenticated
using (addressee_id = auth.uid())
with check (addressee_id = auth.uid());
drop policy if exists "participants delete friendships" on public.friendships;
create policy "participants delete friendships"
on public.friendships for delete to authenticated
using (auth.uid() in (requester_id, addressee_id));

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
