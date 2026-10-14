# Lamīn SECURITY DEFINER review supplement

Date: 2026-10-14
Repository: `laminahmed12/school-mobile-app`
Branch: `fix/lamin-db-recovery-root-cause-20261014`
Scope: read-only inspection of function definitions and ACL metadata in the School-Management Supabase project. No production changes were made.

## Additional definition-level findings

- `private.validate_payroll_transaction()` is a trigger function. It checks `NEW.payee_type`, then requires the referenced teacher or active staff member to belong to `NEW.school_id`. It returns `NEW`. Its `anon` EXECUTE grant does not establish direct API reachability because `anon` has no USAGE on schema `private`; confirm trigger binding and effective caller path before considering any ACL change.
- `public.restore_backup(p_backup)` requires an authenticated school context with role `admin`, checks the backup format `lamin-school-backup-v2`, and requires the payload's `school_filter` to equal the caller's school id before calling the restore core.
- `public.restore_backup_core_v4(p_backup)` extends the previous restore core using a fixed list of tables and filters each inserted row by the current school id. The core is not directly executable by `authenticated` under current ACL metadata; the public wrapper is executable by `authenticated`.
- `private.restore_school_data(p jsonb)` is a legacy SECURITY DEFINER routine. It uses a fixed table-name allowlist and identifier quoting, but its body does not contain an explicit caller/role check. ACL metadata shows it is not executable by `anon`, `authenticated`, or `service_role`. Its call sites and owner-only reachability were not established. Do not grant access to it or use it as a recovery path without further evidence.
- `public.create_next_academic_year` accepts `p_migrate_students` and `p_migrate_staff`, but these parameters are not referenced in the inspected function body. This is a potential contract/implementation mismatch; verify UI/API caller expectations and historical migration source before changing it.
- `public.student_finance` is configured with `security_invoker=true`, but its join to `payments` uses `student_id` only while other reviewed finance views also constrain `school_id`. This is a scope-consistency concern for isolated tests, not a proven cross-tenant exposure.

## Test requirements before closure

1. Test restore wrapper rejection for wrong role, null school, malformed payload, and mismatched `school_filter`.
2. Test hostile/cross-school IDs and rows in backup JSON against an isolated database, including idempotent restore behavior and audit history.
3. Test payroll trigger with teacher/staff IDs from another school and inactive staff.
4. Test the finance view with multiple schools and verify totals against school-scoped source queries.
5. Confirm callers and dependency graph for the legacy private restore routine using trusted source history and catalog evidence.

These findings are preliminary static review only. No grants, RLS policies, schema objects, production data, or migration ledger entries were modified.