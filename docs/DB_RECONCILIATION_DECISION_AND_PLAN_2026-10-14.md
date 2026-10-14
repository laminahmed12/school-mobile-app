# Lamīn database recovery decision and reconciliation plan

**Date:** 2026-10-14 UTC  
**Repository:** `laminahmed12/school-mobile-app`  
**Branch:** `fix/lamin-db-recovery-root-cause-20261014`  
**Decision:** Original migration chain is not currently recoverable from the reachable, inspected sources. Do not synthesize or relabel historical migrations.

## Decision answers

### Was the original source restored?

**No. It remains unrecovered from the sources currently accessible and inspected.** The exact historical SQL for `20260924214051_001_core_tables.sql` and `test/sql/supabase_test_bootstrap.sql` is still absent. The checked-in map has 74 production-history entries and 19 repository-only candidate files; none of the 93 rows is marked as proven. This is not a claim that unreachable Git objects or external backups cannot exist; it means no authoritative copy has been recovered from the accessible repository history, branches, PRs, CI artifacts, releases, or the inspected archives so far.

### What is the last trusted schema tied to a source-code revision?

**There is no complete, replayable schema currently proven to correspond to a specific code revision.** The production catalog snapshots in this branch are trustworthy as read-only descriptions of the live state at the recorded capture time, not as a historical migration source and not as proof that any repository migration file produced that state. The repository's available SQL migrations are partial: they cannot build a fresh database because the base migration and test bootstrap are missing. The 19 repository-only candidates are not proven to match production history.

## Evidence preserved

- `docs/reference_schema_catalog_2026-10-14.json`: sanitized current table metadata; application rows and row counts omitted.
- `docs/reference_supabase_migration_history_2026-10-14.json`: the 74 recorded Supabase migration versions/names, metadata only.
- `docs/reference_rls_policies_2026-10-14.json`, `docs/reference_schema_indexes_2026-10-14.json`, `docs/reference_schema_triggers_2026-10-14.json`.
- `docs/reference_public_routine_definitions_2026-10-14.sql` and `docs/reference_private_routine_definitions_2026-10-14.sql`.
- `docs/reference_routine_signatures_2026-10-14.json` and `docs/reference_table_grants_summary_2026-10-14.json`.
- `docs/migration_recovery_classification_2026-10-14.csv`: row-level evidence classification for all 93 map rows.

No student/parent/staff application rows or credentials were exported. No production write, migration, ACL/RLS change, or migration-history edit was performed.

## Classification of all 93 map rows

The companion CSV records the classification and next evidence required per row:
- **68 production-history entries: `MISSING_SOURCE`** — no exact normalized source filename is available in the repository map.
- **6 production-history entries: `CANDIDATE_NEEDS_CONTENT_PROOF`** — similarly named repository candidates have different versions; name similarity is not equivalence.
- **19 repository-only files: `REPOSITORY_ONLY_NO_PRODUCTION_MATCH`** — they may contain later changes, already-applied changes under other versions, or unapplied changes; none may be replayed blindly.

No row is labeled content-matched. This classification is deliberately conservative. It is a statement about the evidence currently available, not proof that no other copy exists elsewhere.

## Reconciliation strategy if the historical chain remains unavailable

Do not turn the live catalog into a replacement for each old migration. Establish a **new, explicitly versioned canonical baseline** from a reviewed, schema-only export, with provenance, checksums, dependency ordering, and independent review. The baseline represents the current production structure at a named capture point; it must not pretend to reconstruct historical intent.

### Phase A — finish the baseline evidence package

1. Obtain a trusted schema-only export using an authorized read-only database credential or supported Supabase schema dump. Include table/view/materialized-view definitions, constraints, indexes, sequences, enum/domain types, extensions, functions, triggers, policies, grants, ownership, role memberships, and required Auth/storage dependencies.
2. Compare the dump to the sanitized catalog files already committed. Investigate every mismatch. Do not include application table data or secrets.
3. Record PostgreSQL/Supabase versions, capture time, source project ref, command/tool versions, and SHA-256 hashes. Have a second reviewer approve the schema package.
4. Preserve the 74-entry production history unchanged. Keep all unresolved legacy migration files intact as evidence; do not rename, delete, or rewrite historical timestamps.

