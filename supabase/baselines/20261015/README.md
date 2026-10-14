# Catalog-derived routine export procedure

The files `0002_private_routines.sql` through `0009_public_routines_remaining.sql` contain definitions exported from PostgreSQL's `pg_get_functiondef(oid)`. That function returns the function definition but may omit the final SQL statement semicolon. Concatenating the returned definitions verbatim can make PostgreSQL report a syntax error at the next `CREATE FUNCTION`, even when the preceding function body itself is valid.

After exporting the routine definitions from the read-only catalog, run:

```sh
python scripts/normalize_catalog_routine_dump.py --write supabase/baselines/20261015/0002_private_routines.sql supabase/baselines/20261015/0003_public_routines_a_d.sql supabase/baselines/20261015/0004_public_routines_execute_export.sql supabase/baselines/20261015/0005_public_routines_export_lamin.sql supabase/baselines/20261015/0006_public_routines_validation.sql supabase/baselines/20261015/0007_public_routines_rollover_finance.sql supabase/baselines/20261015/0008_public_routines_restore.sql supabase/baselines/20261015/0009_public_routines_remaining.sql
```

The normalizer only inserts a missing semicolon immediately after the outer dollar-quote delimiter. It does not rewrite the body or modify language, owner, grants, `SECURITY DEFINER`, `search_path`, or other routine attributes. Those attributes are captured separately in `0011_security_policies_triggers_grants.sql`.

CI runs the same tool in check-only mode before applying the baseline. A malformed or unterminated outer dollar quote fails the check rather than silently deleting or replacing a routine.
