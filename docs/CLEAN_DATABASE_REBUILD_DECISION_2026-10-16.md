# Lamīn clean database rebuild — 2026-10-16

## Decision
Begin a clean, isolated reconstruction of the Lamīn database delivery chain because the original historical migration source for the baseline migrations cannot currently be verified.

## Safety boundaries
- This branch is isolated: `restart/lamin-db-rebuild-20261016`.
- Never modify `main`, production Supabase project `School-Management` (`stbrhcgzfxvpayfnnqfl`), or merge PR #7 as part of this work.
- Use only the disposable/test project `Lamin-Test` (`iijngozcfzskhvxrmlwi`) for validation.
- Never run production `db push`, migration repair, destructive DDL, or data-changing tests.
- Do not represent catalog-derived SQL as recovered historical migration source.

## Rebuild strategy
1. Treat the current Lamin-Test catalog as a schema snapshot, not as historical migration truth.
2. Produce a deterministic baseline from catalog definitions: extensions, schemas, types, tables, constraints, indexes, sequences, functions, triggers, grants, RLS and policies.
3. Apply the baseline to a fresh disposable PostgreSQL/Supabase test target, then run schema/security invariants and app tests.
4. Add forward migrations only for explicit changes after the baseline; preserve the existing application code unless tests prove a required fix.
5. Require a clean replay from an empty disposable database and a passing CI run before considering the database chain acceptable.
6. Keep production and `main` untouched. Do not release an APK until the required gates pass.

## Known blocker
The original source for migration `20260924214051_001_core_tables.sql` is not present at the expected path, and the migration-history map marks the first historical migrations as missing-source candidates. A test-only PostgreSQL bootstrap exists but is not a substitute for the application schema or historical migrations.

## Acceptance gates
- Baseline is reproducible from committed files and has no undocumented manual steps.
- Fresh disposable database replay succeeds from zero.
- RLS and function-execution grants are tested against intended roles; do not weaken authorization to make tests pass.
- Core school isolation, academic rollover, payment allocation, backup/restore, and permissions tests pass.
- GitHub Actions validates the same chain; logs and artifacts are retained.
- No production writes, no changes to `main`, and no merge of PR #7 until reviewed.
