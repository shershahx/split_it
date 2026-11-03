-- Run via run_finances.sql in an EMPTY, DISPOSABLE local database.
-- Every assertion runs as the named app role, except explicit fixture setup
-- and corruption/failure injection. Test data rolls back.
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
create function pg_temp.person(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid;
$$;
create function pg_temp.login(n integer) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.person(n))::text, true);
$$;
-- Shorthand invokes the real RPC as the current role (NOT security definer).
create function pg_temp.expense(
  eid uuid default '20000000-0000-0000-0000-000000000001',
  allocation jsonb default '[{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":500},{"user_id":"00000000-0000-0000-0000-000000000002","amount_minor":501}]',
  amount bigint default 1001,
  description text default ' Dinner ',
  payer uuid default '00000000-0000-0000-0000-000000000001',
  spent timestamptz default '2020-01-01T12:00:00Z'
) returns uuid language sql as $$
  select public.create_expense(eid, '10000000-0000-0000-0000-000000000001',
                              description, amount, payer, spent, allocation);
$$;
create function pg_temp.settlement(
  sid uuid default '30000000-0000-0000-0000-000000000001',
  amount bigint default 200,
  recipient uuid default '00000000-0000-0000-0000-000000000001',
  paid timestamptz default '2020-01-02T12:00:00Z',
  note text default null
) returns uuid language sql as $$
  select public.record_settlement(sid, '10000000-0000-0000-0000-000000000001',
                                 recipient, amount, paid, note);
$$;
create function pg_temp.balances(owner_net bigint, member_net bigint) returns boolean
language sql as $$
  select count(*) = 4
     and coalesce(sum(balance_minor), 1) = 0
     and max(balance_minor) filter (where user_id = pg_temp.person(1)) = owner_net
     and max(balance_minor) filter (where user_id = pg_temp.person(2)) = member_net
     and max(balance_minor) filter (where user_id = pg_temp.person(4)) = 0
     and max(balance_minor) filter (where user_id = pg_temp.person(5)) = 0
  from jsonb_to_recordset(public.get_group_balances(
    '10000000-0000-0000-0000-000000000001') -> 'balances')
    as b(user_id uuid, balance_minor bigint);
$$;

insert into auth.users (id, email)
select pg_temp.person(n), 'person' || n || '@example.com' from generate_series(1, 5) n;
insert into public.groups (id, name, created_by)
values ('10000000-0000-0000-0000-000000000001', 'Finance test', pg_temp.person(1)),
       ('10000000-0000-0000-0000-000000000002', 'Other group', pg_temp.person(3));
insert into public.group_members (group_id, user_id, role) values
  ('10000000-0000-0000-0000-000000000001', pg_temp.person(2), 'member'),
  ('10000000-0000-0000-0000-000000000001', pg_temp.person(4), 'admin'),
  ('10000000-0000-0000-0000-000000000001', pg_temp.person(5), 'member');

select pg_temp.ok('Financial write policies removed', not exists (
  select 1 from pg_catalog.pg_policies where schemaname = 'public'
    and tablename in ('expenses', 'expense_splits', 'settlements') and cmd <> 'SELECT'));
select pg_temp.ok('SELECT policies retained', (select count(*) = 3
  from pg_catalog.pg_policies where schemaname = 'public'
    and tablename in ('expenses', 'expense_splits', 'settlements') and cmd = 'SELECT'));
select pg_temp.ok('RPCs are definer with empty search_path', (select count(*) = 5
  and bool_and(p.prosecdef and 'search_path=""' = any(p.proconfig))
  from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in (
    'create_expense', 'delete_expense', 'record_settlement', 'delete_settlement', 'get_group_balances')));

