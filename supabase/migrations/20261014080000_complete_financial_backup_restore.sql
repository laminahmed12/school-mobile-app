-- Completes backup/restore coverage for the financial ledger, discount approvals, payroll and rollover provenance.
-- Additive only: no existing production data is modified by this migration itself.
-- Preserve fee assessments in school backups; these rows drive current-term fees and discounts.
-- Existing v2 backups remain compatible: restore_backup skips tables absent from older files.
CREATE OR REPLACE FUNCTION public.export_backup(p_school uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text := private.my_role();
  v_school uuid;
BEGIN
  IF v_role = 'owner' THEN
    IF p_school IS NULL THEN RAISE EXCEPTION 'يجب تحديد المدرسة للنسخ الاحتياطي'; END IF;
    v_school := p_school;
  ELSIF v_role = 'admin' THEN
    v_school := private.my_school();
    IF p_school IS NOT NULL AND p_school <> v_school THEN RAISE EXCEPTION 'غير مصرح'; END IF;
  ELSE
    RAISE EXCEPTION 'ليست لديك صلاحية لهذا الإجراء';
  END IF;
  IF v_school IS NULL OR NOT EXISTS (SELECT 1 FROM public.schools s WHERE s.id = v_school) THEN
    RAISE EXCEPTION 'المدرسة غير موجودة';
  END IF;
  RETURN jsonb_build_object(
    'format','lamin-school-backup-v3','taken_at',now(),'school_filter',v_school,
    'schools',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.schools t WHERE t.id=v_school),
    'profiles',(SELECT coalesce(jsonb_agg(jsonb_build_object('username',t.username,'role',t.role,'active',t.active,'school_id',t.school_id)),'[]') FROM public.profiles t WHERE t.role<>'owner' AND t.school_id=v_school),
    'academic_years',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.academic_years t WHERE t.school_id=v_school),
    'classes',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.classes t WHERE t.school_id=v_school),
    'students',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.students t WHERE t.school_id=v_school),
    'student_parents',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_parents t WHERE t.school_id=v_school),
    'student_fees',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_fees t WHERE t.school_id=v_school),
    'student_fee_assessments',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_fee_assessments t WHERE t.school_id=v_school),
    'fee_schedules',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.fee_schedules t WHERE t.school_id=v_school),
    'discount_rules',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.discount_rules t WHERE t.school_id=v_school),
    'student_discount_awards',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_discount_awards t WHERE t.school_id=v_school),
    'school_branding',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.school_branding t WHERE t.school_id=v_school),
    'payment_allocations',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.payment_allocations t WHERE t.school_id=v_school),
    'financial_adjustments',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.financial_adjustments t WHERE t.school_id=v_school),
    'rollover_batches',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.rollover_batches t WHERE t.school_id=v_school),
    'rollover_items',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.rollover_items t WHERE t.school_id=v_school),
    'payroll_periods',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.payroll_periods t WHERE t.school_id=v_school),
    'salary_assignments',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.salary_assignments t WHERE t.school_id=v_school),
    'audit_log',(SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.created_at),'[]') FROM public.audit_log a WHERE a.school_id=v_school AND a.details->>'restored_from_audit_id' IS NULL),
    'audit_log_school_id',v_school,
    'student_opening_balances',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_opening_balances t WHERE t.school_id=v_school),
    'payments',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.payments t WHERE t.school_id=v_school),
    'subjects',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.subjects t WHERE t.school_id=v_school),
    'class_subjects',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.class_subjects t WHERE t.school_id=v_school),
    'grades',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.grades t WHERE t.school_id=v_school),
    'student_results',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_results t WHERE t.school_id=v_school),
    'student_behavior',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_behavior t WHERE t.school_id=v_school),
    'attendance',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.attendance t WHERE t.school_id=v_school),
    'teachers',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.teachers t WHERE t.school_id=v_school),
    'staff',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.staff t WHERE t.school_id=v_school),
    'staff_payments',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.staff_payments t WHERE t.school_id=v_school),
    'payroll_transactions',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.payroll_transactions t WHERE t.school_id=v_school),
    'expenses',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.expenses t WHERE t.school_id=v_school),
    'student_enrollments',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_enrollments t WHERE t.school_id=v_school),
    'backup_registry',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.backup_registry t WHERE t.school_id=v_school)
  );
END
$function$;

