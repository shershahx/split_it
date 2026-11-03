-- Apply AFTER schema.sql, including on projects that already ran schema.sql.
-- Run this whole file in one SQL Editor request. Safe to rerun.
begin;

-- Membership identity/roles must not be freely edited, even by a group owner.
-- Owner creation remains an atomic database trigger; joining uses invitations.
drop policy if exists "admins add members" on public.group_members;
drop policy if exists "admins update memberships" on public.group_members;
drop policy if exists "admins remove members" on public.group_members;
drop policy if exists "admins manage invites" on public.group_invites;

-- Direct invitation writes are intentionally disallowed. RPCs control sender,
-- normalization, status, and expiry. Members can only read relevant invitations.
drop policy if exists "admins and recipients view invites" on public.group_invites;
create policy "admins and recipients view invites"
on public.group_invites for select to authenticated
using (
  public.is_group_admin(group_id)
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);

-- Disallow duplicate pending invites that differ only by email case.
-- Existing ambiguous records need manual review, not silent data deletion.
create unique index if not exists group_invites_group_email_normalized_idx
  on public.group_invites(group_id, lower(email));

create or replace function public.send_group_invite(
  target_group_id uuid,
  invite_email text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(trim(invite_email));
  result_id uuid;
begin
  if auth.uid() is null or not public.is_group_admin(target_group_id) then
    raise exception 'Only group admins can invite members' using errcode = '42501';
  end if;
  if normalized_email is null or length(normalized_email) > 254
     or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid email address';
  end if;
  if normalized_email = lower(coalesce(auth.jwt() ->> 'email', '')) then
    raise exception 'You cannot invite yourself';
  end if;
  if exists (
    select 1 from public.group_members m
    join auth.users u on u.id = m.user_id
    where m.group_id = target_group_id and lower(u.email) = normalized_email
  ) then
    raise exception 'This person is already a member';
  end if;

  -- Re-sending renews the one invitation rather than creating duplicates.
  insert into public.group_invites (group_id, email, invited_by)
  values (target_group_id, normalized_email, auth.uid())
  on conflict (group_id, lower(email)) do update
    set email = excluded.email,
        invited_by = excluded.invited_by,
        status = 'pending',
        expires_at = now() + interval '7 days',
        created_at = now()
  returning id into result_id;
  return result_id;
end;
$$;

-- The recipient cannot SELECT a group's row until they join. Return only the
-- limited invitation preview instead of weakening group/profile SELECT policies.
create or replace function public.list_my_group_invites(page_offset integer default 0)
returns table (
  id uuid,
  group_name text,
  invited_by_name text,
  expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if page_offset is null or page_offset < 0 then
    raise exception 'Invalid page offset';
  end if;
  return query
    select i.id, g.name, p.display_name, i.expires_at
    from public.group_invites i
    join public.groups g on g.id = i.group_id
    join public.profiles p on p.id = i.invited_by
    where lower(i.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and i.status = 'pending'
      and i.expires_at > now()
    order by i.created_at desc, i.id
    limit 21 offset page_offset;
end;
$$;

create or replace function public.decline_group_invite(invite_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  update public.group_invites
  set status = 'declined'
  where id = invite_id and status = 'pending' and expires_at > now()
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''));
  if not found then
    raise exception 'Invitation is invalid or expired';
  end if;
end;
$$;

create or replace function public.accept_group_invite(invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepted_group_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select i.group_id into accepted_group_id
  from public.group_invites i
  where i.id = invite_id and i.status = 'pending' and i.expires_at > now()
    and lower(i.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  for update;
  if accepted_group_id is null then
    raise exception 'Invitation is invalid or expired';
  end if;
  insert into public.group_members (group_id, user_id, role)
  values (accepted_group_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;
  update public.group_invites set status = 'accepted' where id = invite_id;
  return accepted_group_id;
end;
$$;

revoke all on function public.send_group_invite(uuid, text) from public, anon;
revoke all on function public.list_my_group_invites(integer) from public, anon;
revoke all on function public.decline_group_invite(uuid) from public, anon;
revoke all on function public.accept_group_invite(uuid) from public, anon;
grant execute on function public.send_group_invite(uuid, text) to authenticated;
grant execute on function public.list_my_group_invites(integer) to authenticated;
grant execute on function public.decline_group_invite(uuid) to authenticated;
grant execute on function public.accept_group_invite(uuid) to authenticated;

commit;