set local role authenticated;
select pg_temp.login(1);
select pg_temp.ok('Empty ledger includes zero-balance members', pg_temp.balances(0, 0));
update public.groups set currency = 'EUR' where id = '10000000-0000-0000-0000-000000000001';
update public.groups set currency = 'USD' where id = '10000000-0000-0000-0000-000000000001';
select pg_temp.ok('Create expense returns stable client ID', pg_temp.expense()
  = '20000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.ok('Exact odd cents, full ledger', pg_temp.balances(501, -501));
select pg_temp.ok('Creator is auth.uid and description trimmed', (select created_by = auth.uid()
  and description = 'Dinner' and paid_by = auth.uid() and amount_minor = 1001
  from public.expenses));
select pg_temp.ok('Identical retry returns same ID', pg_temp.expense()
  = '20000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.ok('Semantic retry permits split order, whitespace, UTC equivalent', pg_temp.expense(
  allocation => '[{"user_id":"00000000-0000-0000-0000-000000000002","amount_minor":501},{"amount_minor":500,"user_id":"00000000-0000-0000-0000-000000000001"}]',
  description => 'Dinner', spent => '2020-01-01T13:00:00+01')
  = '20000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.ok('Retries do not duplicate money', (select count(*) = 1 from public.expenses)
  and (select count(*) = 2 from public.expense_splits) and pg_temp.balances(501, -501));
select pg_temp.fails('Conflicting description', $$select pg_temp.expense(description => 'Changed')$$);
select pg_temp.fails('Conflicting payer', $$select pg_temp.expense(payer => pg_temp.person(2))$$);
select pg_temp.fails('Conflicting timestamp', $$select pg_temp.expense(spent => now())$$);
select pg_temp.fails('Conflicting split allocations', $q$select pg_temp.expense(
  allocation => '[{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":501},{"user_id":"00000000-0000-0000-0000-000000000002","amount_minor":500}]')$q$);
select pg_temp.fails('Currency locked by expense', $q$
  update public.groups set currency = 'EUR' where id = '10000000-0000-0000-0000-000000000001'$q$);
-- Non-currency group updates and no-op currency assignments remain usable.
update public.groups set name = 'Renamed', currency = 'USD'
where id = '10000000-0000-0000-0000-000000000001';

-- Each invalid allocation uses a new ID. No INSERT or partial split may remain.
do $$
declare bad jsonb;
begin
  for bad in select value from jsonb_array_elements($json$[
    null, {}, [], [null],
    [{"user_id":null,"amount_minor":1001}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":null}],
    [{"user_id":"00000000-0000-0000-0000-000000000001"}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":"1001"}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":true}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":1001.0}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":1000.5}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":-1}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":4503599627370496}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":1000}],
    [{"user_id":"00000000-0000-0000-0000-000000000003","amount_minor":1001}],
    [{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":500},
     {"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":501}]
  ]$json$::jsonb)
  loop
    perform pg_temp.fails('Reject malformed/nonmember/mismatched allocation: ' || bad::text,
      format('select pg_temp.expense(eid => gen_random_uuid(), allocation => %L::jsonb)', bad));
  end loop;
end;
$$;
select pg_temp.fails('SQL NULL splits', $$select pg_temp.expense(eid => gen_random_uuid(), allocation => null)$$);
select pg_temp.fails('Malformed UUID', $q$select pg_temp.expense(eid => gen_random_uuid(),
  allocation => '[{"user_id":"not-uuid","amount_minor":1001}]')$q$, '22P02');
