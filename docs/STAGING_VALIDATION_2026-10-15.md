# Lamīn database baseline — staging validation evidence (2026-10-15)

## Decision

**Fresh-schema reconstruction is now verified on a real, separate Supabase test project and in GitHub Actions. Production rollout is not yet approved.** The historical migration source gap and the lack of a true production-history upgrade rehearsal remain open.

## Safety boundaries

- Production project: `School-Management`, ref `stbrhcgzfxvpayfnnqfl`.
- Staging project: `Lamin-Test`, ref `iijngozcfzskhvxrmlwi`, PostgreSQL `17.11`.
- The staging project was confirmed to have zero migrations and zero public tables before the test.
- No production DDL/DML, migration repair, or db push was run. `main` remains `807da91475cc0f53827acb9940c62ca61c8f64d1`; PR #7 remains open and unmerged.
- Staging baseline migrations were applied only to `Lamin-Test`. The staging project now contains 13 test-only migration records: baseline stages 0001–0012 plus an ACL-normalization verification migration applied after the initial ACL mismatch was discovered.

## Evidence: fresh Supabase baseline

The catalog-derived baseline stages 0001–0011 and the selective reconciliation stage 0012 were applied successfully to `Lamin-Test`. All 40 application tables were created, and RLS is enabled on all 40.

The first real-Supabase fingerprint found that the platform's default grants were inherited when tables were created: 333 additional table ACL entries (208 for `anon`, 125 for `authenticated`) compared with the production reference. This difference was not visible in the disposable CI bootstrap, which does not carry Supabase's project defaults.

The baseline stage `0011_security_policies_triggers_grants.sql` was corrected to revoke those two roles' table privileges before replaying the catalog-derived grants. The same correction was applied to `Lamin-Test` as a staging-only verification migration. The subsequent fingerprint reported **786 actual grants vs 786 expected grants, with zero extra and zero missing grants**.

After excluding metadata fields that necessarily differ by environment, the post-reconciliation staging fingerprint matched these reference sections exactly:

| Section | Actual | Reference | Result |
|---|---:|---:|---|
| Relations | 43 | 43 | Match |
| Columns | 402 | 402 | Match |
| Constraints | 236 | 236 | Match |
| Indexes | 183 | 183 | Match |
| Views | 3 | 3 | Match |
| Triggers | 32 | 32 | Match |
| Default privileges | 48 | 48 | Match |
| Grants | 786 | 786 | Match |

Expected, documented post-baseline differences are limited to:
- **RLS policies:** 102 actual vs 99 in the original production reference; the three additions are `teachers_owner_insert`, `teachers_owner_update`, and `teachers_owner_delete`.
- **Routines:** 46 actual and 46 reference; exactly three definitions differ due to stage 0012: `execute_academic_rollover`, `lamin_guard_rollover_year_state`, and `prepare_academic_rollover`.
- PostgreSQL versions differ (`17.11` staging vs `17.6` production), so the version metadata is not compared as an identical field.

## Evidence: functional tests on staging

The existing baseline acceptance script was executed against `Lamin-Test` inside an explicit `BEGIN ... ROLLBACK` transaction. It completed without an error and exercised:
- two synthetic schools with bidirectional tenant-isolation checks;
- payment recording, idempotency, allocation totals, and cross-tenant payment rejection;
- backup export and restore on synthetic records.

A follow-up read confirmed that all test fixtures were rolled back: zero test schools, zero test auth users, zero test students, and zero test payments remained.

This is a staging smoke test, not a production backup/restore rehearsal.

## GitHub Actions

- Dart/Flutter strict validation on the preceding reviewed commit: [run 38664264421](https://github.com/laminahmed12/school-mobile-app/actions/runs/38664264421) — success.
- PostgreSQL baseline acceptance on the preceding reviewed commit: [run 38664269396](https://github.com/laminahmed12/school-mobile-app/actions/runs/38664269396) — success.
- Android candidate build on the preceding reviewed commit: [run 38664269296](https://github.com/laminahmed12/school-mobile-app/actions/runs/38664269296) — success; candidate artifact only, not a final release.
- After the ACL normalization change, fresh baseline CI run [38677804002](https://github.com/laminahmed12/school-mobile-app/actions/runs/38677804002) completed successfully. Other checks for the ACL-fix commit were still running when this document was prepared; they must be checked again against the final documentation commit.

## Security-advisor findings and production comparison

Read-only Supabase advisors were run against both `School-Management` production and `Lamin-Test` staging after the baseline build.

| Finding | Production | Staging | Interpretation |
|---|---:|---:|---|
| `SECURITY DEFINER` functions executable by `authenticated` | 13 warnings | 13 warnings | Pre-existing in the production catalog; each function's authorization checks and intended exposure need security-owner review. |
| RLS-enabled tables without policies | 3 | 3 | Same tables in both: `license_codes`, `login_attempts`, `owner_gate_attempts`. Confirm that service-role-only access is intentional. |
| Multiple permissive policies | 2 warnings | 5 warnings | Three additional staging findings are the expected `teachers_owner_insert/update/delete` policies from stage 0012. Review policy overlap and access semantics. |
| Duplicate index on `audit_log` | 1 warning | 1 warning | Same duplicate-index finding exists in production and staging. |
| Unused indexes | 42 | 70 | Staging has no application workload; do not use this count as evidence to drop indexes. |
| Auth leaked-password protection | 1 warning | Not reported | Production Auth configuration finding, outside the SQL baseline; it still needs separate disposition. |

A successful schema fingerprint does not resolve these security findings. The 13 function grants, three no-policy tables, overlapping policies, duplicate index, and production Auth setting need an explicit review/disposition before release approval.

## Existing-schema upgrade and rollback limits

GitHub Actions builds a second disposable PostgreSQL database from stages 0001–0011, seeds synthetic pre-upgrade rows, applies stage 0012, and verifies the rows and target behavior. This proves that the **selective baseline reconciliation delta** preserves the synthetic fixtures.

It does **not** prove replay of the production's 74 historical migrations, because two earliest source files remain unavailable and the test database is built from the current catalog-derived baseline rather than the original historical chain. It is not a clone of the production history.

No production rollback was attempted. The staging fixture transaction was rolled back successfully. Before a future production forward migration, the remaining gate is a separate production-like staging clone or schema/data-safe rehearsal, using a unique forward-only migration, a verified recoverable backup, before/after migration-list snapshots, and a restore rehearsal. Do not use `migration repair`, `db push`, or rewrite production history.

## Remaining blockers

1. Original source files for `20260924214051_001_core_tables.sql` and `20260924214123_002_rls_policies_rpcs.sql` are still not recovered. The new baseline is a documented current-state reconstruction, not a historical replacement.
2. The exact file `test/sql/supabase_test_bootstrap.sql` is still missing; `supabase/baselines/20261015/test_bootstrap.sql` is a different CI-only stub.
3. The active repository's migration directory still does not represent the full 74-row production history. The 20 archived migration files are pinned by tree commit and blob SHA in `MIGRATION_SOURCE_PROVENANCE_2026-10-15.csv`, but they must not be copied into the active migration directory without a reviewed history mapping.
4. The production-like existing-schema upgrade and restore rehearsal has not been performed.
5. The security-advisor findings above need an explicit disposition.

**Approval decision: not ready for production merge/deployment yet.** Fresh rebuild and baseline-delta tests pass; production history compatibility, production-like upgrade/restore rehearsal, and security review remain open.
