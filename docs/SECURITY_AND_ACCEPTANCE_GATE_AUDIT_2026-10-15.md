# Lamīn — Security and acceptance gate audit
Date: 2026-10-15
Branch: `review/lamin-db-schema-baseline-20261015`
Audit source commit: `666f14d5234763c0675d711b3c9b53a748361fc1`

## Decision
**PR #7 is not approved for production merge/deployment.** The fresh-database Baseline and the current CI's synthetic tenant/finance/backup checks pass. Historical existing-database upgrade, full backup export/restore from an upgraded historical fixture, and real upgrade recovery remain unproven. The read-only security review found no reason to add blanket RLS policies to the three tables with zero policies: direct table privileges are currently restricted to `postgres` and `service_role`, not `anon` or `authenticated`. Keep the current access boundary until service/function usage is verified; do not change grants/policies automatically.

## Repository, CI, and production safety
- PR #7: open, not merged. Current branch: `review/lamin-db-schema-baseline-20261015`.
- `main` remains `807da91475cc0f53827acb9940c62ca61c8f64d1`.
- [Baseline acceptance run 38686888475](https://github.com/laminahmed12/school-mobile-app/actions/runs/38686888475): **success**. Job steps passed: disposable DB empty check, Baseline build, schema fingerprint, verified repository deltas, synthetic tenant/finance/backup/restore acceptance, and stage-0012 selective-upgrade with synthetic rows.
- [Flutter/Android candidate run 38686888474](https://github.com/laminahmed12/school-mobile-app/actions/runs/38686888474): **success**. Formatting, static analysis, automated tests, Android candidate APK build, and artifact upload passed. This is a CI candidate artifact, not a final release.
- Read-only migration registry inspection: production `School-Management` still has 74 migration records; `Lamin-Test` has 13 test records (Baseline stages 0001–0012 plus test-only ACL normalization). This count difference is expected for the fresh Baseline test and does not validate production history replay.
- No production DDL/DML, production registry changes, `migration repair`, or `db push` were performed. No production data was copied into staging. No final APK was released.

## RLS tables with zero policies — read-only inspection
Checked in both production and staging:
- `public.license_codes`: columns include `code_hash`, `used_at`, `used_school_id`, `school_id`; RLS enabled; zero policies.
- `public.login_attempts`: columns include `key`, `fails`, `locked_until`, `updated_at`; RLS enabled; zero policies.
- `public.owner_gate_attempts`: columns include `gate_key`, `window_started_at`, `attempts`, `updated_at`; RLS enabled; zero policies.

For each of the three tables, the read-only privilege check returned:
- `anon`: no SELECT/INSERT/UPDATE/DELETE privilege.
- `authenticated`: no SELECT/INSERT/UPDATE/DELETE privilege.
- `service_role`: table privileges present.

All three tables are owned by `postgres`; `FORCE ROW LEVEL SECURITY` is false. Given the lack of direct end-user table grants and the apparent service-side/rate-limit/license purpose, zero policies may be intentional. **No policy was added.** Remaining validation: inspect every application/Edge Function path that accesses these tables, confirm only trusted service-role/server code uses them, and exercise unauthorized direct API access with negative tests. If any end-user path needs direct access, design a narrowly scoped policy only after its threat model and tenant key are established.

## SECURITY DEFINER audit — all 13 advisor findings
Catalog inspection on production and staging showed all 13 functions are owned by `postgres`, grant `EXECUTE` to `authenticated` and `service_role`, and do not grant `EXECUTE` to `anon`. The function ACLs were not modified. Each function was reviewed for owner, grants, search path, and authorization/tenant guard patterns in its definition.

| Function | search_path | Review disposition |
|---|---|---|
| `bootstrap_owner_school(text,text)` | empty | Checks `auth.uid()`, active profile and owner role; creates/binds a school only when profile has no school. Keep callable only if owner onboarding flow is intentional; add negative tests for non-owner, inactive/missing profile, and concurrent bootstrap. |
| `create_next_academic_year(...)` | empty | Uses `private.my_school()` and `private.my_role()`, requires owner/admin and scopes duplicate check/insert by school. The `p_migrate_students` / `p_migrate_staff` parameters appear unused in the inspected definition; confirm intended API contract. |
| `delete_school_user(uuid)` | `public, private` | Requires owner/admin; target lookup and update are scoped to `private.my_school()`, and only accountant/supervisor roles may be deactivated. Harden later to empty search path plus fully qualified object names, with tests before changing implementation. |
| `execute_academic_rollover(uuid)` | empty | Requires owner/admin; locks batch by current school, validates source/target years and target class school/year, reviews each student, and carries opening balances within the school. Keep; require two-school negative tests and duplicate/replay tests before release. |
| `export_backup(uuid)` | empty | Delegates authorization/school selection to `export_backup_core_v4`, then adds audit rows filtered to selected school. Confirm the delegated core remains the sole authorization boundary; test owner/admin/other-role and cross-school arguments. |
| `grant_onedrive_access(uuid,text)` | `public, private` | Requires owner/admin; target must belong to current school, be active, and have accountant/supervisor role. Harden search path after tests; add cross-school and unauthorized-role negative tests. |
| `license_trial_status(uuid)` | empty | Returns status only for owner role or the current school via private helpers. Test arbitrary foreign school IDs and missing/inactive profiles; do not expose unrestricted status. |
| `owner_stats()` | empty | Explicit owner-role guard; returns aggregate student/user counts across schools. Cross-school aggregate access appears intentional for the global owner role; verify product authorization expectations and that ordinary school roles are rejected. |
| `prepare_academic_rollover(uuid,uuid)` | empty | Requires owner/admin, validates both years belong to current school, builds batch/items from school-scoped enrollments and finance, and records source balances. Test foreign-year IDs, mixed-school class references, and finance balance invariants. |
| `record_student_payment(...)` | empty | Requires authenticated user, current school, and owner/admin/accountant role; checks student and fee assessment belong to current school; scopes idempotency and allocations by school/student. Test duplicate idempotency key, foreign student/assessment, allocation sums, and concurrent duplicate calls. |
| `restore_backup(jsonb)` | empty | Requires admin role/current school; validates backup format and exact `school_filter` match; delegates to restore core and scopes audit import. Test malformed payload, foreign school, duplicate restore, and rollback on mid-restore failure. |
| `revoke_onedrive_access(uuid,text)` | `public, private` | Requires owner/admin and same-school target; revokes access and audits action. Harden search path after regression tests; test cross-school and unauthorized role. |
| `update_school_settings(text,text,text)` | empty | Requires admin role and updates only the school returned by `private.my_school()`. Test owner/teacher/accountant denial and that no caller-controlled school ID is accepted. |

### Search-path assessment
For the three routines using `search_path=public, private`, catalog checks confirmed neither `authenticated`, `anon`, nor `service_role` has CREATE privilege on either schema; only `postgres` can create there. This reduces the immediate untrusted-object shadowing risk. Nonetheless, an empty search path with fully qualified relation/function names is the stronger pattern for SECURITY DEFINER routines. Do not make an automatic ACL/search-path rewrite without regression tests, dependency review, and a reviewed migration.

### Security findings still requiring disposition
- Supabase Security Advisor still flags 13 authenticated-executable SECURITY DEFINER functions (the 13 above).
- The three no-policy tables remain flagged as informational; direct grants are service-role-only.
- Existing multiple-permissive-policy and duplicate-index warnings remain to be dispositioned.
- Production Auth leaked-password protection remains disabled according to the latest production advisor result; enablement is an Auth configuration change requiring separate owner approval and verification.
- This was a catalog/code review, not a live adversarial test under each role/JWT. The negative authorization matrix remains to be executed.

## Functional acceptance evidence
[Baseline acceptance run 38686888475](https://github.com/laminahmed12/school-mobile-app/actions/runs/38686888475) passed its synthetic test step covering tenant isolation in both directions, payment idempotency/allocation, cross-tenant payment rejection, and backup/restore. The same workflow passed the synthetic selective stage-0012 upgrade with data preservation.

Limits:
- These are CI tests against disposable Baseline-built schemas and synthetic rows, not a trusted historical production snapshot.
- The backup/restore check is synthetic acceptance; it is not a full database-level export followed by restore into a second empty database with complete schema/data/ACL/registry comparison.
- No live production writes or real production data restore were attempted.
- No rollback of a committed forward migration was attempted. Transaction rollback of synthetic fixtures is not a recovery rehearsal.

## Historical upgrade / backup / recovery gate
No provenance-verified historical pre-upgrade backup or clone was available in the reviewed evidence. The original source files `20260924214051_001_core_tables.sql`, `20260924214123_002_rls_policies_rpcs.sql`, and `test/sql/supabase_test_bootstrap.sql` remain missing. The Baseline remains restricted to **new empty databases only**.

Still untested:
1. Upgrade a trusted prior-version clone with a uniquely versioned forward-only migration.
2. Capture before/after schema fingerprints, grants, policies, function definitions, registry semantics, critical data counts and financial integrity checks.
3. Full backup export from the upgraded clone and restore into a separate empty database.
4. Post-restore comparison and two-school finance/rollover acceptance.
5. Recovery by restoring the pre-upgrade backup into a fresh database, with data-loss and cutover notes.

## Final verdict
- New empty database Baseline: **PASS, limited to fresh-database reconstruction**.
- Synthetic selective upgrade: **PASS, limited to stage 0012 and synthetic rows**.
- Finance/tenant/backup synthetic acceptance: **PASS** in CI.
- Historical existing-database upgrade: **NOT RUN / NOT PROVEN**.
- Full database backup export and separate-target restore: **NOT RUN / NOT PROVEN**.
- Real upgrade rollback/recovery: **NOT RUN / NOT PROVEN**.
- Three RLS tables: direct grants are service-role-only; **do not add blanket policies**; validate call paths and negative API access.
- 13 SECURITY DEFINER functions: owner/grants/search_path and guard patterns inspected; **no automatic ACL changes**; security sign-off and adversarial role/JWT tests remain required.
- Production security configuration: leaked-password protection and advisor findings still need disposition.
- PR #7: **keep open and unmerged**. No production changes, no `migration repair`, no production `db push`, and no final APK release.
