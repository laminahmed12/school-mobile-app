# Lamin migration source recovery — execution report

Date: 2026-10-14
Repository: https://github.com/laminahmed12/school-mobile-app
Work branch: `fix/lamin-postgres-integration-20261014`

## Decision

**Historical SQL source recovery remains blocked.** A new, verifiable source was inspected: the connected Supabase project metadata and read-only PostgreSQL catalog metadata. This provides a current-schema comparison reference, but it does not recover the original SQL files or establish historical file identity. No migration case is marked resolved by this report.

No production writes, schema changes, migration runs, merges to `main`, or APK builds were performed.

## New verification performed

### GitHub branch and source search via repository connector

- Enumerated matching branches using the GitHub branch-search connector. The visible results covered `main`, `build/apk-final`, `lamin-hardening-20261012`, `fix/lamin-postgres-integration-20261014`, `plan/lamin-finance-rollover-hardening`, `release/lamin-2.0.0-rc1`, `release/lamin-2.0.0-rc2`, `release/lamin-2026-school-year`, and `work/lamin-release-readiness-20261014`. These are the same accessible branch families already covered in the prior audit; this check is a new API path, not evidence of a complete Git object scan.
- GitHub repository code search was run for the exact migration filename, exact bootstrap filename, the migration version, and related archive/backup/schema terms. It returned no matching source files.
- The GitHub connector does not expose a complete walk of unreachable Git objects, reflogs, local object databases, or arbitrary external bundles. Therefore, dangling/unreferenced objects remain uninspected.

### Supabase source and schema metadata

Read-only project discovery returned a project named `School-Management` (project ref `stbrhcgzfxvpayfnnqfl`) and a project named `Lamin-Test` (project ref `iijngozcfzskhvxrmlwi`).

For `School-Management`:
- `list_migrations` returned 74 application migration entries.
- The ledger includes `20260924214051 / 001_core_tables` and `20260924214123 / 002_rls_policies_rpcs`, matching the earliest unresolved history entries in the repository's mapping file.
- Read-only catalog inspection enumerated 40 tables across the requested `public` and `private` schemas, including columns, primary keys, foreign-key relationships and RLS flags. The read-only catalog query also enumerated public/private function names, signatures, languages, SECURITY DEFINER flags, and policy definitions from `pg_policies`.
- No application table contents were selected. No SQL write statement or migration was executed.
- This is a live database metadata view, not a downloaded schema-only dump or a backup artifact. It is useful as a comparison oracle, not as proof of the historical source bytes.

For `Lamin-Test`:
- `list_migrations` returned zero application migrations.
- The requested `public` and `private` schema inspection returned zero tables.
- It is a candidate empty test project, but the full migration chain was not run because the authoritative source and mapping remain incomplete.

## Historical source checks retained from the previous audit

- Both requested exact paths were queried on the nine accessible branches listed in `docs/MIGRATION_SOURCE_RECOVERY_FOLLOWUP_2026-10-14.md`; all 18 lookups returned NOT_FOUND.
- Prior exact-filename/version commit searches and path-specific history searches returned no source commit.
- Prior PR review covered PRs #1–#5 without locating authoritative copies.
- Prior GitHub Actions artifact listings for runs `38523817692`, `38523817648`, `38522592586`, `38521346902`, and `38522504072` returned zero artifacts.
- Prior release search returned no releases. A tag-ref endpoint attempt returned 404; this is not proof that no local or external tags exist.
- A previous local clone attempt failed due DNS/network resolution. No local `.git`, Git bundle, developer workstation, external archive, CI cache, or independent database backup was available to inspect.

## Remaining gaps and minimum evidence required

### A. `supabase/migrations/20260924214051_001_core_tables.sql`

Required to resolve:
1. Preferred: original Git commit/blob SHA and the commit/repository containing it, with file bytes retrievable; or
2. An author-controlled, trusted migration archive or CI artifact containing the exact file and provenance; and
3. Dependency context sufficient to validate referenced schemas, extensions, roles, functions, and ordering against the full migration chain.

A current schema listing alone cannot establish original file contents, statement order, comments, migration-time behavior, or the exact dependency history.

### B. `test/sql/supabase_test_bootstrap.sql`

Required to resolve:
1. The original file from the developer checkout, trusted archive, or CI artifact; or
2. If the original is irrecoverable, an explicitly author/reviewer-approved replacement fixture derived from the verified schema and documenting required Supabase `auth`/private dependencies, roles, extensions, policies, and test assumptions.

A replacement must be reviewed as a new fixture; it must not be represented as the historical original.

### C. All 93 migration mapping cases

No case is resolved by the new schema metadata alone.

- **P1 (68):** provide the exact historical migration source (or trusted archive/blob SHA) for each production-history entry and evidence tying its version/name to the applied history.
- **P2 (6):** provide source bytes and a reviewed semantic/dependency comparison proving whether each similar-name candidate is equivalent, superseded, or distinct. Similar names are insufficient.
- **R1 (19):** provide deployment/application evidence tying each repository-only migration to a database history entry, or authoritative reconciliation evidence showing it was never applied and how it should be handled. Do not delete history entries to reduce the count.

The categories total 93; none is marked resolved in this report.

## Safe next action

1. Obtain the original full developer checkout (`.git` included) or a Git bundle containing branches, tags and recoverable unreachable objects; alternatively obtain the original migration archive/CI artifact.
2. Preserve file bytes and record SHA-256, Git blob SHA, commit SHA, version/name, provenance, and dependencies.
3. Compare the recovered source with the live schema metadata without modifying the live project.
4. Once the baseline source and mapping are reviewed, run the full chain from an empty database in an isolated PostgreSQL environment (the accessible `Lamin-Test` project is currently empty, but no migrations have been applied to it). Verify schema creation, RLS, financial invariants, academic-year rollover, and backup/restore.
5. Keep all changes on a work branch. Do not merge to `main`, alter production history, or build an APK as part of this recovery task.

## Current status

- Historical files recovered: **0 of 2**
- Migration mapping cases resolved by authoritative source proof: **0 of 93**
- Full clean-database migration chain: **not run**
- Production writes: **none**
- Merge to `main`: **none**
- APK build: **none**
