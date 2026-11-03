-- LOCAL DISPOSABLE DATABASE ONLY. Creates roles/auth fixtures; never run in a
-- real Supabase project or an existing database. Requires a local superuser.
-- psql -X -v ON_ERROR_STOP=1 -d YOUR_EMPTY_TEST_DB -f supabase/tests/run_groups.sql
\set ON_ERROR_STOP on
\ir fixture.sql
\ir ../schema.sql
\ir ../migrations/001_groups_workflow.sql
\ir ../migrations/001_groups_workflow.sql
\ir groups_workflow_test.sql
