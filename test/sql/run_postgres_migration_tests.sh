#!/usr/bin/env bash
set -euo pipefail

# Free, disposable PostgreSQL regression checks. These fixtures validate ledger
# arithmetic and source guards; they do NOT replace execution of app migrations
# against a fully provisioned Supabase-compatible schema.
psql -v ON_ERROR_STOP=1 <<'SQL'
begin;
create temporary table t_opening_balances(id int primary key, amount numeric(12,2));
create temporary table t_fee_assessments(id int primary key, total_fee numeric(12,2), discount numeric(12,2));
create temporary table t_payments(id int primary key, amount numeric(12,2), fee_assessment_id int, academic_year_id int);
create temporary table t_payment_allocations(payment_id int, opening_balance_id int, fee_assessment_id int, amount numeric(12,2), reversed_at timestamptz);

insert into t_opening_balances values (1,60);
insert into t_fee_assessments values (1,100,0);
-- Payment 1 was split: 20 to prior debt, 30 to this year's assessment.
insert into t_payments values (1,50,null,2);
insert into t_payment_allocations values
  (1,1,null,20,null),
  (1,null,1,30,null);
-- Legacy payment explicitly linked to this assessment, no allocation rows.
insert into t_payments values (2,10,1,2);
-- A payment with a reversed allocation must not be mistaken for a legacy payment.
insert into t_payments values (3,15,1,2);
insert into t_payment_allocations values (3,null,1,15,now());

do $test$
declare opening_due numeric(12,2); fee_due numeric(12,2); total_due numeric(12,2);
begin
 select greatest(ob.amount-coalesce((select sum(pa.amount) from t_payment_allocations pa
   where pa.opening_balance_id=ob.id and pa.reversed_at is null),0),0)
 into opening_due from t_opening_balances ob where ob.id=1;

 select greatest(f.total_fee-f.discount
   -coalesce((select sum(pa.amount) from t_payment_allocations pa
      where pa.fee_assessment_id=f.id and pa.reversed_at is null),0)
   -coalesce((select sum(p.amount) from t_payments p
      where p.fee_assessment_id=f.id and p.academic_year_id=2
      and not exists(select 1 from t_payment_allocations pa where pa.payment_id=p.id)),0),0)
 into fee_due from t_fee_assessments f where f.id=1;

 total_due:=opening_due+fee_due;
 if opening_due<>40 then raise exception 'Opening balance regression: expected 40, got %',opening_due; end if;
 -- 100 fee - 30 active allocation - 10 genuinely unallocated legacy payment.
 -- The reversed 15 payment is not subtracted as a second legacy payment.
 if fee_due<>60 then raise exception 'Fee balance regression: expected 60, got %',fee_due; end if;
 if total_due<>100 then raise exception 'Combined balance regression: expected 100, got %',total_due; end if;
end
$test$;
rollback;
SQL

python3 - <<'PY'
from pathlib import Path

payment = Path("supabase/migrations/20261013041800_lamin_prioritize_selected_fee_payment.sql").read_text(encoding="utf-8")
rollover = Path("supabase/migrations/20261013190000_lamin_rollover_balance_from_allocations.sql").read_text(encoding="utf-8")
repository = Path("lib/repository.dart").read_text(encoding="utf-8")
summary_start = repository.index(" studentFinancialSummary(")
summary_end = repository.index(" saveStudentFeeAssessment(", summary_start)
financial_summary = repository[summary_start:summary_end]
years_start = repository.index(" academicYears()")
classes_start = repository.index(" classes()", years_start)
add_year_start = repository.index(" addAcademicYear(", classes_start)
academic_year_list = repository[years_start:classes_start]
class_list = repository[classes_start:add_year_start]
fees_start = repository.index(" studentFeeAssessments(")
payments_start = repository.index(" studentPayments(", fees_start)
summary_start = repository.index(" studentFinancialSummary(", payments_start)
financial_fees = repository[fees_start:payments_start]
financial_payments = repository[payments_start:summary_start]

