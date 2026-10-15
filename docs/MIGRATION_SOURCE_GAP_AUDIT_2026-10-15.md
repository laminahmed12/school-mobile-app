# Lamīn migration-source gap audit and database rebuild evidence — 2026-10-15

## Decision summary

**The original SQL sources for two production migration-history entries and the old SQL test bootstrap were not recovered.** No replacement file is being represented as historical source. A separate catalog-derived baseline is retained under `supabase/baselines/20261015/` and is explicitly a current-schema reconstruction, not a replayable reconstruction of the original migration chain.

- `supabase/migrations/20260924214051_001_core_tables.sql` — `historical_source_not_found`
- `supabase/migrations/20260924214123_002_rls_policies_rpcs.sql` — `historical_source_not_found`
- `test/sql/supabase_test_bootstrap.sql` — `test_fixture_source_not_found`
- No original commit SHA or original blob SHA exists to report for these three absent files. The register records the exact absence evidence and separate baseline substitutes: [source-gap register CSV](MIGRATION_SOURCE_GAP_REGISTER_2026-10-15.csv).

## Search scope and exact evidence

The exact path was checked against **17 reachable branch heads** and a branch-scoped GitHub commit-history query for each of the three paths. Each query returned **zero commits**. The default-branch path history queries also returned zero commits. Current branch-tree checks likewise found none of the three paths. Branches surfaced by the branch search index as `release/lamin-2.0.0-rc1`, `release/lamin-2.0.0-rc2`, and `release/lamin-2026-school-year` returned 404 from repository content/ref checks, so they were not counted as reachable, inspectable refs.

Reachable refs checked:

- `lamin-hardening-20261012`
- `checkpoint/e8571a2-db-review-20261014`
- `checkpoint/lamin-db-root-gate-20261014`
- `checkpoint/lamin-last-verified-flutter-20261014`
- `checkpoint/lamin-source-checkpoint-20261014`
- `experiment/lamin-db-baseline-reconstruction-20261014-continuation`
- `experiment/lamin-db-baseline-reconstruction-20261014`
- `experiment/lamin-db-schema-baseline-20261015`
- `fix/lamin-baseline-routine-terminators-20261015`
- `fix/lamin-baseline-routine-terminators-review-20261015`
- `fix/lamin-dart-format-20261014`
- `fix/lamin-db-recovery-20261014`
- `fix/lamin-db-recovery-root-cause-20261014`
- `fix/lamin-postgres-integration-20261014`
- `plan/lamin-finance-rollover-hardening`
- `review/lamin-db-schema-baseline-20261015`
- `work/lamin-release-readiness-20261014`

### Required commit and branch inspection

