# Lamīn database baseline and migration reconciliation — 2026-10-15

## Scope and safety

- Source project: Supabase project ref `stbrhcgzfxvpayfnnqfl` (`School-Management`), PostgreSQL 17.6.
- Source access: read-only catalog queries. No production DDL/DML was executed and no school, student, user, attendance, or financial rows were exported.
- The baseline is a **new catalog-derived schema candidate**, not a recovery of the missing historical `20260924214051_001_core_tables.sql`.
- Files live under `supabase/baselines/20261015/`, deliberately outside `supabase/migrations/` so the baseline cannot be picked up accidentally by the normal migration runner.
- The only post-baseline changes are the three verified code/policy deltas documented below. No migration-history repair was run.

## Reference catalog captured

| Object class | Production reference |
|---|---:|
| Relations | 43 (40 tables, 3 views) |
| Columns | 402 |
| Constraints | 236 |
| Indexes | 183 |
| Public/private routines | 46 |
| RLS policies | 99 before reconciliation; 102 after the three owner policies |
| User triggers | 32 |
| Expanded privilege entries | 786 |
| PostgreSQL default-privilege entries retained for app-owned `public` schema | 48 |

The fingerprint records schema/object definitions and privilege signatures, not application data. Platform-managed schemas such as `auth`, `storage`, `realtime`, and `graphql` are not copied; the isolated test bootstrap supplies only a minimal `auth.users` / `auth.uid()` compatibility stub and the roles needed by the application schema.

## Baseline files

The ordered baseline is split into stages so dependency order is explicit:

1. `0001_tables_sequences.sql` — schemas, required extensions, sequences, 40 table definitions.
2. `0002_private_routines.sql` through `0009_public_routines_remaining.sql` — catalog-derived routine definitions, with statement terminators.
3. `0010_defaults_constraints_indexes_views.sql` — defaults, primary/unique/check constraints, indexes (including standalone unique indexes referenced by FKs), then foreign keys and views.
4. `0011_security_policies_triggers_grants.sql` — RLS state, all 99 live policies, triggers, schema/object ACLs, exact routine ACL reset/re-grant, and app-owned default privileges.
5. `0012_repo_drift_reconciliation.sql` — only the three source migrations whose current effects were missing or incorrect in the production catalog.

`schema_fingerprint.sql` and `reference_schema_manifest.json` define the metadata-only reference. A high-confidence secret-pattern scan found no credential/token patterns in the generated baseline SQL; no table data inserts are present in stages 0001, 0010, or 0011. Routine bodies are application code and include their ordinary INSERT statements, not copied data.

## Review of all 25 repository migration files

Production has 74 migration-history rows. **None of the 25 repository filenames has an exact version ID in the production history.** This does not mean all 25 effects are missing: most effects are represented by semantically corresponding production history entries under different version IDs and are visible in the current catalog. History names alone are not byte-for-byte proof of source equivalence, so the classifications below describe current-state effects, not exact historical SQL hashes.