checks = {
    "payment idempotency uses conflict-safe insert": "on conflict (school_id,idempotency_key) where idempotency_key is not null do nothing" in payment.lower(),
    "concurrent payments for one student are serialized before insertion": payment.lower().index("perform pg_catalog.pg_advisory_xact_lock") < payment.lower().index("insert into public.payments"),
    "payment retry validates student": "v_existing_student is distinct from p_student_id" in payment,
    "payment retry validates amount": "v_existing_amount is distinct from round(p_amount,2)" in payment,
    "explicit assessment is allocated first": "Explicit target first" in payment,
    "excess payment fails closed": "if v_remaining>0 then" in payment and "لم تُسجّل الدفعة" in payment,
    "legacy fallback requires no allocation rows": payment.count("not exists(select 1 from public.payment_allocations olda where olda.payment_id=oldp.id)") == 2,
    "rollover uses allocation ledger": "where pa.opening_balance_id=ob.id and pa.reversed_at is null" in rollover and "where pa.fee_assessment_id=f.id and pa.reversed_at is null" in rollover,
    "rollover legacy fallback excludes any payment with allocation history": "where pa.payment_id=p.id)" in rollover,
    "old unreviewed rollover previews are superseded, not reused": "status='cancelled'" in rollover and "Superseded by allocation-ledger balance formula v2" in rollover,
    "reviewed rollover previews are not silently replaced": "where batch_id=v_batch and reviewed" in rollover and "أوقفها وراجع قراراتها" in rollover,
    "new rollover preview is versioned": "'balance_formula_version',2" in rollover,
    "execution blocks stale rollover preview versions": "coalesce(NEW.preview->>'balance_formula_version','')<>'2'" in rollover,
    "offline student cache is scoped by school ID": "final cacheKey = 'students_cache_$schoolId';" in repository,
    "offline tenant scope cache is keyed by authenticated user": "school_id_cache_${u.id}" in repository,
    "offline student cache uses only same-user cached tenant scope after profile failure": "prefs.getString('school_id_cache_${user.id}')" in repository,
    "student list does not use tenant cache while signed out": "if (user == null) return [];" in repository,
    "offline student reads fail closed without school scope": "if (schoolId == null || schoolId.isEmpty) return [];" in repository,
    "offline student cache does not read the legacy shared key": "prefs.getString('students_cache')" not in repository,
    "financial summary scopes active academic year to current school": ".eq('school_id', schoolId)" in financial_summary and ".eq('active', true)" in financial_summary,
    "fee assessment query scopes active year to current school": ".eq('school_id', schoolId)" in financial_fees and ".eq('active', true)" in financial_fees,
    "payment query scopes active year to current school": ".eq('school_id', schoolId)" in financial_payments and ".eq('active', true)" in financial_payments,
    "academic year list is scoped to current school": ".eq('school_id', schoolId)" in academic_year_list,
    "class list is scoped to current school": ".eq('school_id', schoolId)" in class_list,
    "student list query explicitly scopes tenant": ".eq('school_id', schoolId)" in repository[repository.index(" Future<List<Student>> students()"):repository.index(" Future<Map<String, dynamic>?> parent(")],
    "fee and payment rows explicitly scope tenant": ".eq('school_id', schoolId)" in financial_fees and ".eq('school_id', schoolId)" in financial_payments,
    "UI sends a stable idempotency key for student payment retries": "idempotencyKey: idempotencyKey" in Path("lib/main.dart").read_text(encoding="utf-8")
        and "_paymentIdempotencyKey(signature, s.id)" in Path("lib/main.dart").read_text(encoding="utf-8"),
}

backup = Path("supabase/migrations/20261014080000_complete_financial_backup_restore.sql").read_text(encoding="utf-8")
backup_view = Path("lib/backup_view.dart").read_text(encoding="utf-8")
rollover_closure = Path("supabase/migrations/20261014050000_fix_academic_rollover_year_closing.sql").read_text(encoding="utf-8")
required_backup_tables = [
    "fee_schedules", "discount_rules", "student_discount_awards", "school_branding",
    "payment_allocations", "financial_adjustments", "rollover_batches", "rollover_items",
    "payroll_periods", "salary_assignments", "audit_log",
]
checks.update({
    "backup export contains all finance, payroll, rollover and audit payloads":
        all("'" + table + "'" in backup for table in required_backup_tables),
    "restore includes finance, payroll and rollover dependency order":
        all("'" + table + "'" in backup for table in required_backup_tables)
        and "Preload parent rows required by opening balances and rollover provenance" in backup,
    "audit restore is school-scoped and idempotent":
        "audit_log_school_id" in backup and "restored_from_audit_id" in backup
        and "WHERE x.school_id = v_school" in backup,
    "new backup exports use the validated v3 payload format":
        "'format','lamin-school-backup-v3'" in backup,
    "restore remains backward-compatible with v2 and accepts v3":
        "p_backup->>'format' IS DISTINCT FROM 'lamin-school-backup-v2'" in backup
        and "p_backup->>'format' IS DISTINCT FROM 'lamin-school-backup-v3'" in backup,
    "incomplete v3 backups are rejected before any restore insert":
        "IF p_backup->>'format' = 'lamin-school-backup-v3' THEN" in backup
        and "jsonb_typeof(p_backup->v_table) IS DISTINCT FROM 'array'" in backup
        and "النسخة غير مكتملة" in backup
        and backup.index("v3 exports carry a complete table manifest")
            < backup.index("Preload parent rows required by opening balances"),
    "backup UI accepts v2 and v3 internal payloads":
        backup_view.count("lamin-school-backup-v3") == 2
        and backup_view.count("lamin-school-backup-v2") == 2,
    "rollover closes only its source year":
        "where school_id = sid and id = b.source_academic_year_id" in rollover_closure
        and "id<>b.target_academic_year_id" not in rollover_closure,
})
failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(("PASS" if passed else "FAIL") + ": " + name)
if failed:
    raise SystemExit("Source regression guards failed: " + "; ".join(failed))
print(f"Passed {len(checks)} source regression guards")
PY
