# Lamin blocker follow-up — source discovery and Flutter CI verification

Date: 2026-10-14
Repository: https://github.com/laminahmed12/school-mobile-app
Branch: `fix/lamin-postgres-integration-20261014`

## Decision

**BLOCKED on authoritative migration source.** This follow-up adds only genuinely new checks: a repository-wide connector search for the two exact filenames and a direct check of the currently available local execution paths. The earlier branch/path-history/PR/Actions artifact checks were not repeated. No source files were recovered.

## New checks performed

### GitHub-wide source discovery

Using the connected GitHub search capabilities:
- Exact filename search for `20260924214051_001_core_tables.sql`: no results.
- Exact filename search for `supabase_test_bootstrap.sql`: no results.
- Repository discovery query for the project name/owner: no other repository result.
- Commit search for migration version `20260924214051` scoped to `laminahmed12/school-mobile-app`: no results.

These results mean the connected search did not surface another accessible copy. They do not prove that no private/unindexed fork, local clone, or external archive exists.

### Current execution environment

Inspected `/`, `/mnt/data`, `/tmp`, and conventional workspace paths `/workspace`, `/workspaces`, `/repo`, and `/app`. The conventional workspace paths were absent, and no Git checkout, `.git` directory, SQL file, Git bundle, ZIP/TAR archive was found under the searched local data paths. This was a bounded check of the current execution container only; no user device, developer workstation, unmounted storage, or external backup was accessible.

### Flutter — existing CI evidence re-verified, no redundant format run

Queried the existing successful Actions run `38530449708`. Its `format-and-verify` job reports `completed / success`; the steps for non-mutating formatting verification, Flutter analyze, and Flutter tests all report success. The earlier recorded result remains: 10 tests passed and analyzer reported no issues. This is existing CI evidence, not a new local run. The current execution environment lacks a checked-out project and local Flutter toolchain, so no local Flutter command was run and formatting was not repeated.

Run: https://github.com/laminahmed12/school-mobile-app/actions/runs/38530449708
Tested source SHA recorded in prior evidence: `ddda03211898737aa67c0bada77f0b13b44bb2ea`.

## Historical SQL and migration mapping status

Missing files:
1. `supabase/migrations/20260924214051_001_core_tables.sql`
2. `test/sql/supabase_test_bootstrap.sql`

The repository file `supabase/migration_history_map.csv` and reports provide a **mapping snapshot**, not the original migration SQL or a complete authoritative historical source package.

- Production migration-history entries in the recorded snapshot: 74.
- Repository-only migration candidates: 19.
- Unresolved mapping cases: 93 (P1: 68; P2: 6; R1: 19).
- Mappings resolved by authoritative file/provenance proof: 0.
- Historical files recovered: 0/2.
- Full clean-database migration chain: **NOT RUN**.
- Financial, rollover, tenant-isolation/RLS, and backup/restore integration tests: **NOT VERIFIED**.

The recorded PostgreSQL workflow run `38528466520` remains a failed source/mapping gate, not a full migration execution. Do not rerun that same gate until the missing source or mapping evidence changes.

## Exact materials required to proceed

Provide an accessible upload or a new repository branch containing as many of these as available:

1. **Original full developer checkout** including `.git`, or an original Git bundle/archive. Include relevant branches/tags and recoverable unreachable objects if available.
2. **Original complete SQL migration chain**, particularly `supabase/migrations/20260924214051_001_core_tables.sql`, with provenance and dependency context.
3. **Original test bootstrap** `test/sql/supabase_test_bootstrap.sql`; if irrecoverable, an explicitly approved specification for a new fixture. A new fixture must not be described as the original historical file.
4. **Authoritative source-to-ledger evidence** for all 93 mapping cases: migration version/name, source file, Git commit/blob SHA where available, SHA-256, dependency/order information, and deployment evidence tying the source to applied history.
5. If only a trusted schema dump survives: a schema-only dump containing relevant schemas, tables, constraints, indexes, functions, triggers, RLS/policies, extensions, role assumptions, and `auth`/private dependencies, plus an approved baseline/reconciliation plan. Use this for comparison only; do not infer original migration bytes or historical application from it.

No production secrets or real school/student data are required.

## Work that can proceed without the missing historical source

- Continue independent Flutter fixes only when a concrete defect is observed; preserve the passing formatter/analyzer/test baseline and avoid repeating formatting-only work.
- Review application-side financial/year-rollover logic and source-level regression guards without claiming database integration coverage.
- Review the current schema metadata read-only for comparison, if needed.
- Prepare isolated PostgreSQL test orchestration, but keep the full-chain execution disabled until the authoritative baseline and mapping are reviewed.

## Required sequence once a trusted source is provided

1. Preserve source read-only and record provenance, Git blob/commit IDs, SHA-256, and file inventory.
2. Validate exact version/name identity, dependencies, order, extensions, role assumptions, and consistency with the read-only schema reference.
3. Resolve each mapping only when evidence proves identity/application status; do not delete ledger rows to lower the count.
4. Execute the entire ordered chain on a fresh, isolated, disposable PostgreSQL database.
5. After a clean full-chain pass, run finance, academic-year rollover, tenant-isolation/RLS, backup completeness, and restore tests.
6. Keep changes on a work branch; do not modify production, merge to `main`, or build a final APK before the required gates pass.

## Final status

**Awaiting a trusted source package.** New searches returned no alternative source, and the current execution container has no local clone/archive. No migration was fabricated or run, no production data/schema was changed, no merge to `main` occurred, and no APK was built.