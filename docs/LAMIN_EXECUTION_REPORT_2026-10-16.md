# Lamīn — Execution and acceptance report (2026-10-16)

## Scope executed
- Added reconstruction bridge under `supabase/reconstructed/20261016/`.
- Added a newly authored test-only bootstrap at `test/sql/supabase_test_bootstrap.sql`.
- Added a reconstruction map distinguishing reconstructed current state from missing historical source.
- Extended the schema acceptance workflow to apply the bridge to a third disposable PostgreSQL database and run acceptance checks.
- Updated PR #7 with evidence and remaining gates.

## Verified successful CI
- Schema acceptance run: https://github.com/laminahmed12/school-mobile-app/actions/runs/38826365300 — SUCCESS.
  - Empty database check and bootstrap
  - Baseline schema build and reference fingerprint comparison
  - Repository delta application
  - Tenant isolation, finance, backup and restore tests
  - New reconstructed bridge on a third disposable database
  - Selective upgrade/data preservation test
- Flutter/Android candidate run: https://github.com/laminahmed12/school-mobile-app/actions/runs/38826365432 — SUCCESS.
  - Formatting, strict static analysis, automated tests, Android candidate build and artifact upload.
  - Artifact is a candidate, not a signed release.

## Staging security checks (read-only)
Project: Lamin-Test (`iijngozcfzskhvxrmlwi`), status ACTIVE_HEALTHY, PostgreSQL 17.11.

A catalog query on representative finance/admin routines confirmed:
- `public` wrappers are SECURITY INVOKER.
- `private` implementations are SECURITY DEFINER, owned by postgres.
- `anon` does not have EXECUTE on the checked routines.
- `authenticated` has USAGE on schema `private` and EXECUTE on the checked private implementations.
- `service_role` has EXECUTE on the checked routines.

This means the private routines may be directly callable by authenticated database sessions if the `private` schema is exposed by PostgREST. The wrapper-to-private delegation design also relies on permissions. Do not revoke authenticated EXECUTE blindly because that may break invoker wrappers.

## Exposure check limitation
The project URL and publishable key are available, but this execution environment has no generic HTTP client for making a controlled PostgREST request. PostgreSQL does not expose the PostgREST `db-schemas` configuration through the checked `pg_settings` or database/role settings; no `pgrst.db_schemas` value was found there. Therefore actual `private` schema API exposure was **not proven either enabled or disabled**. This remains an explicit external verification gate in Supabase API settings or a controlled API test. No claim is made that it passed.

## Advisor findings
- Security advisor on Lamin-Test reports three INFO findings: RLS enabled without policies on `public.license_codes`, `public.login_attempts`, and `public.owner_gate_attempts`. These may be service-only tables; inspect table grants before deciding on policies.
- Performance advisor reports 70 INFO-level unused-index findings. As the staging database is new and tests are synthetic, unused status is not evidence that those indexes should be removed. No indexes were dropped.
- Auth leaked-password protection and production security findings were not changed.

## Migration provenance and production-like rehearsal
- The two original historical SQL files from 2026-09-24 remain unrecovered.
- The new bridge is a current-state reconstruction, not original historical SQL and not an incremental production migration.
- The full 74-row production migration history was not replayed end-to-end.
- CI tests transactional backup/restore behavior; a production-like restore rehearsal remains outstanding.
- No production DDL/DML, migration repair, db push, or production history edits were performed.

## Repository state
- PR #7 remains open: https://github.com/laminahmed12/school-mobile-app/pull/7
- Main remains at `807da91475cc0f53827acb9940c62ca61c8f64d1`.
- Latest reviewed head for the bridge is `73d99711ad174a24aca103883703aa39ffa8721a`.
- No merge into main and no signed/final APK release was performed.

## Decision
**Development bridge: PASS for isolated clean-install testing.**
**Flutter/Android candidate validation: PASS.**
**Production database deployment: NOT APPROVED yet**, because PostgREST exposure/authorization and full migration-history/restore rehearsal gates remain unresolved.
