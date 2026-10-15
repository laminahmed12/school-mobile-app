# Lamīn — Final acceptance gate status (read-only verification)
Date: 2026-10-15
Review branch: `review/lamin-db-schema-baseline-20261015`
Reviewed head before this report: `7ba7282fa19eb87795e277c0b989a72d8d666fe5`

## Decision
**PR #7 remains blocked from merge/deployment; no final APK release.** The missing historical fixture means an existing-database historical upgrade, complete database export/restore, and real recovery rehearsal cannot honestly be marked passed.

## Repository and CI evidence
- [PR #7](https://github.com/laminahmed12/school-mobile-app/pull/7) is open and unmerged; its base `main` SHA remains `807da91475cc0f53827acb9940c62ca61c8f64d1`.
- [Baseline acceptance CI 38687573359](https://github.com/laminahmed12/school-mobile-app/actions/runs/38687573359): **success** on reviewed head `7ba7282...`. The job passed empty disposable database validation, catalog-derived Baseline build, reference fingerprint comparison, stage-0012 synthetic upgrade/data-preservation checks, and tenant/finance/backup-restore acceptance.
- [Flutter/Android candidate CI 38687573381](https://github.com/laminahmed12/school-mobile-app/actions/runs/38687573381): **success** on the same head. Formatting, static analysis, automated tests, candidate APK build, and candidate artifact upload passed. The uploaded artifact is a CI validation candidate, **not a final release**.
- [Candidate artifact record](https://api.github.com/repos/laminahmed12/school-mobile-app/actions/artifacts/11951008984), SHA-256 `aad73b1d853ee208c7b34997a7e963569d1179be17f188bdc98578782414480e`.
- Production registry read: 74 migration records, ending at `20261012191847 allow_optional_teacher_phone`. `Lamin-Test`: 13 Baseline/test-only records. No production migration registry writes were performed.

## Historical backup/source search
- Checked all three required paths on `main`, `fix/lamin-db-recovery-20261014`, and `fix/lamin-db-recovery-root-cause-20261014`; all nine repository path/ref checks returned NOT_FOUND:
  - `supabase/migrations/20260924214051_001_core_tables.sql`
  - `supabase/migrations/20260924214123_002_rls_policies_rpcs.sql`
  - `test/sql/supabase_test_bootstrap.sql`
- Checked the accessible Supabase project inventory and development branches. `School-Management` and `Lamin-Test` are the relevant active projects; neither project exposes a development branch via the connected branch listing. No provenance-verified prior-version snapshot or saved test database was identified in the accessible evidence.
- This does **not** assert that provider-managed backups do not exist; backup storage/history is not exposed by the connected toolset. Any backup proposed as a fixture must be supplied or located with source release/commit, capture timestamp, PostgreSQL version, capture method, checksum, migration-registry snapshot, and schema fingerprint. Use only an authorized masked/synthetic fixture; do not copy sensitive production rows into an unapproved environment.
- Therefore historical upgrade is **not possible to verify yet**. The current production database is not a pre-upgrade fixture, and `Lamin-Test` was created empty from the current-state Baseline.

## Live read-only security checks
Fresh read-only SQL assertions against staging returned all true:
- RLS is enabled on `public.license_codes`, `public.login_attempts`, and `public.owner_gate_attempts`.
- These three tables have zero policies and direct SELECT/INSERT/UPDATE/DELETE privileges are absent for `anon` and `authenticated`; service-role access is present.
- `anon` cannot execute public SECURITY DEFINER routines, and `anon`, `authenticated`, and `service_role` cannot CREATE in `public` or `private`.
- No blanket RLS policies or ACL changes were made. This is a catalog/privilege test, **not** a live PostgREST/JWT negative-access test.
- Current [production Security Advisor findings](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) and staging findings still include 3 RLS-enabled/no-policy informational findings and 13 authenticated-executable SECURITY DEFINER warnings. Production also reports leaked-password protection disabled ([remediation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)).
- The 13 advisor-flagged exposed SECURITY DEFINER routines are owned by `postgres`, executable by `authenticated` and `service_role`, and not by `anon`. Ten use empty `search_path`; three (`delete_school_user`, `grant_onedrive_access`, `revoke_onedrive_access`) use `public, private`. Schema CREATE privileges are restricted, reducing shadowing risk, but those three should be hardened only after dependency review and regression tests.
- Edge Function source review: `auth-login` (JWT verification disabled by design for custom login) uses service-role access for `login_attempts`; `owner-api` (JWT verification disabled) uses service-role access for `owner_gate_attempts` and gates owner actions with a six-digit PIN hash. Verify rate-limit identity only trusts platform-controlled client-IP headers and add safe negative tests. `admin-api` and `onedrive-access` have JWT verification enabled and check the caller's active profile/role in the inspected source.
- No adversarial requests were sent to production endpoints and no Auth settings were changed. A negative authorization matrix using synthetic users in an isolated environment remains outstanding. Staging currently has no deployed Edge Functions, so these API-path tests cannot be claimed as run there.

## Gate results
| Gate | Result |
|---|---|
| Fresh empty database Baseline | **PASS**, only for new empty databases |
| Selective stage-0012 synthetic upgrade and row preservation | **PASS**, narrow CI scope |
| Flutter formatting, static analysis, tests, candidate APK build/upload | **PASS**, CI candidate only |
| Trusted historical existing-database upgrade | **BLOCKED / NOT RUN** |
| Full database export then restore into a different empty database, with complete schema/data/ACL/registry comparison | **NOT RUN / NOT PROVEN** |
| Real recovery from a committed forward migration using verified pre-upgrade backup | **NOT RUN / NOT PROVEN** |
| Direct table privilege and SECURITY DEFINER catalog checks | **PASS** for tested metadata assertions |
| Live negative PostgREST/JWT authorization matrix and security-owner disposition | **NOT RUN / BLOCKED** |

## What rollback can and cannot recover
- Transactional rollback of a synthetic CI fixture proves only that the fixture transaction leaves no rows behind.
- It does not reverse a committed migration or prove a database restore/cutover.
- A verified pre-upgrade backup can restore the captured state to a new database; changes after capture may be lost unless reconciled separately.
- Before production consideration, restore a trusted prior-version fixture to an isolated database, apply a reviewed forward-only migration, compare before/after schema, grants, policies, functions, migration registry and finance/tenant invariants, export a full database backup, restore it to a different empty database, and rehearse restore-to-new-database plus controlled cutover.

## Safety boundary
No production DDL/DML, production migration-history edits, `migration repair`, or production `db push` were performed. `main` was not modified by this work. PR #7 was not merged. No final APK release was created. Keep the Baseline restricted to new empty databases until all blockers are closed.
