-- Apply AFTER schema.sql and 001_groups_workflow.sql. Run the whole file.
-- All money is integer minor units; supported currencies have two decimals.
begin;

-- Remove every old write policy (including ALL), retaining SELECT policies.
-- Revoking grants as well prevents bypass even if an old policy is restored.
do $$
declare p record;
begin
  for p in
    select schemaname, tablename, policyname from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename in ('expenses', 'expense_splits', 'settlements')
      and cmd <> 'SELECT'
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end;
$$;
revoke insert, update, delete, truncate, references, trigger
  on public.expenses, public.expense_splits, public.settlements
  from public, anon, authenticated;

-- UPDATE already locks the group row. Financial RPCs take the same row lock
-- before checking currency or inserting, so a racing currency change cannot
-- relabel committed money. Definer rights see records regardless of SELECT RLS.
create or replace function public.protect_financial_currency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.currency is distinct from old.currency and (
    exists (select 1 from public.expenses e where e.group_id = old.id)
    or exists (select 1 from public.settlements s where s.group_id = old.id)
  ) then
    raise exception 'Currency cannot change while financial records exist';
  end if;
  return new;
end;
$$;
revoke all on function public.protect_financial_currency() from public, anon, authenticated;
drop trigger if exists groups_protect_financial_currency on public.groups;
create trigger groups_protect_financial_currency
  before update of currency on public.groups
  for each row execute function public.protect_financial_currency();

