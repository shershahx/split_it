# Split It

<<<<<<< HEAD
A Flutter expense-splitting app backed by Supabase Auth and Postgres, using
Riverpod for state and GoRouter for navigation.

## Implemented functionality

- Email/password registration and sign-in, email-confirmation handling, sign-out,
  and password-reset email links with an in-app password recovery flow.
- Supabase-backed groups and member management, expenses with equal or custom
  amount splits, and recorded settlements. Recording a settlement does **not**
  transfer money.
- Pairwise group and friend balances, incoming friend requests with acceptance
  or decline, and an expense-history activity feed. Group and friend screens
  use the same obligation semantics; payments do not reassign other debts.
  A tested greedy debt-simplification utility is available for future optional
  suggestions, but does not change the recorded obligations.
- Profile display-name editing (1–80 Unicode characters after trimming), with
  loading feedback and visible errors. A single Auth update atomically
  synchronizes the public profile through a database trigger.
- Light/dark theme selection saved locally; system theme is the default.
- Bundled, selectable, scrollable [Privacy Policy](PRIVACY_POLICY.md) and
  [Terms of Service](TERMS_OF_SERVICE.md) accessible from Settings.

### Current limitations

- Data is fetched on demand and refreshed explicitly; this is **not a realtime
  feed** and there are no realtime database subscriptions.
- Amounts are stored as integer cents. Only currencies with **two decimal
  places** are supported; there is no currency conversion. Balances in different
  currencies must not be combined into a single total. Each record is limited
  to 999,999,999,999 cents; aggregate reports support up to
  ±35,184,372,088,831 cents and fail explicitly beyond that precision limit.
- Receipt scanning/OCR, push notifications, and offline synchronization are
  **pending**, not implemented features. Settings displays push notifications as
  unavailable. Hive initialization does not imply offline data synchronization.


## Developer setup

1. Install Flutter (Dart 3) and the platform tooling for your target device.
2. Create a Supabase project using PostgreSQL 15 or later. Back up any existing
   database and run the **entire** `supabase/schema.sql` in the
   project's SQL editor, not just the table definitions. It includes profile
   provisioning, row-level security, grants, and transactional RPCs required by
   the app. **Deploy the current schema before using this client**, including on
   existing installations: the Auth metadata-update trigger is required to
   atomically synchronize `public.profiles.display_name` and `avatar_url`.
   Direct client profile updates are revoked; the old signup-only trigger is
   insufficient. The database validates display names as 1–80 Unicode characters
   after trimming. RLS-respecting read views aggregate complete memberships and
   splits, while repositories page all ledger records, including when the API
   uses a low row cap. Existing records above the per-record amount limit and
   reversed duplicate friendships must be reconciled before applying the schema;
   migration validation deliberately fails instead of deleting or clamping data.
   Follow any deployment/migration notes in the schema.
3. Enable the Supabase email/password provider and email confirmation. Configure
   email delivery for your deployment. With confirmation enabled, users must
   follow the verification email before signing in.
4. Add **`com.splitit://auth-callback/`** to Supabase Authentication's allowed
   redirect URLs. Confirmation and password recovery use this exact callback.
   Android's manifest registers the scheme; other platform deployments need
   equivalent deep-link handling (and appropriate redirect configuration).
5. Install dependencies and run with the project's URL and public client key:

   ```bash
   flutter pub get
   flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY
   ```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are compile-time Dart defines and are
required for builds as well as `flutter run`. Despite the define's historical
name, it can contain the Supabase public publishable key. **Never use a
`service_role` or secret/service key in the app**, Dart defines, or committed
configuration. Client keys are extractable from builds; row-level security and
restricted database grants enforce access control.

No Firebase configuration is required for the current Supabase-backed features.

## Validation

```bash
flutter analyze
flutter test
```

The PostgreSQL integration test is **opt-in**. It requires `initdb`, `pg_ctl`, and
`psql` on `PATH` and permission to create a temporary local database cluster. It
creates its own cluster rather than connecting to your Supabase project. Enable
it only when that tooling is installed:

```bash
SPLIT_IT_TEST_POSTGRES=true flutter test test/repositories_test.dart
```

In PowerShell, set the environment variable first:

```powershell
$env:SPLIT_IT_TEST_POSTGRES = 'true'
flutter test test/repositories_test.dart
```

Without `SPLIT_IT_TEST_POSTGRES=true`, the database integration test is skipped;
ordinary unit and widget tests still run.

## Architecture

```text
lib/
├── core/        # Router, theme, providers, database services and money utilities
├── features/    # Auth, groups, expenses, friends, settle, activity, account
└── shared/      # Shared models and widgets
```

Features organize repositories/services, Riverpod providers, and presentation
screens separately. Supabase Postgres stores shared data under row-level security;
Supabase Auth manages identities and sessions.
=======
A Flutter expense-sharing app in development, using Riverpod, GoRouter, and Supabase Auth.

## Current status

**Authentication, groups, expenses, and recorded payments are connected to Supabase.**
Apply both workflow migrations before using these features. Groups support in-app
invitations; expenses and their splits save atomically; group balances include all
saved financial records, not just the displayed page. Hosted multi-user and Android
device validation are still required. Do not use this development version as your
only record of debts or payments.