- [Commit `e8571a2`](https://github.com/laminahmed12/school-mobile-app/commit/e8571a27938f583225915e7a9ba531b8a9e179d7) changed exactly one file: `supabase/migrations/20261014070000_include_fee_assessments_in_backup.sql`. It did not contain either historical SQL source or the missing test bootstrap.
- [`fix/lamin-db-recovery-root-cause-20261014`](https://github.com/laminahmed12/school-mobile-app/tree/fix/lamin-db-recovery-root-cause-20261014) head: `5dab15059a680db013f650049d2e64e1bf415c6e`. The root-gate checkpoint points to the same head. Neither missing historical SQL path nor the old test bootstrap is in that branch tree or its path-specific history.
- [`checkpoint/lamin-source-checkpoint-20261014`](https://github.com/laminahmed12/school-mobile-app/tree/checkpoint/lamin-source-checkpoint-20261014) head: `ae8936c06b6308ab8bbb93975fab2f2439efd8e3`. The three missing paths are absent there too.
- The prior 20-file archived migration search was **not repeated**, per task scope. No archived migration candidates were moved into `supabase/migrations/`.

## Workflow artifacts

The relevant schema/baseline workflow runs inspected for downloadable artifacts did not contain a SQL source archive:

- [Baseline acceptance run 38664269396](https://github.com/laminahmed12/school-mobile-app/actions/runs/38664269396) — no artifacts.
- [Baseline acceptance run 38664264437](https://github.com/laminahmed12/school-mobile-app/actions/runs/38664264437) — no artifacts.
- [Earlier baseline run 38650309583](https://github.com/laminahmed12/school-mobile-app/actions/runs/38650309583) — no artifacts.
- [Earlier baseline run 38653455326](https://github.com/laminahmed12/school-mobile-app/actions/runs/38653455326) — no artifacts.
- [Baseline acceptance run 38661102778](https://github.com/laminahmed12/school-mobile-app/actions/runs/38661102778) — no artifacts.
- [Android candidate run 38661102782](https://github.com/laminahmed12/school-mobile-app/actions/runs/38661102782) has an artifact named `lamin-android-candidate-apk` (29,662,815 bytes); it is an APK, not SQL source, and was not used as migration evidence.

## Explicitly separate replacement baseline

The original three files remain absent. Existing catalog-derived artifacts are kept in a different namespace and must not be renamed to impersonate historical files:

| Purpose | Baseline/test substitute | Git blob SHA |
|---|---|---|
| Current application tables and sequences | `supabase/baselines/20261015/0001_tables_sequences.sql` | `622bb4f6a3958a8b9222a87d47839bd6d9fd3de3` |
| Current routine/policy/grant definitions | `supabase/baselines/20261015/0002_private_routines.sql` through `0009_public_routines_remaining.sql`, and `0011_security_policies_triggers_grants.sql` | `0011`: `cb836d2a1a86aeb5320bdc003f1bdfc84f98a7ea` |
| Metadata-only reference manifest | `supabase/baselines/20261015/reference_schema_manifest.json` | `088a99b92b6d4077f9d196cae34375c2498fddfa` |
| Test-only auth/role compatibility bootstrap | `supabase/baselines/20261015/test_bootstrap.sql` | `2ffd4cb0daee350899aa1c84cb73d39d6b564e03` |
| Deliberate current-catalog drift correction | `supabase/baselines/20261015/0012_repo_drift_reconciliation.sql` | `081c805d185e24262923dd26e0fcedf50677f30a` |

These are baseline substitutes, not the original SQL blobs. The reference manifest is metadata-only; no school/student/attendance/financial row data was exported.

## Database verification: clean build vs existing-schema upgrade

The existing workflow uses separate disposable PostgreSQL 17.6 databases and deliberately does **not** claim a complete replay of the missing historical migration chain.

### A. Clean database build

[Acceptance run](https://github.com/laminahmed12/school-mobile-app/actions/runs/38664269396) completed successfully.

1. Verify the disposable database is empty.
2. Install the test-only auth compatibility stub.
3. Check routine statement terminators and run normalizer regression tests.
4. Apply catalog-derived stages `0001`–`0011`.
5. Compare the generated metadata fingerprint byte-for-byte against `reference_schema_manifest.json`; `diff` succeeded.
6. Apply stage `0012_repo_drift_reconciliation.sql`.
7. Run baseline acceptance checks: 40 application tables, RLS enabled on all 40, 102 policies after the documented owner-policy delta, 32 user triggers, 46 application routines, two-school tenant isolation, payment idempotency/allocation, cross-tenant payment rejection, and synthetic backup/restore coverage for fee assessments and allocations.

### B. Existing-schema upgrade-path test

The same run created a **separate** `lamin_upgrade_test` database. It rebuilt the catalog-derived reference schema, checked its pre-upgrade fingerprint, inserted synthetic school/student rows, applied only the documented stage `0012` correction, then checked that rows survived and the corrected rollover/security behavior was present. The security/finance/backup test suite was run again after the correction.

This is an upgrade-path/data-preservation test against the catalog-derived baseline, **not** a proof that all 74 production history rows can be replayed from original migration SQL. That proof remains blocked by the missing historical sources.

## Migration map

The 93-row map now has an explicit status, evidence text, evidence URL, and candidate source ref/commit fields. It has no row whose status is the generic `unresolved` value:

- 74 production-history records.
- 19 repository-only candidates.
- 2 historical SQL sources explicitly marked missing.
- 6 same-name/version-mismatch relationships retained as unproven source equivalence (one is additionally partial before baseline reconciliation).
- 2 missing current-catalog effects and 1 incorrect current-catalog effect explicitly marked as corrected in stage `0012`.

A row with a clear status does not mean the historical source equivalence is proven. The evidence column explicitly preserves that limitation. For the 25 candidate SQL files, `source_snapshot_commit` means the branch-tip commit where the file was observed, not the commit that originally introduced it. After reusing the exact source refs already recorded in the map (without repeating the 20-file archive search), the current Git blob SHA was recorded for each of the 25 candidate files. The two missing historical SQL files and missing test fixture correctly have no original source commit/blob SHA because they were not found. The deterministic checker `scripts/validate_migration_history_map.py` now validates all 25 blob fingerprints as 40-character hexadecimal Git object IDs.

## Safety boundary

- `main` was not modified.
- No production DDL/DML was run.
- No migration history was edited or repaired.
- No `supabase db push` or migration repair command was used.
- No archived migration candidate was copied into the active migration directory.
- No PR was merged and no final APK was released.
