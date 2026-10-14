-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

CREATE OR REPLACE FUNCTION public.restore_backup(p_backup jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_school uuid; v_count bigint:=0; v_result jsonb;
begin
 v_school:=private.my_school();
 if private.my_role()<>'admin' or v_school is null then raise exception 'يُسمح لمدير المدرسة فقط باستعادة النسخة'; end if;
 if p_backup is null or jsonb_typeof(p_backup)<>'object' or p_backup->>'format'<>'lamin-school-backup-v2'
   or p_backup->>'school_filter' is distinct from v_school::text then raise exception 'النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم'; end if;

 -- Preload referenced academic years and rollover batches so opening balances with rollover_batch_id can restore safely.
 if jsonb_typeof(p_backup->'academic_years')='array' then
  insert into public.academic_years
  select incoming.* from jsonb_populate_recordset(null::public.academic_years,p_backup->'academic_years') incoming
  where incoming.school_id=v_school on conflict do nothing;
 end if;
 if jsonb_typeof(p_backup->'rollover_batches')='array' then
  insert into public.rollover_batches
  select incoming.* from jsonb_populate_recordset(null::public.rollover_batches,p_backup->'rollover_batches') incoming
  where incoming.school_id=v_school on conflict do nothing;
 end if;

 v_result:=public.restore_backup_core_v4(p_backup);
 if jsonb_typeof(p_backup->'audit_log')='array' and p_backup->>'audit_log_school_id'=v_school::text then
  insert into public.audit_log(school_id,user_id,username,action,entity,entity_id,details,created_at)
  select x.school_id,x.user_id,x.username,x.action,x.entity,x.entity_id,
    coalesce(x.details,'{}'::jsonb)||jsonb_build_object('restored_from_audit_id',x.id),x.created_at
  from jsonb_to_recordset(p_backup->'audit_log') as x(
    id bigint,school_id uuid,user_id uuid,username text,action text,entity text,entity_id text,details jsonb,created_at timestamptz)
  where x.school_id=v_school and not exists(select 1 from public.audit_log a where a.school_id=v_school and a.details->>'restored_from_audit_id'=x.id::text);
  get diagnostics v_count=row_count;
 end if;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb)||jsonb_build_object('audit_log',v_count),true);
end $function$


CREATE OR REPLACE FUNCTION public.restore_backup_core_v2(p_backup jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_school uuid; v_table text; v_count bigint; v_restored jsonb := '{}'::jsonb;
begin
  if private.my_role() <> 'admin' then raise exception 'يُسمح لمدير المدرسة فقط باستعادة النسخة'; end if;
  v_school := private.my_school();
  if v_school is null then raise exception 'المدرسة غير نشطة أو انتهت الفترة التجريبية؛ فعّل المدرسة أولاً'; end if;
  if p_backup is null or jsonb_typeof(p_backup) <> 'object'
     or p_backup->>'format' <> 'lamin-school-backup-v2'
     or p_backup->>'school_filter' is distinct from v_school::text then
    raise exception 'النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم';
  end if;
  foreach v_table in array array[
    'academic_years','classes','students','teachers','staff','subjects','class_subjects',
    'student_parents','student_fees','student_enrollments','student_fee_assessments',
    'student_opening_balances','payments','grades','student_results','student_behavior',
    'attendance','staff_payments','payroll_transactions','expenses','school_branding',
    'backup_registry','fee_schedules','discount_rules','student_discount_awards'
  ] loop
    if jsonb_typeof(p_backup->v_table) is distinct from 'array' then continue; end if;
    execute format(
      'insert into public.%I select incoming.* from jsonb_populate_recordset(null::public.%I, $1) as incoming where incoming.school_id = $2 on conflict do nothing',
      v_table,v_table
    ) using p_backup->v_table,v_school;
    get diagnostics v_count = row_count;
    v_restored := v_restored || jsonb_build_object(v_table,v_count);
  end loop;
  return jsonb_build_object('ok',true,'restored',v_restored,
    'message','تم دمج النسخة: أُضيفت السجلات الناقصة وتُركت السجلات المتطابقة دون تغيير.');
end
$function$


CREATE OR REPLACE FUNCTION public.restore_backup_core_v3(p_backup jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_school uuid; v_count bigint:=0; v_result jsonb;
begin
 v_result:=public.restore_backup_core_v2(p_backup);
 v_school:=private.my_school();
 if jsonb_typeof(p_backup->'payment_allocations')='array' then
  insert into public.payment_allocations
  select incoming.* from jsonb_populate_recordset(null::public.payment_allocations,p_backup->'payment_allocations') incoming
  where incoming.school_id=v_school
  on conflict do nothing;
  get diagnostics v_count=row_count;
 end if;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb) || jsonb_build_object('payment_allocations',v_count),true);
end $function$


CREATE OR REPLACE FUNCTION public.restore_backup_core_v4(p_backup jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_school uuid; v_table text; v_count bigint; v_result jsonb; v_extra jsonb:='{}'::jsonb;
begin
 v_result:=public.restore_backup_core_v3(p_backup);
 v_school:=private.my_school();
 foreach v_table in array array['financial_adjustments','payroll_periods','salary_assignments','rollover_batches','rollover_items'] loop
  if jsonb_typeof(p_backup->v_table) is distinct from 'array' then continue; end if;
  execute format('insert into public.%I select incoming.* from jsonb_populate_recordset(null::public.%I,$1) as incoming where incoming.school_id=$2 on conflict do nothing',v_table,v_table)
    using p_backup->v_table,v_school;
  get diagnostics v_count=row_count;
  v_extra:=v_extra||jsonb_build_object(v_table,v_count);
 end loop;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb)||v_extra,true);
end $function$