### Implemented

- Email/password registration and sign-in through Supabase Auth.
- Email-confirmation and password-recovery callback flows using PKCE.
- Display-name updates and sign-out.
- Session refresh through the Supabase SDK.
- Platform-protected session and PKCE-verifier storage on Android.
- Light/dark/system theme selection with locally saved preferences.
- Android deep-link configuration and removal of unused sensitive permissions.
- Group creation with database-owned owner membership, UUIDs, and currency selection.
- Paginated group lists, member names/roles, and refresh/error states.
- Admin email-address invitations and a paginated recipient inbox with join/decline.
  These are **in-app invitations**; the app does not send invitation emails.
- Integer-cent calculation boundary, deterministic equal splits, and corrected
  settlement-aware debt simplification for the supported two-decimal currencies.
- Atomic expense creation with equal splits, named payers, complete split details,
  and creator/admin deletion.
- Recording external payments to named group members, including partial payments
  and overpayments. The app does not transfer money.
- Paginated expense/payment lists and server-computed all-history group balances.
- Database-enforced membership, split totals, retry idempotency, and currency
  protection while financial records exist.

These auth flows require a correctly configured Supabase project. Device-level
registration and email-link testing remains necessary before release.

### Still to implement or validate

- Supabase friendships and cross-group home/activity summaries.
- Group editing, invite revocation, leaving/removing members, and owner transfer.
- Custom splits, expense editing, payment-deletion UI, calculated friend balances,
  and paginated activity.
- Realtime subscriptions and bounded local caching.
- Account deletion/export workflows and in-app legal-document links.
- Receipt uploads/OCR and notifications, if added later.
- Release signing, modern Android device testing, and store requirements.

The database and financial RPCs use integer minor currency units. Legacy Flutter
model APIs retain doubles, with exact-cent validation at the persistence boundary.
Group, invitation, expense, and payment lists load 20 items per page; only active
pages are cached. Details load one group's membership or one expense's splits in
100-row requests and render rows lazily. Detail memory still grows with the number
of participants. This is not an offline sync engine.

## Setup

```bash
git clone https://github.com/shershahx/split_it.git
cd split_it
flutter pub get
```

Create a Supabase project, enable email confirmation, and add this allowed redirect:

```text
com.splitit://auth-callback/
```

For a new database, run `supabase/schema.sql` followed by the files in
`supabase/migrations/` in order. For an existing database that already ran the
bootstrap, run any unapplied migrations in this order:

1. [`001_groups_workflow.sql`](supabase/migrations/001_groups_workflow.sql) —
   protected membership and invitation workflows.
2. [`002_financial_workflow.sql`](supabase/migrations/002_financial_workflow.sql) —
   atomic expense/payment operations and full-history balances.

**Do not rerun the bootstrap alone afterward; it restores the old policies.**
Supabase manages `auth.users`; do not create a custom passwords table. Financial
constraints and the hosted multi-user workflow still need production validation.

Run with your project URL and **publishable** key:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

These same definitions are required for APK/app-bundle builds. A publishable key
is intended for client apps; **never embed a secret/service-role key, database
password, or SMTP credential**. RLS is the database authorization boundary.
Configure production SMTP and server-side password restrictions in Supabase;
client-side password validation is not a security boundary.

Detailed dashboard instructions: [Supabase setup](docs/SUPABASE_SETUP.md).

## Architecture

```text
lib/
  core/       Router, themes, services, balance utilities
  features/   Auth, groups, friends, expenses, settle, activity, account
  shared/     Domain models
supabase/     Bootstrap, ordered migrations, disposable database tests
test/         Flutter tests
```

Feature folders separate data access, Riverpod providers, and presentation.
Hive is initialized, but an offline expense cache/sync engine is not implemented.
Theme preferences use SharedPreferences; authentication secrets use secure storage.

## Checks and Android builds

```bash
flutter analyze
flutter test
flutter build apk --debug --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Tests cover money rounding/balances, repository HTTP contracts, group/payment UI,
account-switch invalidation, and app launch. The disposable PostgreSQL suite at
`supabase/tests/run_finances.sql` includes group regressions, financial authorization,
rollback, retries, and independent-session concurrency tests. It requires local
`dblink` and is **not** for the live Supabase SQL Editor. Auth links and hosted
workflows still need device testing. Full analysis still reports informational
notices in unrelated screens.
An Android build has previously been blocked by a corrupted Gradle distribution;
successful APK and release validation are still required.

Release signing is not configured. A release build command alone does not
produce a store-ready signed application.

## Privacy and terms

No advertising or third-party analytics/crash-reporting SDK is currently configured.
Supabase receives account, group, expense, split, and payment information and may
process operational request logs.
The app does not process payments or collect card details.

- [Privacy Policy](PRIVACY_POLICY.md)
- [Terms of Service](TERMS_OF_SERVICE.md)

Standalone HTML drafts are kept locally and intentionally excluded from GitHub.
They are not updated with this financial milestone. Review and align all published
policies and applicable store/legal requirements before release.

Support: splitit.support@gmail.com

Privacy requests: splitit.privacy@gmail.com
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
