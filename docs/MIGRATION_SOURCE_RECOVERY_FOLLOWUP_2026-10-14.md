# Lamin historical migration recovery — follow-up audit
Date: 2026-10-14
Repository: https://github.com/laminahmed12/school-mobile-app

## Preserved refs at audit time

- `main`: `807da91475cc0f53827acb9940c62ca61c8f64d1`
- `plan/lamin-finance-rollover-hardening`: `5bc0ba46eb04eb122d50dd10f00f8b455982c52a`
- Work branch examined: `fix/lamin-postgres-integration-20261014`, at `a01a41d6ed379d6885025fd75c7f27de6b86562c` before this follow-up report.
- No branches or commits were deleted or rewritten. No production database was contacted for writes. No merge or APK build was performed.

## Expanded source recovery checks

Requested files:
1. `supabase/migrations/20260924214051_001_core_tables.sql`
2. `test/sql/supabase_test_bootstrap.sql`

Evidence collected:
- Enumerated the nine reachable repository branches listed below and requested both exact paths from each branch via GitHub's repository contents API. All 18 file lookups returned NOT_FOUND.
- Queried GitHub commit search for the exact filenames, the migration version, and related phrases; exact filename/version queries returned no commits.
- Queried GitHub's path-specific commit history for both paths; each returned zero commits.
- Reviewed the available pull request collection: PR #5 is open/draft and PRs #1–#4 are closed; no known PR source was identified in the prior audit of PRs #1–#5.
- Checked GitHub Actions artifact lists for runs 38523817692, 38523817648, 38522592586, 38521346902, and 38522504072. All returned zero artifacts.
- Queried GitHub Releases; no releases were returned.
- GitHub tag-refs request returned 404; this is recorded as an unavailable endpoint/result, not proof that no local tags or external tags exist.
- A prior local clone attempt in the available execution environment failed due DNS/network resolution for github.com. Therefore no local .git object database, reflogs, unreachable objects, Git bundle, developer machine, CI cache/archive outside GitHub Actions artifacts, or external backup was inspected.

Branches directly checked for both paths:
`main`, `plan/lamin-finance-rollover-hardening`, `fix/lamin-postgres-integration-20261014`, `lamin-hardening-20261012`, `release/lamin-2.0.0-rc1`, `release/lamin-2.0.0-rc2`, `release/lamin-2026-school-year`, `build/apk-final`, `work/lamin-release-readiness-20261014`.

## File-level conclusion

| Path | Found? | Last trusted commit/blob | Chain compatibility |
|---|---|---|---|
| `supabase/migrations/20260924214051_001_core_tables.sql` | No, in the accessible refs/history searched | None identified | Cannot be established without original source or a reviewed historical schema baseline |
| `test/sql/supabase_test_bootstrap.sql` | No, in the accessible refs/history searched | None identified | Cannot be established without original fixture or author-approved equivalent derived from actual Supabase dependencies |

Do not recreate either requested file from its name, add an empty placeholder, or map a similar-name SQL file without content-level proof.

## The 93 unresolved migration mapping cases

The detailed 93-row table and candidate blob SHAs remain in:
`docs/MIGRATION_SOURCE_RECOVERY_AUDIT_2026-10-14.md`
(https://github.com/laminahmed12/school-mobile-app/blob/fix/lamin-postgres-integration-20261014/docs/MIGRATION_SOURCE_RECOVERY_AUDIT_2026-10-14.md)

Current classification from that evidence:
- P1: 68 production-history entries with no repository candidate found in the audited refs.
- P2: 6 similar-name candidates whose migration versions differ; equivalence is unproven.
- R1: 19 repository-only candidates not represented by exact version/name in the reviewed 74-row production snapshot.
- Total unresolved: 93.

Interpretation must remain cautious: P1 is an inaccessible/missing source in the audited repository view, not proof that production is wrong. P2 requires content and dependency comparison. R1 is not proof a migration was never applied by another mechanism. Do not delete history rows to reduce the count.

## CI evidence and test status

- PostgreSQL workflow run 38523817692: failed at the mapping/source gate. The full migration chain was not executed. https://github.com/laminahmed12/school-mobile-app/actions/runs/38523817692
- Flutter workflow run 38523817648: failed at strict non-mutating Dart format verification. https://github.com/laminahmed12/school-mobile-app/actions/runs/38523817648
- Earlier PostgreSQL run 38522592586 accepted 25 SQL files in the parser and passed 35 source guards, but intentionally failed the full-chain gate because the baseline migration was missing and 93 mappings remained unresolved. https://github.com/laminahmed12/school-mobile-app/actions/runs/38522592586
- No artifacts were available from the five runs listed above.
- No end-to-end clean-database migration, financial integration, tenant-isolation/RLS, or backup/restore success is claimed.

## Safe independent work and blockers

The existing migration mapping remains fail-closed and the existing audit report is retained. No guessed schema or source file was added. The current blocker is the absence of authoritative historical source and local Git object access, not a demonstrated PostgreSQL runtime error in the full chain (the chain has not yet run).

To resolve, provide one of:
1. Original developer checkout including its full `.git` directory, or a Git bundle made from it (including branches/tags and unreachable objects if recoverable).
2. Trusted original migration archive / CI artifact / author-controlled backup containing both files.
3. If the exact baseline source cannot be recovered, a documented schema-only Supabase/PostgreSQL dump with function, policy, extension, role and `auth`/`private` dependency definitions, plus an explicitly reviewed baseline/reconciliation plan. This is a comparison source, not automatic replacement for historical migration contents.

Once source is available, verify commit/blob identity and dependencies, restore only on an isolated work branch, then run the full chain on a fresh disposable Supabase-compatible PostgreSQL database. Fix only observed errors, recreate the database from empty after each relevant change, and then run the finance, rollover, concurrency, RLS/tenant-isolation, backup/restore and Flutter gates.

## Decision

**BLOCKED — source not recovered; the complete migration chain and required integration tests are not proven.** Continue only safe, independent work. Do not merge to `main`, change production, rewrite Git history, or build a release APK as part of this task.
