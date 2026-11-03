-- Run via run_groups.sql, in a disposable local database only.
begin;
create function pg_temp.ok(label text, passed boolean) returns void
language plpgsql as $$
begin
  if passed is distinct from true then raise exception 'FAIL: %', label; end if;
  raise notice 'PASS: %', label;
end;
$$;
create function pg_temp.fails(label text, statement text, expected text default 'P0001')
returns void language plpgsql as $$
declare actual text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual = returned_sqlstate;
  end;
  if actual is distinct from expected then
    raise exception 'FAIL: % expected %, got %', label, expected, actual;
  end if;
  raise notice 'PASS: %', label;
end;
$$;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'owner@example.com'),
  ('00000000-0000-0000-0000-000000000002', 'member@example.com'),
  ('00000000-0000-0000-0000-000000000003', 'outsider@example.com'),
  ('00000000-0000-0000-0000-000000000004', 'other@example.com');
set role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","email":"owner@example.com"}', false);
insert into public.groups (id, name, created_by) values
  ('10000000-0000-0000-0000-000000000001', 'Trip', auth.uid());
select pg_temp.ok('Atomic owner creation', (select count(*) = 1
  from public.group_members where user_id = auth.uid() and role = 'owner'));
select pg_temp.fails('Cannot spoof group creator', $q$
  insert into public.groups (name, created_by)
  values ('Spoof', '00000000-0000-0000-0000-000000000002')$q$, '42501');
select pg_temp.fails('Owner cannot insert raw membership', $q$
  insert into public.group_members (group_id, user_id)
  values ('10000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000002')$q$, '42501');
with changed as (
  update public.group_members set role = 'member' returning *
) select pg_temp.ok('Owner cannot rewrite roles', count(*) = 0) from changed;
select pg_temp.fails('Group identity cannot change', $q$
  update public.groups set created_by = '00000000-0000-0000-0000-000000000002'
$q$);
select pg_temp.fails('INSERT RETURNING is not safe before owner AFTER trigger', $q$
  insert into public.groups (name, created_by) values ('Returning', auth.uid())
  returning id$q$, '42501');
select pg_temp.ok('Failed RETURNING insert rolled back', (select count(*) = 1 from public.groups));
select pg_temp.fails('Cannot self invite', $q$
  select public.send_group_invite('10000000-0000-0000-0000-000000000001', 'OWNER@example.com')
$q$);
select pg_temp.fails('Malformed email rejected', $q$
  select public.send_group_invite('10000000-0000-0000-0000-000000000001', 'not-email')
$q$);
select public.send_group_invite(
  '10000000-0000-0000-0000-000000000001', ' MEMBER@Example.com ') as invite_id \gset
select public.send_group_invite(
  '10000000-0000-0000-0000-000000000001', 'other@example.com') as other_id \gset
select pg_temp.ok('Email normalized', (select email = 'member@example.com'
  from public.group_invites where id = :'invite_id'));
select pg_temp.ok('Resend renews same invitation', public.send_group_invite(
  '10000000-0000-0000-0000-000000000001', 'member@example.com') = :'invite_id'::uuid);

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","email":"outsider@example.com"}', false);
select pg_temp.ok('Outsider cannot read groups', (select count(*) = 0 from public.groups));
select pg_temp.ok('Outsider cannot read members', (select count(*) = 0 from public.group_members));
select pg_temp.ok('Outsider cannot read invitations', (select count(*) = 0 from public.group_invites));
select pg_temp.ok('Outsider cannot preview invitations', (select count(*) = 0 from public.list_my_group_invites()));
select pg_temp.fails('Outsider cannot invite', $q$
  select public.send_group_invite('10000000-0000-0000-0000-000000000001', 'new@example.com')
$q$, '42501');
select pg_temp.fails('Wrong account cannot accept',
  format('select public.accept_group_invite(%L)', :'invite_id'));
select pg_temp.fails('Wrong account cannot decline',
  format('select public.decline_group_invite(%L)', :'invite_id'));

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","email":"MEMBER@EXAMPLE.COM"}', false);
select pg_temp.ok('Recipient cannot yet read group', (select count(*) = 0 from public.groups));
select pg_temp.ok('Recipient gets limited own preview', (select count(*) = 1 and bool_and(group_name = 'Trip')
  from public.list_my_group_invites()));
select pg_temp.ok('Accept returns group ID', public.accept_group_invite(:'invite_id')
  = '10000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.ok('Member can now read group', (select count(*) = 1 from public.groups));
select pg_temp.ok('Member can read collaborator profiles', (select count(*) = 2 from public.profiles));
select pg_temp.ok('Accepted invitation no longer pending', (select count(*) = 0 from public.list_my_group_invites()));
select pg_temp.fails('Cannot accept twice',
  format('select public.accept_group_invite(%L)', :'invite_id'));
select pg_temp.fails('Ordinary member cannot invite', $q$
  select public.send_group_invite('10000000-0000-0000-0000-000000000001', 'new@example.com')
$q$, '42501');
with changed as (
  update public.group_members set role = 'owner' where user_id = auth.uid() returning *
) select pg_temp.ok('Member cannot elevate role', count(*) = 0) from changed;

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000004","email":"other@example.com"}', false);
select public.decline_group_invite(:'other_id');
select pg_temp.ok('Decline creates no membership',
  not public.is_group_member('10000000-0000-0000-0000-000000000001'));
select pg_temp.fails('Declined invitation cannot accept',
  format('select public.accept_group_invite(%L)', :'other_id'));
reset role;
update public.group_invites set status = 'pending', expires_at = now() - interval '1 second'
where id = :'other_id';
set role authenticated;
select pg_temp.fails('Expired invitation cannot accept',
  format('select public.accept_group_invite(%L)', :'other_id'));
select pg_temp.ok('Expired invite not previewed', (select count(*) = 0 from public.list_my_group_invites()));

-- Force failure AFTER membership insertion to verify the RPC is atomic.
reset role;
update public.group_invites set expires_at = now() + interval '1 day' where id = :'other_id';
create function pg_temp.reject_accept() returns trigger language plpgsql as $$
begin
  if new.status = 'accepted' then raise exception 'Injected failure'; end if;
  return new;
end;
$$;
create trigger test_reject before update on public.group_invites
for each row execute function pg_temp.reject_accept();
set role authenticated;
select pg_temp.fails('Accept update failure propagates',
  format('select public.accept_group_invite(%L)', :'other_id'));
select pg_temp.ok('Membership insertion rolled back',
  not public.is_group_member('10000000-0000-0000-0000-000000000001'));
select pg_temp.ok('Invitation remains pending',
  (select status = 'pending' from public.group_invites where id = :'other_id'));
reset role;
set role anon;
select pg_temp.fails('Anonymous list denied', 'select public.list_my_group_invites()', '42501');
select pg_temp.fails('Anonymous accept denied',
  format('select public.accept_group_invite(%L)', :'other_id'), '42501');
reset role;
rollback;
