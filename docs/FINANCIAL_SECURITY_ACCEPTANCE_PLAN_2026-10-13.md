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

## User intervention required

Creating the disposable Supabase branch requires the organization's billing/cost confirmation through the Supabase connector. No production change should be used as a substitute. If the connector asks for organization ID and cost acknowledgment, request those details before branch creation.


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
