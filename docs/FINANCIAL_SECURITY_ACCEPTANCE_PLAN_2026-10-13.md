# Lamin financial and tenant-isolation acceptance plan

**Created:** 2026-10-13 20:20 Libya time (UTC+02:00)  
**Branch:** `plan/lamin-finance-rollover-hardening`  
**Status:** Static review documented; isolated database execution still required. Do not merge to production until all blocking tests pass.

## Scope and safety boundary

- Production Supabase was queried read-only during this review.
- No production rows were inserted, updated, or deleted.
- No production migration was applied.
- The payment-allocation priority migration in this branch is not deployed.
- Flutter CI is not evidence of SQL transaction correctness.

## Confirmed observations

1. Read-only integrity checks found zero non-positive payments, zero non-positive allocations, zero overallocated payments (by active allocations), zero invalid fee assessment totals/discounts, zero schools with multiple active academic years, zero opening balances missing a same-school academic year, and zero allocations with a missing/mismatched payment.
2. No duplicate non-null `(school_id, idempotency_key)` groups were present in the current production data at inspection time.
3. Supabase security advisor reported 13 authenticated-executable SECURITY DEFINER functions, three RLS-enabled tables with no policies (`license_codes`, `login_attempts`, `owner_gate_attempts`), and leaked-password protection disabled.
4. These observations do not establish safety under concurrent requests, malicious users, or backup restore.

## Blocking test matrix — run only on a disposable Supabase development branch

### Payments and allocations
- [ ] Selected assessment receives payment before opening balances and other assessments.
- [ ] Partial, exact, and excess payments allocate correctly; excess remains unallocated and is visible as credit or is rejected according to product policy.
- [ ] Concurrent requests with the same idempotency key create one payment only.
- [ ] Reusing the same key for a different student/amount is rejected rather than returning an unrelated prior payment.
- [ ] Payment and allocation insertions are atomic: forced allocation failure leaves no partial payment.
- [ ] Cross-school student or assessment IDs are rejected.
- [ ] Allocation sum never exceeds payment amount or fee outstanding amount.
- [ ] Reversal records are auditable and do not erase history.

### Discounts and fee assessment
- [ ] Only permitted roles can approve a discount.
- [ ] Pending discounts do not alter payable balances.
- [ ] Approved discount updates assessment total once; repeated approval is idempotent.
- [ ] Manual discount baseline is preserved through rule changes and restore.
- [ ] Combined discounts cannot exceed assessment total.
- [ ] Cross-school rule/assessment references are rejected.

### Academic rollover
- [ ] Only one active academic year per school after every successful run.
- [ ] Source year is active/open and target year inactive/open before execution.
- [ ] Each student decision is reviewed; target class belongs to the same school and target year.
- [ ] Debts are preserved exactly once; pre-existing target balances block or reconcile safely.
- [ ] Repeating execute after completion does not duplicate enrollments or opening balances.
- [ ] Forced failure rolls back all rollover writes and status transitions.
- [ ] Concurrent rollover attempts for the same batch cannot both create data.

### Backup and restore
- [ ] Backup contains all required academic, financial, payroll, discount, allocation, and audit data.
- [ ] Restore validates schema/version and rejects foreign-school IDs.
- [ ] Restore runs atomically and rolls back on malformed/incomplete payloads.
- [ ] Restore cannot overwrite another school's records.
- [ ] Before/after counts and financial totals reconcile; restored audit copies are not re-exported recursively.
- [ ] Backup access is limited to the owning school and permitted role.

### Tenant isolation and privileged functions
- [ ] Each SECURITY DEFINER function is reviewed for `auth.uid()`, role guard, tenant scope, fixed `search_path`, and least-privilege grants.
- [ ] Owner-only functions reject admin/accountant/teacher accounts.
- [ ] School-bound functions ignore or reject caller-supplied foreign school IDs.
- [ ] RLS-less internal tables have no direct access for `anon` or `authenticated`, unless an explicitly reviewed policy is needed.
- [ ] Cross-school read/write attempts fail for all key financial and academic tables.
- [ ] Enable leaked-password protection in project Auth settings after confirming impact and communicating any login-policy changes.

## Idempotency design requirement

The payment RPC must use a database uniqueness guarantee for non-null `(school_id, idempotency_key)`, plus conflict handling that verifies the existing payment's student, amount, and target assessment match the retry. A pre-insert SELECT alone is not concurrency-safe.

Before adding a unique index, re-check duplicate keys and resolve any duplicates through a reviewed, auditable procedure. Never delete financial rows merely to make the index succeed.

## Release gate

Do not merge the payment migration, change production RLS/function grants, or build a release until:
- all applicable matrix items pass in the isolated development database;
- security advisor findings are triaged, with each intentional exception documented;
- backup restore is demonstrated on disposable data;
- test evidence and commit IDs are recorded here;
- a final Flutter analyze/test run passes.


## Follow-up hardening change (2026-10-13, Libya time UTC+02:00)

- Updated migration `20261013041800_lamin_prioritize_selected_fee_payment.sql` on the review branch to preflight duplicate non-null `(school_id, idempotency_key)` values and create a partial unique index before using `ON CONFLICT`. If duplicates exist, migration aborts without deleting or rewriting financial records.
- This closes the source-level missing-uniqueness prerequisite, but **is not database-tested** and has not been applied to production. Confirm the index definition and migration behavior on a disposable database before merge.
- The migration still does not resolve the excess-payment policy. It can leave part of a recorded payment unallocated after all obligations are satisfied. Treat this as a release blocker until excess is rejected transactionally or a student-credit ledger and statement behavior are implemented and tested.
- No paid Supabase branch was created because recurring branch cost was explicitly declined. Production remains unchanged by this follow-up.