select pg_temp.fails('Nonmember payer', $$select pg_temp.expense(eid => gen_random_uuid(), payer => pg_temp.person(3))$$);
select pg_temp.fails('Null payer', $$select pg_temp.expense(eid => gen_random_uuid(), payer => null)$$);
select pg_temp.fails('Null expense ID', $$select pg_temp.expense(eid => null)$$);
select pg_temp.fails('Blank description', $$select pg_temp.expense(eid => gen_random_uuid(), description => '   ')$$);
select pg_temp.fails('Whitespace-only description', $$select pg_temp.expense(eid => gen_random_uuid(), description => E'\t\n\r ')$$);
select pg_temp.fails('Null description', $$select pg_temp.expense(eid => gen_random_uuid(), description => null)$$);
select pg_temp.fails('Long description', $$select pg_temp.expense(eid => gen_random_uuid(), description => repeat('x',201))$$);
select pg_temp.fails('Zero expense', $$select pg_temp.expense(eid => gen_random_uuid(), amount => 0)$$);
select pg_temp.fails('Negative expense', $$select pg_temp.expense(eid => gen_random_uuid(), amount => -1)$$);
select pg_temp.fails('Null expense total', $$select pg_temp.expense(eid => gen_random_uuid(), amount => null)$$);
select pg_temp.fails('Expense above maximum', $$select pg_temp.expense(eid => gen_random_uuid(), amount => 4503599627370496)$$);
select pg_temp.fails('Null date', $$select pg_temp.expense(eid => gen_random_uuid(), spent => null)$$);
select pg_temp.fails('Infinite date', $$select pg_temp.expense(eid => gen_random_uuid(), spent => 'infinity')$$);
select pg_temp.fails('Negative infinite date', $$select pg_temp.expense(eid => gen_random_uuid(), spent => '-infinity')$$);
select pg_temp.ok('Invalid expense requests leave no rows or splits',
  (select count(*) = 1 from public.expenses) and (select count(*) = 2 from public.expense_splits));

-- Simulate a storage failure AFTER expense insert and one split insert.
reset role;
create function pg_temp.reject_split() returns trigger language plpgsql as $$
begin
  if new.user_id = pg_temp.person(2) then raise exception 'Injected split failure'; end if;
  return new;
end;
$$;
create trigger test_reject_split before insert on public.expense_splits
  for each row execute function pg_temp.reject_split();
set local role authenticated;
select pg_temp.fails('Late split failure propagates', $$select pg_temp.expense(eid => gen_random_uuid())$$);
select pg_temp.ok('Late failure rolls back entire expense and all splits',
  (select count(*) = 1 from public.expenses) and (select count(*) = 2 from public.expense_splits));
reset role;
drop trigger test_reject_split on public.expense_splits;
set local role authenticated;

-- No direct write paths, even for owner/admin/creator. In particular an admin
-- may delete a whole expense but cannot rewrite or separately delete its splits.
select pg_temp.fails('Owner cannot insert raw expense/spoof creator', $q$
  insert into public.expenses (group_id, description, amount_minor, paid_by, created_by)
  values ('10000000-0000-0000-0000-000000000001','Spoof',1,auth.uid(),pg_temp.person(2))$q$, '42501');
select pg_temp.fails('Owner cannot update expense', $$update public.expenses set amount_minor = 1$$, '42501');
select pg_temp.fails('Owner cannot delete expense directly', $$delete from public.expenses$$, '42501');
select pg_temp.fails('Owner cannot insert splits', $q$
  insert into public.expense_splits values ('20000000-0000-0000-0000-000000000001',pg_temp.person(4),0)$q$, '42501');
select pg_temp.fails('Owner cannot update splits', $$update public.expense_splits set amount_minor = 0$$, '42501');
select pg_temp.fails('Owner cannot delete splits', $$delete from public.expense_splits$$, '42501');
select pg_temp.fails('Owner cannot truncate ledger', $$truncate public.expenses cascade$$, '42501');
select pg_temp.login(4);
select pg_temp.fails('Admin cannot update splits', $$update public.expense_splits set amount_minor = 0$$, '42501');
select pg_temp.fails('Admin cannot delete splits', $$delete from public.expense_splits$$, '42501');

select pg_temp.login(2);
select pg_temp.fails('Another member cannot reuse expense UUID', $$select pg_temp.expense()$$);
select pg_temp.fails('Split participant cannot delete creator expense', $q$
  select public.delete_expense('20000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.ok('Partial external payment returns ID', pg_temp.settlement()
  = '30000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.ok('Settlement payer and creator derived from session', (select
  paid_by = auth.uid() and created_by = auth.uid() and paid_to = pg_temp.person(1)
  from public.settlements));
