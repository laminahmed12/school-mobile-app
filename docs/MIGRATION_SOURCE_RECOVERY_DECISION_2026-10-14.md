# Lamin source-recovery decision and execution boundary

Date: 2026-10-14
Repository: https://github.com/laminahmed12/school-mobile-app
Work branch: `fix/lamin-postgres-integration-20261014`

## Decision

**BLOCKED: authoritative historical SQL source is still unavailable.** This document records the stopping point and the exact handoff required. It does not claim that every Git object or external backup was inspected.

No new migration search was run against the same previously audited GitHub refs, path histories, PRs, releases, or Actions artifacts. Those checks remain documented in the prior audit reports below. No SQL placeholder or guessed replacement was created. No production writes, schema changes, migration executions, history edits, merge to `main`, or APK build occurred.

## New local-environment check performed for this decision

The current execution container was inspected directly:
- Working directory: `/`.
- `/mnt/data`: empty.
- No local `.git` directory, repository checkout, `.bundle`, SQL archive, ZIP, TAR, or TAR.GZ was found in the searched local data path.
- Conventional workspace roots `/workspace`, `/workspaces`, `/repo`, and `/app` were not present/accessible as directories in this environment.

This is a bounded check of the current execution environment only. It does **not** inspect the user's device, a developer workstation, remote disks, unmounted cloud storage, unreachable Git objects in another clone, or external backups.

## Prior checks already exhausted — not repeated

See:
- [Source recovery audit](MIGRATION_SOURCE_RECOVERY_AUDIT_2026-10-14.md)
- [Follow-up audit](MIGRATION_SOURCE_RECOVERY_FOLLOWUP_2026-10-14.md)
- [Execution report](MIGRATION_SOURCE_RECOVERY_EXECUTION_REPORT_2026-10-14.md)

Those reports record the nine reachable GitHub branches/ref families checked for both exact paths; zero path-history commits and no exact-name/version search result; PRs #1–#5; no GitHub Releases returned; a tag-ref request that returned 404 (not proof that no tags exist elsewhere); and zero artifacts in the enumerated Actions runs. They also record the prior clone attempt failing at DNS/network resolution. The connector does not provide complete access to unreachable Git objects, local reflogs, a developer checkout, arbitrary external bundles, or CI caches outside the inspected Actions artifacts.

The Supabase metadata check is read-only and remains useful only as a current-schema comparison reference; it is not the historical SQL source or a backup. The `Lamin-Test` project was empty at the recorded inspection and has not had the migration chain applied.

## Exact missing source and requested handoff

Please provide one trusted source package through an accessible upload or repository branch:

1. **Full original developer checkout** with its `.git` directory, or a Git bundle made from it that includes relevant branches/tags and recoverable unreachable objects; alternatively, an author-controlled original project archive.
2. **Original migration files** with provenance, especially:
   - `supabase/migrations/20260924214051_001_core_tables.sql`
   - the complete migration chain needed to validate dependencies and ordering, not just the baseline file in isolation.
3. **Original PostgreSQL test bootstrap**:
   - `test/sql/supabase_test_bootstrap.sql`, or
   - its approved specification if the original is genuinely irrecoverable. Any replacement must be explicitly reviewed and labeled as a new fixture, not as the historical original.
4. **Authoritative migration-history mapping** tying each applied version/name to source bytes, preferably with Git commit/blob SHA, file SHA-256, provenance, dependencies, and deployment evidence.
5. If only a schema snapshot survives: a trusted schema-only dump including relevant schemas, tables, constraints, indexes, functions, triggers, policies/RLS, extensions, role assumptions, and `auth`/private dependencies, plus a reviewer-approved baseline/reconciliation plan. This is comparison evidence only; it does not automatically reconstruct migration history.

Do not send database passwords, service-role keys, production tokens, or real school/student data. A sanitized schema/source package is sufficient for the next review.

## Migration mapping and test status

- Production-history snapshot: 74 entries.
- Repository-only candidates: 19.
- Unresolved mapping cases: 93 total — P1: 68, P2: 6, R1: 19.
- Resolved by authoritative historical source evidence: 0/93.
- Original historical files recovered: 0/2.
- Full migration chain on an empty isolated PostgreSQL database: **NOT RUN**.
- Financial integration, academic-year rollover, tenant isolation/RLS, and backup/restore integration gates: **NOT VERIFIED**.
- Most recent recorded PostgreSQL gate, run [38528466520](https://github.com/laminahmed12/school-mobile-app/actions/runs/38528466520): PostgreSQL service became ready; SQL parser and 35 source regression guards passed; job stopped at the migration mapping/source gate with 93 unresolved mappings and missing bootstrap. This is not a successful full-chain test.
- Flutter branch evidence recorded separately: commit `ddda03211898737aa67c0bada77f0b13b44bb2ea` passed `dart format --output=none --set-exit-if-changed .`, `flutter analyze` (no issues), and `flutter test` (10 tests). Successful Actions run: [38530449708](https://github.com/laminahmed12/school-mobile-app/actions/runs/38530449708). No local Flutter rerun was possible in this execution container because the project checkout and toolchain are not present.

## Next execution sequence after trusted source arrives

1. Preserve the supplied package read-only; record source, provenance, commit/blob SHA and SHA-256 for each file.
2. Check version/name identity, dependencies, ordering, extensions, role assumptions, and compatibility against the read-only schema metadata.
3. Review the 93 mapping rows; mark a row mapped only when the source and evidence establish identity and application status. Do not delete history entries to reduce the count.
4. Run the entire ordered chain against a fresh, isolated, disposable PostgreSQL database with no production credentials or data.
5. Only after a clean full-chain pass, run financial invariants, school/year rollover, tenant-isolation/RLS, backup completeness, and restore verification.
6. Keep all work on a non-main branch. Do not merge to `main` or build a final APK until the required gates pass.

## Final status

**Awaiting a trusted source package.** No further repeated GitHub search is justified until a new source or a new access path is supplied.