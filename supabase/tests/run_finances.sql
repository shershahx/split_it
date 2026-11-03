-- LOCAL DISPOSABLE DATABASE ONLY. Requires a local superuser and empty DB.
-- psql -X -v ON_ERROR_STOP=1 -d YOUR_EMPTY_TEST_DB -f supabase/tests/run_finances.sql
\set ON_ERROR_STOP on
\ir fixture.sql
\ir ../schema.sql
\ir ../migrations/001_groups_workflow.sql
\ir ../migrations/002_financial_workflow.sql
\ir ../migrations/002_financial_workflow.sql
\ir finances_workflow_test.sql
\ir groups_workflow_test.sql
\ir finances_concurrency_test.sql
