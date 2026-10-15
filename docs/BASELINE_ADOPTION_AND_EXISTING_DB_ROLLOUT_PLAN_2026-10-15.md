# Lamīn — Baseline adoption and existing-database rollout gate
Date: 2026-10-15
Status: **Decision documented; production rollout blocked**

## Decision

Adopt the catalog-derived Baseline under `supabase/baselines/20261015/` as the reconstruction path for **new, empty databases only**, pending review of the security findings below. Do not describe it as a replay or restoration of the historical migration chain.

The original SQL sources remain unavailable in the review branch and both known recovery branches:
- `supabase/migrations/20260924214051_001_core_tables.sql`
- `supabase/migrations/20260924214123_002_rls_policies_rpcs.sql`
- `test/sql/supabase_test_bootstrap.sql`

Production's registry has 74 records. The current migration map is evidence-bearing but does not prove source equivalence for the full 74-record history. Do not fabricate the missing SQL, copy archived candidates into the active migration directory, or mark migrations applied based on names or schema similarity.

## Scope of the current passing evidence

The existing successful CI run (38682346947) proves:
- empty disposable PostgreSQL can be reconstructed from the catalog-derived Baseline;
- the reference schema fingerprint and ACL normalization checks pass;
- stage 0012's selective reconciliation preserves synthetic rows and expected behavior;
- synthetic tenant isolation, finance, and backup/restore acceptance checks pass.

The separate Supabase staging project `Lamin-Test` currently has 40 public tables, RLS enabled on all 40, 102 policies, 3 views, and 32 triggers. Its 13 registry rows are Baseline stages 0001–0012 plus a staging-only ACL-normalization verification migration. Production remains at 74 registry rows, 40 tables, 99 policies, and 3 views. This is current-state comparison, not migration-history equivalence.

## Fresh database path

1. Keep the Baseline stages and their reference fingerprint versioned and immutable once approved.
2. Build a new empty disposable PostgreSQL/Supabase-compatible database.
3. Apply Baseline stages in order; fail on any SQL error.
4. Compare normalized schema fingerprints, grants, RLS flags/policies, routines, triggers, constraints, and indexes with the reviewed reference.
5. Run tenant-isolation in both directions, finance/payment idempotency and cross-tenant rejection, and backup/restore with synthetic data.
6. Run security review for the 3 RLS-enabled tables with no policies, the 13 authenticated-executable SECURITY DEFINER routines, overlapping policies, and production Auth leaked-password protection. Baseline is not release-approved until each finding has a documented owner disposition.

## Existing database upgrade path — separate from Baseline

Do not run the fresh-database Baseline over an existing database. Do not replay the incomplete historical chain.

Before any existing database can be upgraded:
1. Obtain a schema/data-safe snapshot or disposable clone representing a **trusted prior version**. Record source commit, database version, registry rows, schema fingerprint, row counts, and non-sensitive integrity checks.
2. Design a separate, uniquely versioned, forward-only migration against that known pre-upgrade state. Review destructive operations, data backfills, tenant scope, financial invariants, RLS/policy changes, function privileges, and idempotency.
3. Apply it only to a dedicated staging clone, never production. Capture before/after schema fingerprints and migration registry; verify historical rows are preserved and new behavior is correct.
4. Run two-school isolation tests in both directions, including students, fees, payments, allocations, discounts, payroll, and academic rollover; test duplicate payment/idempotency and reject cross-tenant writes.
5. Export a backup from the upgraded test database, restore it into a **separate empty disposable database**, then compare required data counts/integrity and schema behavior. A transaction rollback test is not a substitute for a full export-and-restore rehearsal.
6. Simulate recovery on a disposable copy. Prefer restore-to-new-database and controlled cutover over an improvised reverse SQL migration. Document data-loss boundaries and a measured rollback decision point.
7. Require evidence and reviewer sign-off before a release decision. Only after the rehearsal passes may a separately reviewed production runbook be proposed.

## Migration registry policy

- Never use `migration repair` to paper over missing source history.
- Never use `db push` on production.
- Never modify production's registry or DDL/DML during this work.
- Never treat a Baseline fingerprint as proof that historical migrations are equivalent.
- Do not merge PR #7 or issue a final APK until the historical-source disposition, existing-database upgrade rehearsal, full backup/restore rehearsal, rollback/recovery evidence, and security findings are all approved.

## Current acceptance status

| Gate | Evidence | Status |
|---|---|---|
| New empty database reconstruction | CI 38682346947; staging fingerprint/ACL comparison | Passed for current-state Baseline |
| Synthetic selective upgrade | CI 38682346947; stage 0012 with synthetic rows | Passed, limited scope |
| Tenant/finance/backup acceptance | CI and transaction-wrapped staging smoke tests | Passed for synthetic fixtures |
| Full historical 74-entry replay | Two original sources missing; map incomplete | Blocked |
| Upgrade from trusted prior existing database | No reviewed prior-state clone with a verified forward-only plan | Not proven |
| Full backup export and restore rehearsal | Current evidence is synthetic; no production-like rehearsal | Not proven |
| Recovery/rollback rehearsal | No tested recovery from an existing-version upgrade | Not proven |
| Security disposition | Advisor findings remain open | Blocked |

No production changes are authorized by this plan.