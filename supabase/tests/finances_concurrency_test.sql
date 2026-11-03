-- Local disposable database only. dblink makes independent connections to THIS
-- server/database using the local superuser. No hosted connections or secrets.
-- These fixtures must commit so both sessions can see them.
create extension if not exists dblink;
create function pg_temp.ok(label text, passed boolean) returns void
language plpgsql as $$
begin
  if passed is distinct from true then raise exception 'FAIL: %', label; end if;
  raise notice 'PASS: %', label;
end;
$$;
create function pg_temp.wait_blocked(pid integer) returns boolean
language plpgsql as $$
begin
  for attempt in 1..100 loop
    if cardinality(pg_catalog.pg_blocking_pids(pid)) > 0 then return true; end if;
    perform pg_sleep(0.05);
  end loop;
  return false;
end;
$$;
insert into auth.users(id,email) values
  ('90000000-0000-0000-0000-000000000001','concurrent-owner@example.com'),
  ('90000000-0000-0000-0000-000000000002','concurrent-member@example.com');
insert into public.groups(id,name,created_by) values
  ('91000000-0000-0000-0000-000000000001','Concurrency test','90000000-0000-0000-0000-000000000001');
insert into public.group_members(group_id,user_id) values
  ('91000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000002');
select dblink_connect('finance_a', format(
  'host=127.0.0.1 port=%s dbname=%L user=%L',
  current_setting('port'), current_database(), current_user));
select dblink_connect('finance_b', format(
  'host=127.0.0.1 port=%s dbname=%L user=%L',
  current_setting('port'), current_database(), current_user));
select dblink_exec('finance_a', 'set statement_timeout = ''15s''');
select dblink_exec('finance_b', 'set statement_timeout = ''15s''');
select pid as finance_a_pid from dblink('finance_a','select pg_backend_pid()') as t(pid integer) \gset
select pid as finance_b_pid from dblink('finance_b','select pg_backend_pid()') as t(pid integer) \gset
\set create_command 'select public.create_expense(''92000000-0000-0000-0000-000000000001'', ''91000000-0000-0000-0000-000000000001'', ''Concurrent'', 101, ''90000000-0000-0000-0000-000000000001'', ''2020-01-01T00:00:00Z'', ''[{"user_id":"90000000-0000-0000-0000-000000000002","amount_minor":101}]'')'

select dblink_exec('finance_a','begin');
select dblink_exec('finance_a','set local role authenticated');
select * from dblink('finance_a', $q$select set_config('request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001"}',true)$q$) as t(claims text);
select * from dblink('finance_a', :'create_command') as t(id uuid);
select dblink_exec('finance_b','begin');
select dblink_exec('finance_b','set local role authenticated');
select * from dblink('finance_b', $q$select set_config('request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001"}',true)$q$) as t(claims text);
select dblink_send_query('finance_b', :'create_command');
select pg_temp.ok('Concurrent identical retry waits on same group lock',
  pg_temp.wait_blocked(:finance_b_pid));
select dblink_exec('finance_a','commit');
select pg_temp.ok('Concurrent retry returns original UUID', id = '92000000-0000-0000-0000-000000000001'::uuid)
  from dblink_get_result('finance_b') as t(id uuid);
-- Drain the async protocol before issuing a new command.
select * from dblink_get_result('finance_b') as t(id uuid);
select dblink_exec('finance_b','commit');
select pg_temp.ok('Concurrent retry does not duplicate money',
  (select count(*) = 1 from public.expenses where group_id = '91000000-0000-0000-0000-000000000001')
  and (select count(*) = 1 from public.expense_splits
       where expense_id = '92000000-0000-0000-0000-000000000001'));

-- Start with an empty group, commit its currency update while a create waits.
-- The create sees the new currency only after the UPDATE commits.
delete from public.expenses where id = '92000000-0000-0000-0000-000000000001';
select dblink_exec('finance_a','begin');
select dblink_exec('finance_a','set local role authenticated');
select * from dblink('finance_a', $q$select set_config('request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001"}',true)$q$) as t(claims text);
select dblink_exec('finance_a', $q$update public.groups set currency = 'EUR'
  where id = '91000000-0000-0000-0000-000000000001'$q$);
select dblink_exec('finance_b','begin');
select dblink_exec('finance_b','set local role authenticated');
select * from dblink('finance_b', $q$select set_config('request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001"}',true)$q$) as t(claims text);
select dblink_send_query('finance_b', :'create_command');
select pg_temp.ok('Expense create waits for a racing currency update',
  pg_temp.wait_blocked(:finance_b_pid));
select dblink_exec('finance_a','commit');
select * from dblink_get_result('finance_b') as t(id uuid);
select * from dblink_get_result('finance_b') as t(id uuid);
-- finance_b still holds the expense/group lock and its insert is uncommitted.
select dblink_exec('finance_a','begin');
select dblink_exec('finance_a','set local role authenticated');
select * from dblink('finance_a', $q$select set_config('request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001"}',true)$q$) as t(claims text);
select dblink_send_query('finance_a', $q$update public.groups set currency = 'GBP'
  where id = '91000000-0000-0000-0000-000000000001'$q$);
select pg_temp.ok('Currency update waits for uncommitted expense',
  pg_temp.wait_blocked(:finance_a_pid));
select dblink_exec('finance_b','commit');
select * from dblink_get_result('finance_a', false) as t(status text);
select pg_temp.ok('Racing currency update sees newly committed expense and rejects',
  dblink_error_message('finance_a') like '%Currency cannot change%');
select * from dblink_get_result('finance_a', false) as t(status text);
select dblink_exec('finance_a','rollback');
select pg_temp.ok('Committed money remains in the original currency',
  (select currency = 'EUR' from public.groups where id = '91000000-0000-0000-0000-000000000001')
  and (select count(*) = 1 from public.expenses where group_id = '91000000-0000-0000-0000-000000000001'));
select dblink_disconnect('finance_a');
select dblink_disconnect('finance_b');
delete from public.groups where id = '91000000-0000-0000-0000-000000000001';
delete from auth.users where id in (
  '90000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000002');
