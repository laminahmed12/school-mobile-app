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
    'format','lamin-school-backup-v2','taken_at',now(),'school_filter',v_school,
    'schools',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.schools t WHERE t.id=v_school),
    'profiles',(SELECT coalesce(jsonb_agg(jsonb_build_object('username',t.username,'role',t.role,'active',t.active,'school_id',t.school_id)),'[]') FROM public.profiles t WHERE t.role<>'owner' AND t.school_id=v_school),
    'academic_years',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.academic_years t WHERE t.school_id=v_school),
    'classes',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.classes t WHERE t.school_id=v_school),
    'students',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.students t WHERE t.school_id=v_school),
    'student_parents',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_parents t WHERE t.school_id=v_school),
    'student_fees',(SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM public.student_fees t WHERE t.school_id=v_school),
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
  v_restored jsonb := '{}'::jsonb;
BEGIN
  IF private.my_role() <> 'admin' THEN RAISE EXCEPTION 'يُسمح لمدير المدرسة فقط باستعادة النسخة'; END IF;
  v_school := private.my_school();
  IF v_school IS NULL THEN RAISE EXCEPTION 'المدرسة غير نشطة أو انتهت الفترة التجريبية؛ فعّل المدرسة أولاً'; END IF;
  IF p_backup IS NULL OR jsonb_typeof(p_backup) <> 'object'
     OR p_backup->>'format' <> 'lamin-school-backup-v2'
     OR p_backup->>'school_filter' IS DISTINCT FROM v_school::text THEN
    RAISE EXCEPTION 'النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم';
  END IF;
  FOREACH v_table IN ARRAY ARRAY[
    'academic_years','classes','students','teachers','staff','subjects','class_subjects',
    'student_parents','student_fees','student_opening_balances','student_enrollments',
    'payments','grades','student_results','student_behavior','attendance','staff_payments',
    'payroll_transactions','expenses','backup_registry'
  ] LOOP
    IF jsonb_typeof(p_backup->v_table) IS DISTINCT FROM 'array' THEN CONTINUE; END IF;
    EXECUTE format(
      'INSERT INTO public.%I SELECT incoming.* FROM jsonb_populate_recordset(NULL::public.%I, $1) AS incoming WHERE incoming.school_id = $2 ON CONFLICT DO NOTHING',
      v_table, v_table
    ) USING p_backup->v_table, v_school;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_restored := v_restored || jsonb_build_object(v_table, v_count);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'restored', v_restored,
    'message', 'تم دمج النسخة: أُضيفت السجلات الناقصة وتُركت السجلات المتطابقة دون تغيير.');
END
$function$;
REVOKE ALL ON FUNCTION public.restore_backup(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.restore_backup(jsonb) TO authenticated;