create or replace function public.create_expense(
  expense_id uuid,
  target_group_id uuid,
  expense_description text,
  total_minor bigint,
  payer_id uuid,
  spent_at timestamptz,
  splits jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_description text := regexp_replace(
    expense_description, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  group_currency text;
  item jsonb;
  split_user uuid;
  split_amount bigint;
  canonical_splits jsonb;
  existing_splits jsonb;
  inserted_id uuid;
  existing public.expenses%rowtype;
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select g.currency into group_currency from public.groups g
    where g.id = target_group_id for update;
  if not found or not public.is_group_member(target_group_id) then
    raise exception 'Group unavailable' using errcode = '42501';
  end if;
  if group_currency not in ('USD', 'PKR', 'EUR', 'GBP', 'INR', 'AED', 'SAR', 'CAD', 'AUD') then
    raise exception 'Unsupported currency';
  end if;
  if expense_id is null or payer_id is null
     or normalized_description is null or length(normalized_description) not between 1 and 200
     or total_minor is null or total_minor not between 1 and 4503599627370495
     or spent_at is null or not isfinite(spent_at) then
    raise exception 'Invalid expense';
  end if;
  -- timestamptz is an instant (normalized by PostgreSQL), not a local date.
  if splits is null or jsonb_typeof(splits) <> 'array' then
    raise exception 'Splits must be a nonempty array';
  end if;
  if jsonb_array_length(splits) = 0 then
    raise exception 'Splits must be a nonempty array';
  end if;
  for item in select value from jsonb_array_elements(splits)
  loop
    if jsonb_typeof(item) <> 'object'
       or jsonb_typeof(item -> 'user_id') is distinct from 'string'
       or jsonb_typeof(item -> 'amount_minor') is distinct from 'number'
       or (item ->> 'amount_minor') !~ '^[0-9]+$' then
      raise exception 'Invalid split: UUID and nonnegative integer required';
    end if;
    -- Cast only after type/format checks; invalid UUIDs and overflow reject.
    split_user := (item ->> 'user_id')::uuid;
    if (item ->> 'amount_minor')::numeric > 4503599627370495 then
      raise exception 'Split amount exceeds supported range';
    end if;
    split_amount := (item ->> 'amount_minor')::bigint;
  end loop;
  if (select count(*) <> count(distinct (x ->> 'user_id')::uuid)
      from jsonb_array_elements(splits) x) then
    raise exception 'Duplicate split user';
  end if;
  if (select sum((x ->> 'amount_minor')::numeric)
      from jsonb_array_elements(splits) x) <> total_minor then
    raise exception 'Split sum must equal expense total';
  end if;
  select jsonb_agg(jsonb_build_object(
    'user_id', (x ->> 'user_id')::uuid,
    'amount_minor', (x ->> 'amount_minor')::bigint)
    order by (x ->> 'user_id')::uuid)
  into canonical_splits from jsonb_array_elements(splits) x;

  -- No UPDATE/upsert: a collision is only accepted for the creator's identical
  -- semantic payload. A retry may reorder splits or add description whitespace.
  -- Check a previous record before participant validation, allowing a retry
  -- after another participant leaves, but never after the caller loses access.
  select e.* into existing from public.expenses e where e.id = expense_id;
  if not found then
    if not exists (select 1 from public.group_members m
                   where m.group_id = target_group_id and m.user_id = payer_id)
       or exists (
         select 1 from jsonb_array_elements(canonical_splits) x
         where not exists (
           select 1 from public.group_members m where m.group_id = target_group_id
             and m.user_id = (x ->> 'user_id')::uuid)
       ) then
      raise exception 'Payer and split users must be group members';
    end if;
    insert into public.expenses
      (id, group_id, description, amount_minor, paid_by, expense_date, created_by)
    values
      (expense_id, target_group_id, normalized_description, total_minor, payer_id, spent_at, actor)
    on conflict (id) do nothing returning id into inserted_id;
    if inserted_id is not null then
      insert into public.expense_splits (expense_id, user_id, amount_minor)
        select inserted_id, (x ->> 'user_id')::uuid, (x ->> 'amount_minor')::bigint
        from jsonb_array_elements(canonical_splits) x;
      return inserted_id;
    end if;
    -- A concurrent request in another group may have claimed this UUID.
    select e.* into existing from public.expenses e where e.id = expense_id;
  end if;
  select jsonb_agg(jsonb_build_object('user_id', s.user_id, 'amount_minor', s.amount_minor)
                  order by s.user_id)
    into existing_splits from public.expense_splits s
    where s.expense_id = create_expense.expense_id;
  if existing.created_by = actor and existing.group_id = target_group_id
     and existing.description = normalized_description and existing.amount_minor = total_minor
     and existing.paid_by = payer_id and existing.expense_date = spent_at
     and existing_splits = canonical_splits then
    return expense_id;
  end if;
  raise exception 'Expense UUID already used with a different payload or creator';
end;
$$;

create or replace function public.delete_expense(target_expense_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare ledger_group uuid;
begin
  select e.group_id into ledger_group from public.expenses e where e.id = target_expense_id;
  perform 1 from public.groups g where g.id = ledger_group for update;
  -- Missing and inaccessible records deliberately share a safe denial.
  if auth.uid() is null or not public.is_group_member(ledger_group) then
    raise exception 'Expense unavailable' using errcode = '42501';
  end if;
  delete from public.expenses e where e.id = target_expense_id
    and (e.created_by = auth.uid() or public.is_group_admin(e.group_id));
  if not found then
    raise exception 'Expense unavailable' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.record_settlement(
  settlement_id uuid,
  target_group_id uuid,
  recipient_id uuid,
  total_minor bigint,
  paid_at timestamptz,
  settlement_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  group_currency text;
  inserted_id uuid;
  existing public.settlements%rowtype;
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select g.currency into group_currency from public.groups g
    where g.id = target_group_id for update;
  if not found or not public.is_group_member(target_group_id) then
    raise exception 'Group unavailable' using errcode = '42501';
  end if;
  if group_currency not in ('USD', 'PKR', 'EUR', 'GBP', 'INR', 'AED', 'SAR', 'CAD', 'AUD') then
    raise exception 'Unsupported currency';
  end if;
  if settlement_id is null or recipient_id is null or recipient_id = actor
     or total_minor is null or total_minor not between 1 and 4503599627370495
     or paid_at is null or not isfinite(paid_at)
     or length(settlement_note) > 300 then
    raise exception 'Invalid settlement';
  end if;
  select s.* into existing from public.settlements s where s.id = settlement_id;
  if not found then
    if not exists (select 1 from public.group_members m
                   where m.group_id = target_group_id and m.user_id = recipient_id) then
      raise exception 'Recipient must be a group member';
    end if;
    -- An external payment record, NOT a transfer or debt-enforced payment.
    -- Honest overpayments are allowed; balances reflect the resulting credit.
    insert into public.settlements
      (id, group_id, paid_by, paid_to, amount_minor, settled_at, note, created_by)
    values
      (settlement_id, target_group_id, actor, recipient_id, total_minor, paid_at, settlement_note, actor)
    on conflict (id) do nothing returning id into inserted_id;
    if inserted_id is not null then return inserted_id; end if;
    select s.* into existing from public.settlements s where s.id = settlement_id;
  end if;
  if existing.created_by = actor and existing.paid_by = actor
     and existing.group_id = target_group_id and existing.paid_to = recipient_id
     and existing.amount_minor = total_minor and existing.settled_at = paid_at
     and existing.note is not distinct from settlement_note then
    return settlement_id;
  end if;
  raise exception 'Settlement UUID already used with a different payload or creator';
end;
$$;

create or replace function public.delete_settlement(target_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare ledger_group uuid;
begin
  select s.group_id into ledger_group from public.settlements s where s.id = target_settlement_id;
  perform 1 from public.groups g where g.id = ledger_group for update;
  if auth.uid() is null or not public.is_group_member(ledger_group) then
    raise exception 'Settlement unavailable' using errcode = '42501';
  end if;
  delete from public.settlements s where s.id = target_settlement_id
    and (s.paid_by = auth.uid() or s.created_by = auth.uid() or public.is_group_admin(s.group_id));
  if not found then
    raise exception 'Settlement unavailable' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.get_group_balances(target_group_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare balances jsonb;
begin
  if auth.uid() is null or not public.is_group_member(target_group_id) then
    raise exception 'Group unavailable' using errcode = '42501';
  end if;
  -- One JSON result avoids PostgREST's SETOF max_rows truncation. No paging or
  -- date filter. Numeric intermediate sums cannot overflow before the explicit
  -- app-safe integer bound check below.
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', totals.participant, 'balance_minor', totals.net)
    order by totals.participant), '[]'::jsonb)
  into balances
  from (
    select ledger.participant, sum(ledger.delta) as net
    from (
      select m.user_id as participant, 0::numeric as delta
        from public.group_members m where m.group_id = target_group_id
      union all
      select e.paid_by, e.amount_minor::numeric
        from public.expenses e where e.group_id = target_group_id
      union all
      select s.user_id, -s.amount_minor::numeric
        from public.expense_splits s join public.expenses e on e.id = s.expense_id
        where e.group_id = target_group_id
      union all
      select s.paid_by, s.amount_minor::numeric
        from public.settlements s where s.group_id = target_group_id
      union all
      select s.paid_to, -s.amount_minor::numeric
        from public.settlements s where s.group_id = target_group_id
    ) ledger
    group by ledger.participant
  ) totals;
  if exists (select 1 from jsonb_array_elements(balances) b
             where abs((b ->> 'balance_minor')::numeric) > 4503599627370495) then
    raise exception 'Group balance exceeds supported integer range';
  end if;
  return jsonb_build_object('balances', balances);
end;
$$;

revoke all on function public.create_expense(uuid, uuid, text, bigint, uuid, timestamptz, jsonb) from public, anon;
revoke all on function public.delete_expense(uuid) from public, anon;
revoke all on function public.record_settlement(uuid, uuid, uuid, bigint, timestamptz, text) from public, anon;
revoke all on function public.delete_settlement(uuid) from public, anon;
revoke all on function public.get_group_balances(uuid) from public, anon;
grant execute on function public.create_expense(uuid, uuid, text, bigint, uuid, timestamptz, jsonb) to authenticated;
grant execute on function public.delete_expense(uuid) to authenticated;
grant execute on function public.record_settlement(uuid, uuid, uuid, bigint, timestamptz, text) to authenticated;
grant execute on function public.delete_settlement(uuid) to authenticated;
grant execute on function public.get_group_balances(uuid) to authenticated;

commit;
