# Lamīn — Existing database upgrade, backup/restore, and recovery gate
Date: 2026-10-15
Review branch: `review/lamin-db-schema-baseline-20261015`
Review head before this report: `bfb0e61290b9d437db5aa02f6c7caf7bec94c572`

## Decision
**NOT APPROVED for merging PR #7, production deployment, or final APK release.**

The current evidence proves reconstruction of a fresh database from the catalog-derived Baseline and a narrow synthetic selective-upgrade test. It does **not** prove upgrade of a trusted historical database, a full database backup export/restore, or recovery from a real existing-schema upgrade.

## Immutable safety boundary
- Production project `School-Management`, ref `stbrhcgzfxvpayfnnqfl`, PostgreSQL 17.6.
- Separate test project `Lamin-Test`, ref `iijngozcfzskhvxrmlwi`, PostgreSQL 17.11.
- Read-only project metadata and migration registries were inspected. Production still reports 74 migration records; Lamin-Test has 13 records from baseline stages 0001–0012 plus its test-only ACL normalization check.
- No trusted historical backup/clone with provenance was available in the inspected evidence. The current production database is a live current-state reference, not a prior-version fixture; Lamin-Test was created empty and reconstructed from the Baseline. Neither qualifies as a historical pre-upgrade snapshot.
- No production DDL/DML, production registry write, `migration repair`, or `db push` was performed. No production data was copied into staging. `main` remains at `807da91475cc0f53827acb9940c62ca61c8f64d1`. PR #7 remains open and unmerged.

## Latest CI observed for the previous review head
- [Baseline acceptance, run 38686246623](https://github.com/laminahmed12/school-mobile-app/actions/runs/38686246623): **success** on `bfb0e61290b9d437db5aa02f6c7caf7bec94c572`. Job `clean-baseline-and-acceptance` completed successfully, including empty disposable DB validation, baseline build, reference fingerprint, verified repository deltas, tenant/finance/backup/restore synthetic acceptance, and the selective stage-0012 upgrade with synthetic rows.
- [Flutter / Android candidate, run 38686246627](https://github.com/laminahmed12/school-mobile-app/actions/runs/38686246627): Flutter formatting, static analysis, and automated tests had passed when inspected; Android candidate APK build was still in progress. Do not report this workflow as fully successful until its final conclusion is confirmed.
- The CI upgrade step starts from a database constructed from the current-state Baseline, seeds synthetic rows, and applies stage 0012. This is **not** a replay of the 74-entry production history or a prior-production-version upgrade.

## Source provenance
The following original files remain unavailable in the review branch and the two known recovery branches:
- `supabase/migrations/20260924214051_001_core_tables.sql`
- `supabase/migrations/20260924214123_002_rls_policies_rpcs.sql`
- `test/sql/supabase_test_bootstrap.sql`

The production registry lists 74 migration versions, but source equivalence for the full chain has not been established. Do not fabricate missing SQL, promote archived candidates into active migrations, or mark history applied based on names or schema similarity.

## Gate-by-gate verdict

| Gate | Evidence actually run | Verdict |
|---|---|---|
| Create a new empty database | Baseline CI and separate empty Lamin-Test build; 40 public tables, RLS enabled on all 40; normalized reference fingerprint and ACLs matched after correction | **Passed for current-state Baseline only** |
| Narrow synthetic existing-schema upgrade | CI builds a Baseline database, seeds synthetic rows, applies stage 0012, verifies row preservation and target behavior | **Passed, narrowly scoped** |
| Upgrade from a trusted historical database version | No provenance-verified prior snapshot/clone; original early migration sources missing | **Not run / not proven** |
| Full backup export from the upgraded database and restore into a separate empty database | Synthetic backup/restore acceptance and transaction-wrapped staging smoke tests only; no production-like full export-and-restore rehearsal | **Not run / not proven** |
| Post-restore comparison | No trusted pre-upgrade snapshot to compare; no complete production-like restore comparison | **Not run / not proven** |
| Rollback/recovery of a real existing-database upgrade | Transaction fixture rollback succeeded, but no applied forward migration was recovered from a pre-upgrade snapshot | **Not run / not proven** |
| Security-owner disposition | 3 RLS-enabled tables without policies, 13 authenticated-executable SECURITY DEFINER routines, policy overlap findings, duplicate index, and production leaked-password protection warning remain to be dispositioned | **Blocked** |

## Required safe test fixture and execution plan
Before claiming an existing-database upgrade passes, obtain an authorized, schema/data-safe backup or clone that is demonstrably from a prior application/database version. Do not use the live production database as the test target. The fixture must have:
1. A recorded source commit/release, capture time, PostgreSQL version, and method of capture.
2. A checksum for the backup artifact, plus migration registry snapshot and normalized schema fingerprint.
3. Before-state counts and non-sensitive integrity checks for schools/tenants, students, fee assessments, payments, payment allocations, discounts, payroll, academic years/rollover batches, and backup/audit records.
4. Explicit confirmation that sensitive production data is not being copied to an unapproved environment; prefer masked/synthetic data where feasible.

Then:
1. Restore the fixture into a dedicated disposable database that is not production and not the existing Lamin-Test baseline database.
2. Design a separate, uniquely versioned, forward-only migration for that exact known pre-upgrade schema. Review DDL/data transformations, tenant scope, financial invariants, RLS, grants, SECURITY DEFINER routines, idempotency, and interruption behavior.
3. Capture before-state registry, schema fingerprint, counts, and integrity checks; apply only the proposed migration to the disposable fixture.
4. Capture the same after-state evidence; test two-school isolation in both directions, payment idempotency/allocation, cross-tenant rejection, discounts, payroll, and academic rollover.
5. Export a full backup of the upgraded disposable database and restore it into a **different empty disposable database**. Compare normalized schema/fingerprint, roles/grants/policies/routines, registry semantics, critical row counts, financial totals, foreign-key/integrity checks, and application-level tenant/finance tests.
6. Test recovery by restoring the original pre-upgrade backup to a fresh database and confirming the documented cutover/recovery path. Record what is recoverable, expected recovery time, and any data written after the backup that would be lost. Prefer restore-to-new-database and controlled cutover over improvised reverse SQL.
7. Repeat with an interruption/failure injected at a safe disposable step if the migration contains multi-step data transformations. Confirm restart/idempotency or document manual recovery.
8. Require reviewer sign-off on all evidence and security findings before production rollout is even considered.

## What rollback can and cannot promise
- A transaction-level `ROLLBACK` only proves that the synthetic test transaction left no fixture rows behind; it does not reverse a committed production migration or prove a restore path.
- DDL/data changes that are transactional may be reverted before commit if the operation is fully contained in one transaction; do not assume every Supabase migration or external side effect is atomically reversible.
- A committed forward migration may not have a safe automatic reverse, especially if data was transformed or discarded. Restoring a verified pre-upgrade backup can recover the captured state, but changes made after backup capture may be lost unless separately reconciled.
- The preferred recovery option is restore-to-new-database followed by controlled cutover, with the original database retained until validation is complete. No such cutover rehearsal has yet been performed.

## Final disposition
- **Fresh database creation:** verified for the catalog-derived Baseline path, subject to security review.
- **Existing database upgrade:** not verified against a trusted prior version.
- **Full backup/restore:** not verified with a production-like upgraded database and separate restore target.
- **Rollback/recovery:** only synthetic transaction rollback is verified; real upgrade recovery is untested.
- **PR #7:** keep open and unmerged. Do not issue a final APK. Do not run `migration repair` or `db push` against production, and do not modify production migration history.
