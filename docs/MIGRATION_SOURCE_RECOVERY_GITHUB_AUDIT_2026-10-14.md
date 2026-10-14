# Lamin GitHub-only source recovery audit — expanded pass

Date: 2026-10-14
Repository: https://github.com/laminahmed12/school-mobile-app
Audit branch: `fix/lamin-postgres-integration-20261014`

## Decision

**BLOCKED — neither historical file was recovered.** This pass expanded the access path beyond the prior file-search checks: direct GitHub REST enumeration of all current branch refs, recursive trees for each branch head, direct commit-history queries for both missing paths, tag/release checks, multiple pages of commit history, and broader Actions run/artifact sampling. The Supabase connection was also checked read-only for available projects, migration ledgers, test-project application schemas, and development branches.

No migration file was fabricated; no mapping status was changed; no production writes, schema changes, or migration executions occurred; no merge to `main`; no APK build.

## GitHub refs and commit history actually inspected

### Current branches

Direct GitHub `git/matching-refs/heads/` returned 10 branch refs:

| Branch | Head SHA |
|---|---|
| `main` | `807da91475cc0f53827acb9940c62ca61c8f64d1` |
| `fix/lamin-dart-format-20261014` | `9f619d6d69cf54a179529426aa50829fdbf906c4` |
| `fix/lamin-postgres-integration-20261014` | `220dc4775ecaf185bd609dec8979ee8a7981718a` |
| `build/apk-final` | `38658475e1d292ce71c2eee2c560f81ecfefffc9` |
| `lamin-hardening-20261012` | `c1d223dd078a9ac57f05db7b2c44116b3e69f57a` |
| `plan/lamin-finance-rollover-hardening` | `5bc0ba46eb04eb122d50dd10f00f8b455982c52a` |
| `release/lamin-2.0.0-rc1` | `d8e09bbc2101c7ee03d447d926776d94a4b3ca5d` |
| `release/lamin-2.0.0-rc2` | `0bef5445ae8fd95cd277de06ddf91b0ffd38409f` |
| `release/lamin-2026-school-year` | `d1b9b11dfdf3490c0fd6b442838d605708431d8d` |
| `work/lamin-release-readiness-20261014` | `20a95454038ee64691b99211e3347a071e2dbd5c` |

For each head, a recursive Git tree was fetched and searched for the exact filenames and likely archive/backup names. Neither missing file appeared in any branch tree. Matching backup-related SQL candidates are ordinary current repository files, not copies of either missing file.

Direct GitHub tag refs returned an empty array. GitHub Releases returned an empty array.

### Commit history and deleted-file evidence

Direct path-history queries returned zero commits for each of:
- `supabase/migrations/20260924214051_001_core_tables.sql`
- `test/sql/supabase_test_bootstrap.sql`