### Phase B — introduce a canonical migration line without pretending it is the old line

1. Store the reviewed baseline as a **new, explicitly named canonical bootstrap artifact** with a new version and a clear comment that it is a current-state baseline, not a reconstruction of the 74 historical migrations.
2. Keep unverified legacy candidates segregated from the canonical fresh-build sequence while preserving their bytes and hashes in version control. Any move/retirement of the old sequence must be a separate reviewed commit and must retain a retrievable archive; do not silently change the default migration sequence.
3. Apply only forward, additive reconciliation migrations after the baseline. Before each migration, state preconditions and postconditions; use catalog assertions to avoid recreating existing objects. Destructive or data-transforming operations require a separate reviewed data plan and explicit rollback/restore proof.
4. For an existing production database, use a separately reviewed adoption procedure: verify the live schema matches the approved baseline, record the baseline as adopted only after that proof, preserve all existing migration-history rows, and apply only forward migrations that are demonstrably not already present. **No adoption or production command is authorized by this document.**

### Phase C — separate tests and required gates

The following must be implemented and executed as distinct jobs against disposable databases. A single source-parser or fixture test does not satisfy either job.

**1. Fresh rebuild test**
- Start a brand-new PostgreSQL instance/database with the required Supabase-compatible roles, Auth stubs/dependencies, extensions, and schemas.
- Apply only the canonical migration sequence in order, fail on any SQL error, and compare resulting catalogs against the approved baseline manifest.
- Assert tables, views, constraints, indexes, routines, triggers, RLS enabled/forced flags, policies, grants, ownership, and extension versions.
- Run school-isolation negative tests: user from school A cannot select/insert/update/delete school B rows, including through SECURITY DEFINER functions and RPCs.
- Run backup/restore round-trip tests for each supported backup version, verify fees, discounts, payments/allocations, payroll, rollover and audit provenance, and verify one school's backup/restore cannot leak or overwrite another school's data.

**2. Current-schema upgrade test**
- Restore a schema-only baseline plus a separately generated, synthetic fixture dataset into a disposable database; never copy production student/family rows.
- Apply only the proposed forward reconciliation migrations.
- Assert pre-existing objects are not duplicated or dropped; verify catalog delta is exactly the reviewed delta.
- Run migration idempotency/precondition tests where appropriate, RLS and grant regression tests, cross-school isolation, and backup/restore round trips.
- Exercise restore from a pre-upgrade backup and document a rollback path before any future production change.

**3. Security gate**
- Review every SECURITY DEFINER function for a fixed safe `search_path`, explicit school/role authorization, EXECUTE grants, and absence of privilege escalation.
- Review tables with RLS but no policies and all exposed schemas' table/function grants. A finding can be accepted only with documented rationale and test coverage.
- Verify Auth password protection configuration separately from SQL migrations.

**4. CI gate**
- Keep SQL parsing/source regression checks, but do not call them a full migration pass.
- Run the fresh rebuild and upgrade tests as separate required jobs. Publish database catalog diffs and test logs as reviewable artifacts.
- Fail closed if the approved baseline manifest, test bootstrap, migration map, or either test job is missing/failed. Do not relax the existing unresolved-history gate to obtain green CI.

## Current test result and blocker

The prior disposable-PostgreSQL workflow run `38528466520` failed at the explicit unresolved-history/missing-bootstrap gate after SQL parsing and source-regression guards. It did **not** execute the complete migration chain. No fresh rebuild or upgrade test has passed. This branch does not have local PostgreSQL/Docker tooling available in the current execution environment.

## Go/no-go

**NO-GO for merge or release.** The safe next implementation step is to obtain and review a complete schema-only export and its ACL/dependency details, then create the canonical baseline in a separate reviewed commit. Until that baseline is approved, writing a new SQL bootstrap or claiming a clean rebuild would be speculative. Production remains unchanged.
