# Lamīn — Historical backup availability check
Date: 2026-10-15
Repository: `laminahmed12/school-mobile-app`
Branch: `review/lamin-db-schema-baseline-20261015`
PR: [#7](https://github.com/laminahmed12/school-mobile-app/pull/7)

## Decision
**No provenance-verified prior-version database backup or database dump was found in the connected Supabase projects, repository branches, repository history for the missing paths, or the inspected GitHub Actions artifacts.** This is an access/evidence limitation, not proof that no backup exists anywhere in the Supabase Dashboard. Historical upgrade, full database export/restore, and actual recovery rehearsal remain blocked and must not be reported as passed.

## 1. Actual connected-tool capability check
The connected Supabase tools expose organization/project inventory, project details, table/catalog queries, migration history, read-only SQL, development-branch listing, Edge Functions, logs, and advisors. They do **not** expose a database-backup inventory/download action or a PITR restore-to-new-project action. The available `restore_project` tool is project lifecycle restoration, not a verified database-backup retrieval API. I did not fabricate an endpoint, use credentials outside the connector, or run any production restore.

Supabase organization inventory returned:
- Organization: `Adreemk.com`, plan `free`.
- Production project: `School-Management`, ref `stbrhcgzfxvpayfnnqfl`, PostgreSQL 17.6.1.166, created 2026-09-24.
- Test project: `Lamin-Test`, ref `iijngozcfzskhvxrmlwi`, PostgreSQL 17.11.0.003, created 2026-10-13.
- Development branch listings for both projects returned empty arrays.

Official Supabase backup guidance: https://supabase.com/docs/guides/platform/backups . It states automated daily backups are provided for Pro/Team/Enterprise projects and recommends regular CLI exports for Free-tier projects. Since the connected organization reports Free tier and backup inventory is not exposed by the connection, managed backup existence/retention cannot be verified here. No assumption has been made that backups exist or do not exist.

## 2. Repository and Git history search
- Enumerated all 24 repository branches returned by GitHub and inspected their recursive trees for SQL dumps, database archives, backup files, schema manifests, and migration-history artifacts.
- No `.dump`, `.backup`, `.bak`, `.tar`, `.gz`, or `.zip` database backup was found in those branch trees.
- The original files were absent from every inspected branch tree:
  - `supabase/migrations/20260924214051_001_core_tables.sql`
  - `supabase/migrations/20260924214123_002_rls_policies_rpcs.sql`
  - `test/sql/supabase_test_bootstrap.sql`
- GitHub commit-history queries for each exact missing path returned zero commits. The current `supabase/migration_history_map.csv` and `docs/MIGRATION_SOURCE_PROVENANCE_2026-10-15.csv` correctly classify the first two as historical source missing and the test fixture as missing.
- Older checkpoint branches contain `docs/reference_schema_routines_2026-10-14.sql` and `docs/reference_public_routine_definitions_2026-10-14.sql`. Their headers identify them as read-only current-state catalog extracts captured 2026-10-14 UTC, without application data; they are **not** a prior-version database or historical migration source.
- Current review branch includes a catalog-derived baseline at `supabase/baselines/20261015/`, including `reference_schema_manifest.json` (Git blob SHA `088a99b92b6d4077f9d196cae34375c2498fddfa`). This is a reconstruction of the current reference schema for empty-database creation, not a historical snapshot.

## 3. GitHub Actions archives inspected
- [Latest Baseline acceptance run 38688287752](https://github.com/laminahmed12/school-mobile-app/actions/runs/38688287752): success. The actual job log lists a disposable empty PostgreSQL database, a catalog-derived baseline build, current reference fingerprint comparison, synthetic row seeding, application of `0012_repo_drift_reconciliation.sql`, and synthetic data-preservation/behavior checks. It does not replay the missing historical migrations or use a trusted pre-upgrade database.
- [Latest Flutter/Android candidate run 38688287712](https://github.com/laminahmed12/school-mobile-app/actions/runs/38688287712): success; the only uploaded artifact is `lamin-android-candidate-apk` (candidate build, not a database backup).
- Downloaded and inspected [artifact from verification run 38671308444](https://github.com/laminahmed12/school-mobile-app/actions/runs/38671308444), archive `lamin-db-verification-38671308444.zip`, GitHub artifact SHA-256 `192aafe3f1d2591b49a6922303d42d1bed1180f37b5c8348877dc578d517da52`. The ZIP contains only `lamin-db-verification-summary.md` (968 bytes uncompressed), explicitly stating historical migration replay is not proven. It contains no database dump.
- The latest CI evidence therefore validates only the synthetic Baseline and narrow stage-0012 path. It is not evidence of historical upgrade or a full database backup/restore.

## 4. Required external action — one provenance package from the Supabase owner
Ask the Supabase project owner to perform **one task**: inspect **Database → Backups** and **Point-in-Time Recovery** for `School-Management` and, if a restore point exists from before a specifically identified migration/release, produce a sanitized, isolated historical fixture package for testing. The package must contain:
1. A logical database export or an isolated restored copy from that actual historical point; do not send production credentials or unmasked sensitive rows.
2. Metadata identifying the source project privately, restore timestamp/UTC, PostgreSQL version, backup type and capture/restore method, plus the known app release/commit and migration-registry state at that point.
3. SHA-256 checksum of the export and a schema fingerprint; include the migration registry snapshot and enough synthetic/masked relational data to validate tenant and financial invariants.
4. Confirmation that the fixture is authorized for testing and is isolated from production.

If the owner finds no suitable historical point, the owner should explicitly confirm that result. Do not replace it with a newly generated current-state dump and label it historical. A current-state dump can support a future forward test but cannot prove a historical upgrade.

## 5. Safety and current gate
Fresh read-only checks show production migration registry remains at 74 rows, ending `20261012191847 allow_optional_teacher_phone`; no production DDL/DML, migration-registry write, `migration repair`, or production `db push` was performed. `main` remains `807da91475cc0f53827acb9940c62ca61c8f64d1`. PR #7 remains open and unmerged, with head `ea6cc239893ac43a14600f3325ca1a1e8f26a09a`.

**Keep the Baseline approved only for new empty databases. Keep PR #7 unmerged and do not issue a final APK.** Once the owner supplies the provenance package, run the historical upgrade, full backup/export and restore into a separate empty database, compare schema/data/ACLs/RLS/routines/migration registry and financial/tenant invariants, and rehearse recovery. If no package exists, record historical upgrade as externally blocked; do not claim success.
