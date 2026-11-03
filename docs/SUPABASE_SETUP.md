# Supabase setup for Split It

## 1. Create the project

1. Open <https://supabase.com/dashboard> and select **New project**.
2. Use project name `Split_It`.
3. Generate and save a strong database password in a password manager.
4. Select the region closest to the majority of users.
5. Wait for provisioning to finish.

## 2. Configure authentication

In **Authentication > Providers > Email**:

- Enable Email provider.
- Enable **Confirm email**.
- Set minimum password length to **12**.
- Enable leaked-password protection when the selected Supabase plan exposes it.
- Keep secure email-change confirmation enabled.

In **Authentication > URL Configuration**:

- Add `com.splitit://auth-callback/` to **Redirect URLs**.
- Set **Site URL** to the production website once one exists. Do not use the
  custom app URL as the public website URL.

During development, use Supabase's default email sender only for testing.
Configure a production SMTP provider before release, because the default
sender is rate-limited.

## 3. Create the database

1. Open **SQL Editor**.
2. Select **New query**.
3. Copy all of [`supabase/schema.sql`](../supabase/schema.sql).
4. Select **Run**.
5. Confirm that all eight tables appear under **Table Editor** and that RLS is
   enabled on each one.
6. Run [`supabase/migrations/001_groups_workflow.sql`](../supabase/migrations/001_groups_workflow.sql)
   as a separate whole query, unless already applied.
7. Run [`supabase/migrations/002_financial_workflow.sql`](../supabase/migrations/002_financial_workflow.sql)
   as another whole query. This enables atomic expenses, external-payment records,
   deletion authorization, full-history group balances, and currency protection.

Always apply migrations after the bootstrap, in filename order. Do not rerun
`schema.sql` alone on an existing project: it restores older, permissive membership
and invitation policies. Do not run anything in `supabase/tests/` in your project;
those files create fake local auth fixtures for disposable PostgreSQL tests.

If the migration reports duplicate email addresses, review existing invitation
rows that share a group and differ only by email case. The migration deliberately
stops without deleting or merging those records. Ask for help before changing
existing data.

The schema stores monetary values as integer minor units (`amount_minor`), for
example `$12.34` as `1234`. This avoids floating-point rounding errors.

## 4. Obtain client configuration

Open **Project Settings > API** and copy:

- Project URL
- Publishable key, or the legacy `anon` key

The publishable/anon key is designed for client applications and is protected
by Row Level Security. Never put the `service_role` key, database password, or
SMTP credentials in the app.

Run the app without committing configuration:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

For an Android release:

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 5. Verify authentication

1. Create an account in the app with a new email address.
2. Confirm that the app asks the user to verify their email.
3. Open the verification link and then sign in.
4. Confirm that `Authentication > Users` contains the account.
5. Confirm that `Table Editor > profiles` contains the matching profile.
6. Use **Forgot Password**, open the email link on the Android device, and
   confirm that the app displays the new-password form.

## 6. Verify groups with two accounts

1. Run the groups workflow migration above in the live project's SQL Editor.
2. Sign in as account A and create a group. Select its currency before saving.
3. Restart the app and verify the group and your owner role still appear.
4. Open the group and invite the email address account B signs in with.
5. Sign in as B. Open **Groups > Group invitations** using the envelope icon.
6. Join the invitation; verify B sees the group and both member names.
7. Refresh A's group details; verify B appears as a member.
8. Check that B cannot invite someone else as an ordinary member.
9. Try a second invitation and decline it. Check it disappears from the inbox.
10. Sign in as an unrelated account C and verify it cannot see the group.

Invitations are stored in the app; **no invitation email is sent**. The recipient
must sign in using the invited email address. Invitations expire after seven days;
an admin can resend to renew one. Pull down to refresh data; realtime/offline
synchronization is not implemented.

Group editing/deletion, removing/leaving members, owner transfer, and invitation
revocation are not exposed by this UI yet. Local PostgreSQL tests do not replace
this hosted device check.

## 7. Verify expenses and payments

1. Ensure both migrations above have run successfully.
2. With A and B in the same group, add an expense for `10.01`, paid by A.
3. Verify the two equal shares add to `10.01` (one is `5.01`, the other `5.00`);
   the extra cent is assigned deterministically by member ID.
4. Restart and open the expense. Check its currency, payer, and complete split.
5. Sign in as B and use **Record payment** to record a real external payment to A
   for B's share. This action does not send money.
6. Refresh A's group. Check both balances become zero. A partial payment should
   reduce the debt; an overpayment should reverse the credit.
7. Confirm B cannot delete A's expense. The creator or a group admin can delete
   it from expense details, with a confirmation; balances then reflect the removal.
8. Verify unrelated C still cannot read the expense, splits, payments, or balances.

Expense and payment lists are paginated; group totals include older pages too.
An unchanged retry reuses its request ID to avoid duplicate records. Changing the
form creates a new request, so inspect existing records before editing and retrying
after an uncertain network result. Currency cannot change while financial records
exist. Custom splits, expense editing, and payment-deletion UI are not implemented.

## Local database tests (developers only)

On an **empty disposable local PostgreSQL database**, as a local test superuser:

```bash
psql -X -v ON_ERROR_STOP=1 -d YOUR_EMPTY_TEST_DB -f supabase/tests/run_groups.sql
# Or the full financial + group regression suite, on another empty local DB:
psql -X -v ON_ERROR_STOP=1 -d YOUR_EMPTY_TEST_DB -f supabase/tests/run_finances.sql
```

This simulates Supabase's auth schema and database roles, applies the bootstrap,
applies the migration twice, and checks RLS, roles, invitation identity/expiry, and
transaction rollback. The financial runner also checks cents, ledger history,
idempotency, and concurrent requests using the bundled `dblink` extension with
loopback local authentication. These tests do not verify real JWT signatures,
PostgREST, email delivery, realtime subscriptions, or your deployed Supabase
configuration.

## Security notes

- RLS, not the client UI, is the authorization boundary.
- Every shared-data query must remain scoped by group membership.
- Delete or rotate a key immediately if a `service_role` key is ever exposed.
- Enable MFA in Supabase for administrator accounts.
- Review Auth audit logs and database advisors before production release.
- Use Play Integrity or another attestation layer later as abuse mitigation;
  device attestation does not replace RLS.