CREATE OR REPLACE FUNCTION public.restore_backup(p_backup jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_school uuid;
  v_table text;
  v_count bigint;
  v_audit_count bigint := 0;
  v_restored jsonb := '{}'::jsonb;
BEGIN
  IF private.my_role() <> 'admin' THEN RAISE EXCEPTION 'يُسمح لمدير المدرسة فقط باستعادة النسخة'; END IF;
  v_school := private.my_school();
  IF v_school IS NULL THEN RAISE EXCEPTION 'المدرسة غير نشطة أو انتهت الفترة التجريبية؛ فعّل المدرسة أولاً'; END IF;
  IF p_backup IS NULL OR jsonb_typeof(p_backup) <> 'object'
     OR (p_backup->>'format' IS DISTINCT FROM 'lamin-school-backup-v2'
         AND p_backup->>'format' IS DISTINCT FROM 'lamin-school-backup-v3')
     OR p_backup->>'school_filter' IS DISTINCT FROM v_school::text THEN
    RAISE EXCEPTION 'النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم';
  END IF;
  -- v3 exports carry a complete table manifest. Reject truncated or malformed v3
  -- payloads before the first insert; legacy v2 backups remain backward-compatible.
  IF p_backup->>'format' = 'lamin-school-backup-v3' THEN
    FOREACH v_table IN ARRAY ARRAY[
      'schools','profiles','academic_years','classes','students','student_parents',
      'student_fees','student_fee_assessments','fee_schedules','discount_rules',
      'student_discount_awards','school_branding','payment_allocations',
      'financial_adjustments','rollover_batches','rollover_items','payroll_periods',
      'salary_assignments','audit_log','student_opening_balances','payments','subjects',
      'class_subjects','grades','student_results','student_behavior','attendance',
      'teachers','staff','staff_payments','payroll_transactions','expenses',
      'student_enrollments','backup_registry'
    ] LOOP
      IF jsonb_typeof(p_backup->v_table) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'النسخة غير مكتملة: الحقل % مفقود أو غير صالح', v_table;
      END IF;
    END LOOP;
    IF p_backup->>'audit_log_school_id' IS DISTINCT FROM v_school::text THEN
      RAISE EXCEPTION 'النسخة غير مكتملة: نطاق سجل التدقيق غير صالح';
    END IF;
  END IF;

  -- Preload parent rows required by opening balances and rollover provenance.
  IF jsonb_typeof(p_backup->'academic_years') = 'array' THEN
    INSERT INTO public.academic_years
    SELECT incoming.* FROM jsonb_populate_recordset(NULL::public.academic_years, p_backup->'academic_years') incoming
    WHERE incoming.school_id = v_school ON CONFLICT DO NOTHING;
  END IF;
  IF jsonb_typeof(p_backup->'rollover_batches') = 'array' THEN
    INSERT INTO public.rollover_batches
    SELECT incoming.* FROM jsonb_populate_recordset(NULL::public.rollover_batches, p_backup->'rollover_batches') incoming
    WHERE incoming.school_id = v_school ON CONFLICT DO NOTHING;
  END IF;

  FOREACH v_table IN ARRAY ARRAY[
    'academic_years','rollover_batches','classes','students','teachers','staff','subjects','class_subjects',
    'student_parents','student_fees','fee_schedules','discount_rules','student_fee_assessments',
    'student_discount_awards','student_opening_balances','student_enrollments','payments','payment_allocations',
    'financial_adjustments','rollover_items','grades','student_results','student_behavior','attendance',
    'staff_payments','payroll_periods','salary_assignments','payroll_transactions','expenses',
    'school_branding','backup_registry'
  ] LOOP
    IF jsonb_typeof(p_backup->v_table) IS DISTINCT FROM 'array' THEN CONTINUE; END IF;
    EXECUTE format(
      'INSERT INTO public.%I SELECT incoming.* FROM jsonb_populate_recordset(NULL::public.%I, $1) AS incoming WHERE incoming.school_id = $2 ON CONFLICT DO NOTHING',
      v_table, v_table
    ) USING p_backup->v_table, v_school;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_restored := v_restored || jsonb_build_object(v_table, v_count);
  END LOOP;
  -- Audit rows are appended with a source marker instead of copying their IDs.
  IF jsonb_typeof(p_backup->'audit_log') = 'array'
     AND p_backup->>'audit_log_school_id' = v_school::text THEN
    INSERT INTO public.audit_log(school_id,user_id,username,action,entity,entity_id,details,created_at)
    SELECT x.school_id,x.user_id,x.username,x.action,x.entity,x.entity_id,
      coalesce(x.details,'{}'::jsonb) || jsonb_build_object('restored_from_audit_id',x.id),x.created_at
    FROM jsonb_to_recordset(p_backup->'audit_log') AS x(
      id bigint,school_id uuid,user_id uuid,username text,action text,entity text,
      entity_id text,details jsonb,created_at timestamptz)
    WHERE x.school_id = v_school
      AND NOT EXISTS (
        SELECT 1 FROM public.audit_log a
        WHERE a.school_id = v_school AND a.details->>'restored_from_audit_id' = x.id::text
      );
    GET DIAGNOSTICS v_audit_count = ROW_COUNT;
    v_restored := v_restored || jsonb_build_object('audit_log',v_audit_count);
  END IF;

  RETURN jsonb_build_object('ok', true, 'restored', v_restored,
    'message', 'تم دمج النسخة المالية والأكاديمية: أُضيفت السجلات الناقصة وحُفظت السجلات المتطابقة.');
END
$function$;
REVOKE ALL ON FUNCTION public.restore_backup(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restore_backup(jsonb) TO authenticated;
