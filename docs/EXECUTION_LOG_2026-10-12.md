# Lamin hardening work log — 2026-10-12

## Scope and safety
- Work is isolated on branch `lamin-hardening-20261012`; `main` was not modified.
- No Release APK was built or published.
- No school rows, student rows, or school license states were edited.

## Database hardening applied to Supabase
- Added school-scoped foreign keys for target/source academic years on opening balances.
- Added school-scoped academic-year foreign keys for payments and fee schedules.
- Added school/student-scoped source assessment provenance for opening balances.
- Added school-scoped rollover-batch provenance for opening balances.
- These relationships now use `ON DELETE RESTRICT` to protect historical financial references.
- Preflight mismatch checks returned zero for target/source year, payment year, fee schedule year, source assessment, and rollover batch relationships.
- Post-migration query confirmed all six new constraints exist.
- Audit completeness check returned zero rows with missing `created_at` or `created_by` for payments and discount awards; no duplicate student/year opening balances were found.

## Flutter code change
- `SchoolRepository.addPayment` now calls the existing server-side `record_student_payment` RPC rather than directly inserting into `payments`.
- This routes payments through the database's atomic payment/allocation path and supplies an idempotency key.
- The old unused academic-year lookup was removed from this method.

## Validation
- Added a branch-only validation workflow that resolves dependencies, formats Dart sources in the temporary runner workspace, and runs Flutter static analysis.
- The first validation run failed before static analysis because the repository contains pre-existing Dart formatting differences. The workflow was adjusted to format only in the temporary runner workspace rather than fail on those existing differences.
- Validation of the latest code revision is pending. This is not a Release build.