select pg_temp.ok('Partial settlement direction reduces debt', pg_temp.balances(301, -301));
select pg_temp.ok('Settlement retry is idempotent', pg_temp.settlement()
  = '30000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.ok('Settlement retry leaves money unchanged', (select count(*) = 1 from public.settlements)
  and pg_temp.balances(301, -301));
select pg_temp.fails('Settlement conflicting amount', $$select pg_temp.settlement(amount => 201)$$);
select pg_temp.fails('Settlement conflicting note', $$select pg_temp.settlement(note => 'changed')$$);
select pg_temp.fails('Settlement conflicting timestamp', $$select pg_temp.settlement(paid => now())$$);
select pg_temp.fails('Settlement conflicting recipient', $$select pg_temp.settlement(recipient => pg_temp.person(4))$$);
select pg_temp.settlement('30000000-0000-0000-0000-000000000002', 301);
select pg_temp.ok('Full settlement zeros debt', pg_temp.balances(0, 0));
select pg_temp.settlement('30000000-0000-0000-0000-000000000003', 50);
select pg_temp.ok('Overpayment honestly reverses credit', pg_temp.balances(-50, 50));
select pg_temp.fails('Zero settlement', $$select pg_temp.settlement(sid => gen_random_uuid(), amount => 0)$$);
select pg_temp.fails('Negative settlement', $$select pg_temp.settlement(sid => gen_random_uuid(), amount => -1)$$);
select pg_temp.fails('Null settlement total', $$select pg_temp.settlement(sid => gen_random_uuid(), amount => null)$$);
select pg_temp.fails('Settlement above maximum', $$select pg_temp.settlement(sid => gen_random_uuid(), amount => 4503599627370496)$$);
select pg_temp.fails('Self settlement', $$select pg_temp.settlement(sid => gen_random_uuid(), recipient => auth.uid())$$);
select pg_temp.fails('Nonmember recipient', $$select pg_temp.settlement(sid => gen_random_uuid(), recipient => pg_temp.person(3))$$);
select pg_temp.fails('Null recipient', $$select pg_temp.settlement(sid => gen_random_uuid(), recipient => null)$$);
select pg_temp.fails('Null settlement ID', $$select pg_temp.settlement(sid => null)$$);
select pg_temp.fails('Long note', $$select pg_temp.settlement(sid => gen_random_uuid(), note => repeat('x',301))$$);
select pg_temp.fails('Null payment date', $$select pg_temp.settlement(sid => gen_random_uuid(), paid => null)$$);
select pg_temp.fails('Infinite payment date', $$select pg_temp.settlement(sid => gen_random_uuid(), paid => 'infinity')$$);
select pg_temp.fails('Negative infinite payment date', $$select pg_temp.settlement(sid => gen_random_uuid(), paid => '-infinity')$$);
select pg_temp.ok('Invalid settlements leave no rows', (select count(*) = 3 from public.settlements));
select pg_temp.fails('No raw settlement insert/spoofed payer', $q$
  insert into public.settlements (group_id,paid_by,paid_to,amount_minor,created_by)
  values ('10000000-0000-0000-0000-000000000001',pg_temp.person(1),auth.uid(),1,auth.uid())$q$, '42501');
select pg_temp.fails('No raw settlement update', $$update public.settlements set amount_minor = 1$$, '42501');
select pg_temp.fails('No raw settlement delete', $$delete from public.settlements$$, '42501');
select pg_temp.login(1);
select pg_temp.fails('Other creator cannot reuse settlement ID', $$select pg_temp.settlement(recipient => pg_temp.person(2))$$);

-- Outsiders, other-group owners, missing JWTs, and anonymous sessions.
select pg_temp.login(3);
select pg_temp.ok('Other-group owner cannot read ledger', (select count(*) = 0 from public.expenses)
  and (select count(*) = 0 from public.expense_splits) and (select count(*) = 0 from public.settlements));
