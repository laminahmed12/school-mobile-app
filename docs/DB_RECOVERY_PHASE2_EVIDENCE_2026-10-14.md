# Lamīn DB recovery — Phase 2 evidence and security review
**Date:** 2026-10-14  
**Repository:** `laminahmed12/school-mobile-app`  
**Branch:** `fix/lamin-db-recovery-root-cause-20261014`  
**Branch head observed before this phase:** `e929582ef764166add244913b16cf56c72b38b55`  
**Production project inspected read-only:** `stbrhcgzfxvpayfnnqfl` (School-Management)  
**Safety:** catalog-only SQL; no application rows selected; no DDL/DML; no migration executed; no grants/config changed.

## 1. Git/source recovery attempts in this phase
- Rechecked the exact paths on all 11 branch names returned by the repository branch search: both files returned NOT_FOUND on every visible branch (22 path/ref checks). A repository commit search for each missing filename returned zero results.
- Queried commit search for the exact base-migration filename and test-bootstrap filename: no matching commits were returned by GitHub's commit-search endpoint.
- Visible branches checked: `main`, `plan/lamin-finance-rollover-hardening`, `fix/lamin-postgres-integration-20261014`, `lamin-hardening-20261012`, `release/lamin-2.0.0-rc1`, `release/lamin-2.0.0-rc2`, `release/lamin-2026-school-year`, `build/apk-final`, `work/lamin-release-readiness-20261014`, `fix/lamin-dart-format-20261014`, and `fix/lamin-db-recovery-root-cause-20261014`. This is the set returned by the branch search, not proof of every tag, hidden ref, unreachable Git object, reflog, or private developer clone.
- This phase did not recover either original SQL file. No placeholder or reconstructed SQL was created.

## 2. 93-case migration mapping audit
A row-by-row companion CSV was generated from the existing `supabase/migration_history_map.csv`; the original map and its statuses were not changed.
- Rows in scope: 93
- Production entries with no exact candidate in the inspected refs/searches: 68; classified `missing_from_examined_refs`, not proven globally deleted.
- Similar-name candidates with differing version: 6; classified `needs_additional_evidence`; content equivalence remains unproven.
- Repository-only candidates without an exact production ledger mapping: 19; classified `needs_additional_evidence`.
- Proven exact matches: 0.
- Proven content-difference pairs: 0, because no source pair was established for the missing entries.
- The six similar-name rows are not labeled as content differences; only a source diff can establish that.

See `docs/MIGRATION_MAPPING_AUDIT_93_2026-10-14.csv`.

## 3. Schema-only inspection result
A read-only PostgreSQL catalog query was used to extract table metadata (table names, column counts, RLS/force-RLS flags, policy/constraint/index counts). It does not query student, parent, staff, payment, or other application records. The database reports PostgreSQL 17.x (project metadata previously observed as 17.6.1.166).
- Catalog inventory in prior verified pass: 40 public base tables, 3 public views, 99 public RLS policies.
- A table-name/RLS inventory CSV contains 40 public base-table names and RLS flags. It is a structural inventory, **not** a `pg_dump --schema-only` archive and not a substitute for migration history. The connected tools exposed catalog queries but no trustworthy full schema-only dump operation or database connection string for running `pg_dump`; a full export remains unverified.
- All inspected public views are marked `security_invoker=true`.
- The `student_finance` view joins `payments` on `student_id` alone, unlike the other reviewed finance views which also constrain school scope. This is a query-scope inconsistency requiring a controlled test and comparison against intended source; no production change was made.
- `license_codes`, `login_attempts`, and `owner_gate_attempts` have RLS enabled and zero policies; catalog privileges show neither `anon` nor `authenticated` has SELECT/INSERT on these tables. This indicates default deny for those roles under current direct table grants, but does not evaluate service-role/backend paths.

## 4. SECURITY DEFINER review — preliminary, definition-level
- Catalog inventory found 34 SECURITY DEFINER function signatures in `public`/`private`; the previously recorded inventory shows 16 executable by `authenticated` and one `private.validate_payroll_transaction()` with an `anon` EXECUTE grant. The `anon` role has no USAGE on `private`; that grant alone does not prove direct callability.
- `public.bootstrap_owner_school`: body checks `auth.uid()`, active profile, and role exactly `owner`; uses empty search_path and schema-qualified object names. Preliminary positive finding, not full test coverage.
- `public.execute_academic_rollover`: body checks school scope and owner/admin role, locks the batch row, validates state/review/target class and debt provenance, then writes enrollments/opening balances and closes prior academic years. Requires adversarial isolated tests for cross-tenant IDs, duplicate execution, concurrency, and rollback on mid-operation failure.
- `public.create_next_academic_year`: body checks school scope and owner/admin role and validates dates/name; its `p_migrate_students` and `p_migrate_staff` parameters are present in the signature but are not referenced in the visible body. This may be a behavior/contract mismatch; confirm caller expectations before changing anything.
- `public.delete_school_user`: checks owner/admin role, school scope, and restricts target roles to accountant/supervisor before deactivation/audit writes.
- Backup function review is incomplete: `export_backup` delegates to `export_backup_core_v4`; `export_backup_core_v2` is not directly executable by authenticated according to current grants, but wrapper reachability and all restore/export variants require full caller/ACL analysis. No permissions were changed.
- All reviewed SECURITY DEFINER functions had explicit function-level `search_path` settings in the inventory; this alone does not establish authorization correctness.

## 5. Test gate and stop condition
- Full migration replay on an empty PostgreSQL database remains **NOT RUN**: the original base migration and bootstrap source are unavailable, and the 93-case chain mapping is unresolved.
- Do not fabricate `001_core_tables.sql`, do not treat a generated bootstrap as historical source, and do not enable migration execution in CI until authoritative source and ordering/dependencies are proven.
- Required next evidence: a local `.git` repository or `git bundle` from the developer machine; unreachable-object/reflog scan on that clone; CI cache/artifact or uploaded archive containing original SQL; or a trusted schema-only dump plus original migration SQL/history from the environment where the migrations were authored/deployed. For exact source restoration, a schema snapshot alone is insufficient.
- No changes to `main`, production data/schema/grants, migration ledger, or APK/release.
