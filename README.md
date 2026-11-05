# Split It

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