select pg_temp.fails('Outsider cannot create expense', $$select pg_temp.expense(eid => gen_random_uuid())$$, '42501');
select pg_temp.fails('Outsider cannot record payment', $$select pg_temp.settlement(sid => gen_random_uuid())$$, '42501');
select pg_temp.fails('Outsider cannot obtain balances', $q$
  select * from public.get_group_balances('10000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Outsider cannot delete expense', $q$
  select public.delete_expense('20000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Outsider cannot delete settlement', $q$
  select public.delete_settlement('30000000-0000-0000-0000-000000000001')$q$, '42501');
select set_config('request.jwt.claims', '{}', true);
select pg_temp.fails('Authenticated role without identity cannot create', $$select pg_temp.expense()$$, '42501');
select pg_temp.fails('Authenticated role without identity cannot settle', $$select pg_temp.settlement()$$, '42501');
select pg_temp.fails('Missing identity cannot read balances', $q$
  select * from public.get_group_balances('10000000-0000-0000-0000-000000000001')$q$, '42501');
reset role;
set local role anon;
select pg_temp.fails('Anonymous expense RPC denied', $$select pg_temp.expense()$$, '42501');
select pg_temp.fails('Anonymous settlement RPC denied', $$select pg_temp.settlement()$$, '42501');
select pg_temp.fails('Anonymous delete expense denied', $q$
  select public.delete_expense('20000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Anonymous delete settlement denied', $q$
  select public.delete_settlement('30000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Anonymous balances RPC denied', $q$
  select * from public.get_group_balances('10000000-0000-0000-0000-000000000001')$q$, '42501');

-- Membership removal is a privileged fixture operation, not new app UX.
reset role;
delete from public.group_members where user_id = pg_temp.person(2);
set local role authenticated;
select pg_temp.login(1);
select pg_temp.ok('Historic participant retains balances after leaving', pg_temp.balances(-50, 50));
select pg_temp.ok('Original creator retry still works after split member leaves', pg_temp.expense()
  = '20000000-0000-0000-0000-000000000001'::uuid);
select pg_temp.login(2);
select pg_temp.fails('Former member cannot read balances', $q$
  select * from public.get_group_balances('10000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Former creator cannot delete settlement', $q$
  select public.delete_settlement('30000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Former member cannot create', $$select pg_temp.expense(eid => gen_random_uuid())$$, '42501');
select pg_temp.fails('Former member cannot record', $$select pg_temp.settlement(sid => gen_random_uuid())$$, '42501');
reset role;
insert into public.group_members (group_id,user_id)
values ('10000000-0000-0000-0000-000000000001',pg_temp.person(2));
set local role authenticated;

-- An unrelated member cannot erase other members' financial records.
select pg_temp.login(5);
select pg_temp.fails('Unrelated member cannot delete expense', $q$
  select public.delete_expense('20000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Unrelated member cannot delete settlement', $q$
  select public.delete_settlement('30000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.login(2);
select public.delete_settlement('30000000-0000-0000-0000-000000000003');
select pg_temp.ok('Payer deletion updates net', pg_temp.balances(0, 0));
select pg_temp.login(4);
select public.delete_settlement('30000000-0000-0000-0000-000000000002');
select pg_temp.ok('Admin deletion updates net', pg_temp.balances(301, -301));
select public.delete_expense('20000000-0000-0000-0000-000000000001');
select pg_temp.ok('Admin expense deletion cascades splits', (select count(*) = 0 from public.expense_splits)
  and (select count(*) = 0 from public.expenses) and pg_temp.balances(-200, 200));
select pg_temp.login(1);
select pg_temp.fails('Settlement alone locks currency', $q$
  update public.groups set currency = 'PKR' where id = '10000000-0000-0000-0000-000000000001'$q$);
select pg_temp.fails('Missing expense safely denied', $q$
  select public.delete_expense('20000000-0000-0000-0000-000000000001')$q$, '42501');
select pg_temp.fails('Missing settlement safely denied', $q$
  select public.delete_settlement('30000000-0000-0000-0000-000000000003')$q$, '42501');

-- Boundaries and aggregation across much more than a UI page, including old
-- dates. Payer may differ from creator; zero splits and max cents are valid.
select pg_temp.expense('20000000-0000-0000-0000-000000000002',
  '[{"user_id":"00000000-0000-0000-0000-000000000001","amount_minor":0},{"user_id":"00000000-0000-0000-0000-000000000002","amount_minor":4503599627370495}]',
  4503599627370495, repeat('x',200), pg_temp.person(2));
select pg_temp.ok('Maximum amount, zero allocation and alternate payer exact', pg_temp.balances(-200, 200));
select pg_temp.login(2);
select pg_temp.fails('Expense payer alone cannot delete another creator expense', $q$
  select public.delete_expense('20000000-0000-0000-0000-000000000002')$q$, '42501');
select pg_temp.login(1);
select public.delete_expense('20000000-0000-0000-0000-000000000002');
select pg_temp.ok('Creator may delete expense paid by another member', (select count(*) = 0 from public.expenses));
do $$
declare n integer;
begin
  for n in 1..125 loop
    perform pg_temp.expense(gen_random_uuid());
  end loop;
end;
$$;
select pg_temp.ok('All 125 old expenses aggregated, not page-limited', pg_temp.balances(62425, -62425));
select pg_temp.login(2);
select pg_temp.settlement('30000000-0000-0000-0000-000000000004',4503599627370495,
  pg_temp.person(1),'2001-01-01T00:00:00Z',repeat('x',300));
select pg_temp.ok('Max settlement and max length note exact', pg_temp.balances(
  62425::bigint - 4503599627370495, -62425::bigint + 4503599627370495));
select public.delete_settlement('30000000-0000-0000-0000-000000000004');
select pg_temp.ok('Deleting maximum restores exact totals', pg_temp.balances(62425, -62425));
select pg_temp.login(1);
select pg_temp.expense('20000000-0000-0000-0000-000000000003',
  '[{"user_id":"00000000-0000-0000-0000-000000000002","amount_minor":4503599627370495}]',
  4503599627370495);
select pg_temp.fails('Aggregate above safe money bound fails visibly', $q$
  select public.get_group_balances('10000000-0000-0000-0000-000000000001')$q$);
select public.delete_expense('20000000-0000-0000-0000-000000000003');
select pg_temp.ok('Removing excessive aggregate restores balances', pg_temp.balances(62425, -62425));

-- Unsupported currencies reject BOTH kinds of record before any insert.
reset role;
insert into public.groups(id,name,currency,created_by)
values ('10000000-0000-0000-0000-000000000003','Unsupported','JPY',pg_temp.person(1));
set local role authenticated;
select pg_temp.login(1);
select pg_temp.fails('Unsupported expense currency', $q$
  select public.create_expense(gen_random_uuid(),'10000000-0000-0000-0000-000000000003',
    'Test',1,auth.uid(),now(),jsonb_build_array(jsonb_build_object('user_id',auth.uid(),'amount_minor',1)))$q$);
select pg_temp.fails('Unsupported settlement currency', $q$
  select public.record_settlement(gen_random_uuid(),'10000000-0000-0000-0000-000000000003',
    pg_temp.person(2),1,now())$q$);

-- Existing owner DELETE feature intentionally cascades current financial data.
delete from public.groups where id = '10000000-0000-0000-0000-000000000001';
reset role;
select pg_temp.ok('Owner group deletion cascades financial data',
  (select count(*) = 0 from public.expenses) and (select count(*) = 0 from public.expense_splits)
  and (select count(*) = 0 from public.settlements));
rollback;