## Free-only validation boundary

Do not create a paid Supabase branch and do not ask the user to approve any paid service. Use GitHub Actions with disposable PostgreSQL and synthetic fixtures, plus local/static validation, as far as the repository schema permits. Do not apply review-branch SQL to production. If a test cannot be run without credentials or a paid resource, document it as blocked and continue with all independent free checks.


## Additional blockers found in read-only function review (2026-10-13)

### Rollover balance calculation — blocking
The current production `prepare_academic_rollover` calculates source debt as opening balances plus fee assessments minus the full sum of payments recorded in the source year. The payment RPC can allocate part of a payment to an older opening balance, so subtracting the whole payment from the source-year debt can understate the amount carried forward.

Required correction before merge:
- Calculate unpaid amounts by each source-year fee assessment and each source-year opening balance using active, non-reversed `payment_allocations`.
- Define a compatibility rule for legacy payments that have no allocations, without counting the same payment both through allocations and through the legacy fallback.
- Test a payment split between a prior-year opening balance and current-year assessment; expected carried balance must reconcile to the outstanding obligations exactly.
- Include graduation/transfer cases in the same reconciliation; preserve any debt according to the product's documented policy.

### Excess payments — blocking product/accounting decision
The payment RPC records the full payment amount, but allocation loops stop when no outstanding obligations remain. The remainder is therefore not assigned to a fee or opening balance. Until a credit/advance ledger and student statement display exist, either reject excess payments transactionally or explicitly implement a customer-credit balance; never silently subtract the full amount from an outstanding balance report.

### Current verification state
These are source-level findings, not changes to production. The relevant SQL tests cannot be honestly marked passed without a disposable database. No paid Supabase branch was created because the cost was declined.


## Further changes on the review branch (2026-10-13, Libya time UTC+02:00)

- Payment RPC now raises an exception if allocation loops leave any amount unallocated. PostgreSQL function exceptions roll back the payment insert and allocation writes in the same transaction. This implements the conservative policy of rejecting payments greater than outstanding debt until a student-credit ledger exists.
- Added `20261013190000_lamin_rollover_balance_from_allocations.sql`, which recalculates the rollover preview balance from opening-balance and fee-assessment obligations less active, non-reversed allocations. A legacy payment with no active allocations is deducted only when explicitly linked to the matching assessment, rather than being subtracted indiscriminately from all source-year debt.
- **Legacy data caveat:** older payments with no allocation and no explicit fee-assessment link cannot be reliably assigned to an obligation by this function. Such cases require an auditable reconciliation policy before rollover; do not assume the revised preview is complete for those records. Existing draft rollover batches also retain their saved preview until a new batch is prepared.
- These are source changes only. They have not been applied to a disposable Supabase branch or production. SQL syntax, transaction rollback, legacy reconciliation, and end-to-end financial totals remain unverified.


## Additional ledger correction (2026-10-13, Libya time UTC+02:00)

- Corrected the legacy-payment fallback in both payment allocation and rollover preview logic: a payment is considered legacy/unallocated only when it has **no allocation rows at all**. A payment with reversed allocations must not be treated as a fresh legacy payment, because that could subtract its amount again and understate debt.
- Updated commits: `c54d376a539911cc0f6f9f95d1be200d7432e5d2` (payment RPC) and `6d9f77081e68a74840eb3e8248c0806bbbb5a858` (rollover preview).
- This is a source-level correction only; PostgreSQL execution and financial reconciliation tests are still required before merge or release.


## Free CI regression harness added (2026-10-13, Libya time UTC+02:00)

- Added `test/sql/run_postgres_migration_tests.sh`, which runs against the disposable PostgreSQL service in GitHub Actions. It checks a split payment across an opening balance and a current-year fee, a genuinely unallocated legacy payment, and a payment with reversed allocation history; it also applies source-level guards to the payment and rollover migrations.
- The workflow now finds and runs this harness automatically. The harness is a regression fixture, **not** a substitute for executing the complete Supabase migrations against a fully provisioned isolated schema. The baseline schema/auth dependencies are not included as a self-contained migration set in this repository.
- Latest branch comparison against `main`: 76 commits ahead, 7 behind, 35 changed files; branch is diverged. Do not merge directly. First reconcile the seven incoming commits and rerun the full free CI suite.
- Current verification is repository/source inspection only. A successful GitHub Actions run has not yet been confirmed from the available workflow-run results; do not describe tests as passed until the actual run is visible.


## Additional issue found during continued review (2026-10-13, Libya time UTC+02:00)

### Existing rollover draft can retain stale balance preview — blocking
The revised `prepare_academic_rollover` returns an existing `draft` or `reviewed` batch before recalculating its items. Therefore, deploying the corrected balance formula does not refresh a draft batch that was created under the old formula, and calling prepare again returns the same stale batch. The earlier statement that a new batch can simply be prepared is not guaranteed by the current RPC behavior.

Required safe correction:
- Do not silently delete or rewrite rollover items that have already been reviewed or may be audit-relevant.
- Add an explicit, authorized refresh/rebuild flow that records the old batch as superseded/cancelled with an audit reason, or otherwise version the preview calculation and block execution of batches created under an older version.
- Test that a stale batch cannot execute without re-review and that refresh never duplicates target enrollments or opening balances.

### Flutter financial summary — ledger reconciliation still required
`SchoolRepository.studentFinancialSummary` currently calculates `remaining` as current fees minus discounts plus opening balances minus the sum of payment amounts for the active year. This does not follow payment allocations and can misstate debt when a payment settles an opening balance, is split across obligations, or has reversed allocation history. It must be reconciled to active allocation rows plus a narrowly defined legacy-payment fallback before release. This requires a dedicated unit/integration test and is not yet changed here.
