# Lamīn database recovery: root-cause execution log
**Date:** 2026-10-14  
**Repository:** `laminahmed12/school-mobile-app`  
**Branch created:** `fix/lamin-db-recovery-root-cause-20261014`  
**Base commit:** `b3b4b696b92cfee3a2900db4aed9b4d35d78f69e` on `fix/lamin-postgres-integration-20261014`  
**Production safety:** catalog-only SELECTs; no application rows queried, no DDL/DML, no migration execution, no production configuration changes.

## Executive result
The root cause remains a source-provenance gap, not evidence that the production database itself is corrupt. The production migration ledger records 74 versions, but the repository mapping still has 93 unresolved entries (68 P1, 6 P2, 19 R1). The two historical SQL files have not been recovered. A clean PostgreSQL migration pass therefore cannot honestly be claimed.

## Branching and repository preservation
A new independent repair branch was created from the latest documented recovery work branch. `main` was not moved or modified. No migration history was rewritten, no migration deleted, no placeholder SQL added, and no release/APK built.

## Archive forensics
The following available Library ZIPs were materialized and checked with Python's ZIP integrity test:
| Artifact | SHA-256 | Entries | Finding |
|---|---|---:|---|
| `school_management_full_stack_v3(1).zip` | `12f3d7b99c409b24680e353a7498639c640ed692311167d8ff5cd48a6865aafb` | 100 | Contains Flutter, NestJS and `backend/prisma/schema.prisma`; no Supabase migration directory, SQL migration, or test bootstrap. Not a proven match for the deployed Supabase schema. |
| `school_management_full_stack(1).zip` | `2ae2c45a649eb0908d30de052e96f3dc6099a56b26d39c98c1a996c95f1a33cb` | 48 | Older separate Prisma/NestJS/Flutter implementation; no historical Supabase SQL chain or bootstrap. |
| `lamin-release-apk.zip` | `a698671821b260b767fc680eeee78b8e1b10bc09cc3cee6a430fa12f233f1b92` | 1 | Contains only `app-release.apk`; cannot restore SQL source. |

ZIP integrity passed for all three artifacts. The V3 archive's Prisma model must not be transplanted into the current database without independent proof of schema identity.

## Production schema catalog inventory (read-only)
Project ref: `stbrhcgzfxvpayfnnqfl` (School-Management).
- 40 public base tables.
- 3 public views.
- 99 public RLS policies.
- 39 public functions and 7 private functions.
- 74 recorded migration versions, including `20260924214051 / 001_core_tables`.

The application table inventory includes school/student/teacher and academic-year data, plus `student_fee_assessments`, `student_opening_balances`, `payments`, `payment_allocations`, `discount_rules`, `student_discount_awards`, `payroll_periods`, `payroll_transactions`, `rollover_batches`, and `rollover_items`. Only catalog metadata was read; no school, student, or payment records were selected.

A read-only Storage catalog check returned no visible rows from `storage.buckets` or `storage.objects`. This is limited evidence, not proof that no external backups exist.

## SECURITY DEFINER review — inventory only, not a security clearance
Catalog query across `public` and `private` found 34 SECURITY DEFINER function signatures:
- 16 signatures are executable by `authenticated`.
- 1 signature is executable by `anon`; it is `private.validate_payroll_transaction()`.
- 0 of the 34 lacked an explicit function-level `search_path` setting.

These are permission/configuration inventory results, not proof that the function bodies are safe. The anonymous EXECUTE result concerns a function in the `private` schema; effective exploitability also depends on schema USAGE and trigger/function context. Do not revoke grants or alter production permissions based on this inventory alone. Next security step is definition-level review of each privileged function, its caller authorization, schema USAGE, object ownership, writable schemas, and required grants, followed by tests on an isolated database.

## CI gate and what it actually proves
Workflow `.github/workflows/postgres-migration-tests.yml`:
1. Parses migration SQL syntax.
2. Checks migration filenames and non-empty contents.
3. Runs existing ledger arithmetic/source regression fixtures.
4. Requires the core migration, migration map, bootstrap, zero unresolved mappings, and no mapped missing files before it will apply the chain.

The existing PostgreSQL run `38528466520` stopped at step 4 with 93 unresolved mappings and missing bootstrap. PostgreSQL service readiness, SQL parsing, and source guards do not prove that the entire migration chain applies to an empty database. The new branch has not yet produced a clean-chain run because authoritative prerequisites remain missing.

## Exact blockers
1. `supabase/migrations/20260924214051_001_core_tables.sql` — not found in the inspected reachable repository refs/path history.
2. `test/sql/supabase_test_bootstrap.sql` — not found in the inspected reachable repository refs/path history.
3. `supabase/migration_history_map.csv` — 93 rows remain unresolved; mapping them without source provenance would misrepresent evidence.
4. The live schema catalog is not a schema-only dump of every definition and cannot prove historical SQL equivalence.
5. The GitHub connector cannot establish that every unreachable Git object, local reflog, remote workstation, or external CI cache has been searched.

## Required next technical steps
1. Obtain an authoritative original checkout/Git bundle/archive or a verifiable source-equivalent schema snapshot with provenance. No user-local files are presumed available.
2. Compare the exact migration source and dependency order with the 74-version ledger and every row in the mapping CSV; retain unresolved states where evidence is absent.
3. Create the bootstrap only as a separately reviewed test fixture based on the actual chain and Supabase auth/RLS dependencies. Never represent it as historical production source.
4. Run all migrations in timestamp order against a fresh disposable PostgreSQL/Supabase-compatible environment. Then test repeatability, tenant isolation/RLS, auth roles, financial invariants, rollover, backup/restore, and privileged-function permissions.
5. Run Flutter format, analyze, tests, and a non-release build from the actual checkout; preserve the logs.
6. Do not merge to `main`, mutate production, or build a final release until all acceptance gates pass.

## Acceptance status
- Historical SQL recovered: **0/2**.
- Mapping cases proven: **0/93**.
- Full chain on an empty isolated database: **NOT RUN / BLOCKED**.
- Definition-level SECURITY DEFINER audit with exploitability tests: **NOT COMPLETE**.
- Production writes: **none**.
- `main) changes: **none**.
- Final APK: **not built**.