| Repository migration | Production history / current-state finding | Classification |
|---|---|---|
| `20261011040000_allow_supervisors_to_read_teachers.sql` | `20261011054843 allow_supervisors_to_read_teachers`; `teachers_select` policy exists | Present |
| `20261011040001_complete_school_backup_and_safe_restore.sql` | `20261011055003 complete_school_backup_and_safe_restore`; export/restore wrappers and v4 chain exist | Present |
| `20261012045500_lamin_finance_foundation.sql` | `20261012025856 lamin_finance_foundation_audit_and_fee_rules`; fee schedules, discount rules/awards, indexes and audit routines exist | Present |
| `20261012050000_lamin_audit_compatibility_and_policy_cleanup.sql` | `20261012030006 lamin_audit_trigger_align_existing_schema` and `20261012030028 lamin_finance_audit_timestamps_and_restore_order`; audit triggers and policy cleanup are represented | Present |
| `20261012050500_lamin_enrollment_fee_and_backup_support.sql` | `20261012025918 lamin_backup_support_finance_foundation` and `20261012030321 lamin_auto_fee_schedule_at_enrollment`; enrollment RPC and backup routines exist | Present |
| `20261012052000_lamin_payment_allocations.sql` | `20261012030408 lamin_payment_allocations_and_amount_guard` and `20261012030421 lamin_backup_include_payment_allocations`; allocation table, guards, policies and indexes exist | Present |
| `20261012054000_lamin_rollover_adjustments_payroll.sql` | `20261012030454 lamin_rollover_adjustments_and_payroll_periods` and `20261012030515 lamin_backup_include_adjustments_rollover_payroll_periods`; rollover/payroll tables exist | Present |
| `20261012055000_lamin_backup_acl_and_audit_history.sql` | `20261012030603 lamin_backup_rpc_execute_restrictions` and `20261012030615 lamin_backup_audit_history_and_rpc_acl`; backup ACL and audit history are represented | Present |
| `20261012060000_lamin_finance_fk_indexes.sql` | `20261012030742 lamin_finance_foreign_key_index_coverage`; all 15 named FK-supporting indexes checked are present | Present |
| `20261012061000_lamin_atomic_payment_recording.sql` | `20261012030944 lamin_atomic_payment_recording_and_allocation`; payment RPC and idempotency behavior exist | Present |
| `20261012062000_lamin_discount_approval.sql` | `20261012031043 lamin_discount_approval_and_assessment_sync` and `20261012031054 lamin_fix_discount_sync_trigger_record_return`; discount routines/policy exist | Present |
| `20261012062100_lamin_preserve_manual_discount_baseline.sql` | `20261012031158 lamin_preserve_manual_discount_baseline`; manual discount preservation is present in the live trigger | Present |
| `20261012062200_lamin_manager_approval_for_manual_discounts.sql` | `20261012031957 lamin_require_approval_for_manual_discount_changes`; approval policy and trigger guard exist | Present |
| `20261012063000_lamin_academic_rollover_rpc.sql` | `20261012031250 lamin_academic_rollover_preview_and_execute`; preview/execute RPCs exist, but later formula/year-closing changes are incomplete | Present, later drift corrected |
| `20261012063100_lamin_rollover_provenance_and_single_active_year.sql` | `20261012031455 lamin_enforce_single_active_year_and_rollover`, `20261012031554 lamin_link_opening_balances_to_rollover_batch`, and `20261012042902 lamin_scope_opening_balance_provenance`; single-active-year index and provenance links exist | Present |
| `20261012063200_lamin_guard_rollover_year_state.sql` | `20261012032249 lamin_guard_rollover_year_state`; state guard exists but does not enforce balance formula version 2 | Partial; updated in stage 0012 |
| `20261012064000_lamin_disable_legacy_rollover_bypasses.sql` | `20261012031751 lamin_disable_unsafe_legacy_rollover_bypasses` and `20261012031804 lamin_disable_legacy_student_promotion_rpc`; old bulk RPC grants are revoked and `create_next_academic_year` only creates an inactive year | Present |
| `20261012064100_lamin_rls_performance_cleanup.sql` | `20261012030109 lamin_finance_rls_and_fk_index_cleanup` and `20261012031908 lamin_rls_performance_cleanup`; relevant policies/indexes exist | Present |
| `20261012064200_lamin_restore_rollover_dependency_order.sql` | `20261012032029 lamin_restore_rollover_dependency_order`; restore preloads rollover batches before dependent records | Present |
| `20261013041800_lamin_prioritize_selected_fee_payment.sql` | Live `record_student_payment` prioritizes the selected fee assessment and retains idempotency; no exact matching history version exists | Effect present; history provenance unresolved |
| `20261013190000_lamin_rollover_balance_from_allocations.sql` | Live `prepare_academic_rollover` does not calculate outstanding debt from `payment_allocations`; guard lacks `balance_formula_version=2` | Missing; included in stage 0012 |
| `20261014030000_allow_owner_teacher_management.sql` | `teachers_owner_insert/update/delete` policies were absent | Missing; included in stage 0012 |
| `20261014050000_fix_academic_rollover_year_closing.sql` | Live execute RPC closes all other non-target years instead of only the source year | Incorrect current effect; corrected in stage 0012 |
| `20261014070000_include_fee_assessments_in_backup.sql` | `export_backup_core_v2` / `restore_backup_core_v2` include fee assessments | Present |
| `20261014080000_complete_financial_backup_restore.sql` | Export/restore version chain covers allocations, adjustments, rollover, payroll, and audit history | Present |

## Automated validation

Workflow: [Lamin schema baseline acceptance](https://github.com/laminahmed12/school-mobile-app/actions/runs/38650309583)

At commit `9c9662c94d28cb8ed18a3400a24501766b7cd409`, GitHub Actions completed successfully with these observed results:

- Clean empty PostgreSQL 17.6 database built from stages 0001–0011.
- The schema-only fingerprint matched the live production reference exactly before reconciliation.
- Only the three documented drift corrections were applied after the comparison.
- Tenant-isolation tests passed for two synthetic schools in both directions.
- Finance tests passed: payment recording, idempotency, allocation total, and cross-tenant payment rejection.
- Backup/restore tests passed for synthetic data; backup payload included fee assessments and payment allocations.
- A separate upgrade-path database matched the reference before patching; pre-existing synthetic school/student rows survived the patch, then the same security/finance/backup test suite passed.

These tests use a disposable PostgreSQL service and a minimal auth stub. They do **not** validate a full Supabase Auth/Storage deployment, nor do they constitute a production backup restore rehearsal. No production data was used in these tests.

## Migration-history compatibility and safe rollout plan

1. Keep this candidate baseline outside the normal migration directory until review. It must not be marked as the historical `20260924214051` migration merely because that history row exists.
2. In a separate staging project/clone, inventory all 74 production history rows and map each to source provenance. Do not add history rows for the 25 repository files solely because their version IDs are absent; several effects are already represented by differently versioned production migrations.
3. Review the one history-only discrepancy (`20261013041800` payment-priority effect) and the three missing/incorrect effects from `20261013190000`, `20261014030000`, and `20261014050000`.
4. After code review, create a new forward-only production migration with a unique version for the three missing/incorrect effects. Test it on staging against a fresh backup, run the schema/tenant/finance/backup/restore suite, and rehearse restoration before any production window.
5. Do not run `migration repair`, edit production migration history, apply the baseline to production, or change production schema as part of this work. Preserve a full recoverable backup and schema-only dump before any later rollout. Prefer a reviewed forward corrective migration over deleting history or rewriting prior migration records.
6. Merge only after review and the full staging/rollback gate. `main` remains untouched; no release APK is part of this task.