The accessible repository commit API returned 211 commit records across its available pages (100 + 100 + 11; subsequent pages were empty). The path-specific queries did not reveal an addition/deletion history for either exact path. Relevant history includes documentation of the missing migration gate, e.g. [commit 35eea415415a158bee017de35689cdf032170259](https://github.com/laminahmed12/school-mobile-app/commit/35eea415415a158bee017de35689cdf032170259), but it is not the original SQL source.

This is evidence about refs and commit history exposed by GitHub's APIs, not proof that all Git objects ever created are available. GitHub's connected API does not expose a complete listing of dangling/unreachable objects, developer reflogs, or arbitrary local object databases. The user has no local clone/archive available, and the current execution environment has no mounted repository or bundle. No such unavailable source was claimed as inspected.

### Actions runs and artifacts

The repository's Actions runs endpoint reports 510 total runs. Available paginated responses in this connection yielded the latest run pages, while later page requests returned empty results despite the total count; therefore I cannot claim that all 510 run records were exhaustively traversed. Artifact lists were checked on 20 selected PostgreSQL/analysis/Flutter runs, including recent runs and older runs from 2026-10-13; every checked run returned an empty artifact list. Examples:
- [38528466520 — PostgreSQL migration gate](https://github.com/laminahmed12/school-mobile-app/actions/runs/38528466520)
- [38482809867 — PostgreSQL migration tests](https://github.com/laminahmed12/school-mobile-app/actions/runs/38482809867)
- [38419883231 — PostgreSQL migration tests](https://github.com/laminahmed12/school-mobile-app/actions/runs/38419883231)
- [38530449708 — Flutter format/analyze/test](https://github.com/laminahmed12/school-mobile-app/actions/runs/38530449708)

The sampled Actions runs provided no recoverable artifact. The available connection did not provide an artifact archive containing either missing file.

## The 93-row migration map

Fetched `supabase/migration_history_map.csv` directly from the work branch. Blob SHA: `facaf56b1d381b33cab312588aeaa07657b7c265`. The file has 93 data rows, all still `unresolved`:

- 74 production ledger rows.
- 68 P1 rows without a repository source candidate.
- 6 P2 rows with similar names but different versions; equivalence remains unproven.
- 19 R1 repository-only candidates not represented by exact version/name in the recorded production snapshot.
- Authoritatively resolved rows: 0/93.

The six P2 candidate blobs already recorded in the previous audit are not historical identity proof. A candidate SQL file can be read and tested as a candidate, but its filename or similarity cannot establish that it is the SQL originally applied. The map has not been edited.

Map: https://github.com/laminahmed12/school-mobile-app/blob/fix/lamin-postgres-integration-20261014/supabase/migration_history_map.csv

## Supabase: backup/schema source availability

The connected Supabase account exposes:
- `School-Management`, project ref `stbrhcgzfxvpayfnnqfl`, status `ACTIVE_HEALTHY`.
- `Lamin-Test`, project ref `iijngozcfzskhvxrmlwi`, status `ACTIVE_HEALTHY`.

Read-only inspection of School-Management previously returned 74 migration ledger entries and current catalog metadata for tables, columns, keys, RLS/policies, and functions. This is a live-schema comparison source, not a canonical schema dump and not the historical SQL bytes.

New read-only inspection of Lamin-Test returned:
- zero application migrations in its migration ledger;
- zero tables in the requested `public` and `private` schemas;
- no Supabase development branches listed for either project.

The test project is a candidate isolated database, but it has not been used to run the chain. The currently connected Supabase tools expose migration/table/extension metadata and SQL execution, but do not expose a backup listing, point-in-time restore inventory, or `pg_dump`/full schema export operation. No backup artifact was found through the available interfaces. Do not invoke a restore or run any migrations on either project as part of this source-recovery audit.

A full, authoritatively restorable schema-only dump is therefore **not currently available as an exported artifact** through the connected tools. Catalog metadata can be used for comparison, but cannot prove historical migration identity or reproduce all role/grant/extension/auth/private behavior by itself.

## Flutter status — current branch versus dedicated repair branch

The dedicated Flutter repair branch has prior successful evidence at tested SHA `ddda03211898737aa67c0bada77f0b13b44bb2ea`: formatting verification passed, `flutter analyze` reported no issues, and 10 tests passed in run [38530449708](https://github.com/laminahmed12/school-mobile-app/actions/runs/38530449708).

The current PostgreSQL work branch was also checked by its automatically triggered analysis workflow [38534182719](https://github.com/laminahmed12/school-mobile-app/actions/runs/38534182719). Results:
- `flutter analyze`: step succeeded; it reported 23 informational/deprecation notices.
- `flutter test`: step succeeded; 26 tests passed.
- non-mutating `dart format --output=none --set-exit-if-changed .`: failed because 24 Dart files would change on this branch.
- No formatter command that modifies files was run during this audit.

This branch-specific formatting failure does not invalidate the separate successful Flutter repair branch. It does mean this PostgreSQL work branch should not be described as passing the formatting gate. The branch divergence needs a deliberate, isolated reconciliation; formatting was not repeated automatically.

## Current test status

| Gate | Result |
|---|---|
| Exact historical files recovered | 0/2 |
| GitHub current branches recursively inspected | 10/10 |
| Exact path commit history | 0 commits for each path |
| GitHub tag refs / releases | empty |
| Actions artifacts sampled | 0 artifacts across 20 checked runs |
| Production mapping cases authoritatively resolved | 0/93 |
| Full clean PostgreSQL migration chain | **NOT RUN** |
| Finance / rollover / RLS tenant isolation / backup-restore integration | **NOT VERIFIED** |
| Flutter dedicated repair branch format/analyze/tests | prior successful evidence |
| Current PostgreSQL branch format gate | failed (24 Dart files would change) |
| Current PostgreSQL branch analyzer | step succeeded; 23 informational notices |
| Current PostgreSQL branch Flutter tests | 26 passed |
| Production writes, merge to main, final APK | none |

## Exact evidence required to continue

No request is made for a local copy the owner does not have. The next recoverable source must come from an accessible GitHub source or an authorized export:
1. A separate accessible fork/repository/branch or commit that contains the original file bytes.
2. An accessible GitHub Actions artifact from an older run containing the source/fixture, or an accessible commit that added/deleted them.
3. If no such source exists, an authorized Supabase schema-only export from the database owner, including application schemas, table definitions, constraints/indexes, functions/triggers, RLS policies/grants, extensions, and `auth`/private dependencies, for comparison only. The original migration history still requires a separately reviewed reconciliation baseline; a schema dump does not reconstruct it automatically.

Until new evidence appears, further repeated GitHub searches against these same refs and path histories are not justified.

## Safe work that remains possible

- Continue static/source-level Flutter work on the dedicated repair branch when a concrete issue is identified; do not repeat formatting-only changes already proven on that branch.
- Inspect candidate SQL files for internal consistency and parser/source-regression issues, without marking historical mappings resolved.
- Continue read-only schema/catalog comparisons against School-Management.
- Keep preparing tests and fixtures on a disposable PostgreSQL instance, but do not run the full chain until the baseline source and mapping are reviewed.

## Final decision

**Source recovery remains blocked.** No file was recovered, no migration status changed, no SQL was executed against either Supabase project, and no production changes, merge to `main`, or final APK build occurred.