-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

CREATE OR REPLACE FUNCTION public.execute_academic_rollover(p_batch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); b record; i record; v_enrollment uuid; v_balance_id uuid; v_students integer:=0; v_balances integer:=0;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'تنفيذ الترحيل متاح لمدير المدرسة فقط'; end if;
 select * into b from public.rollover_batches where id=p_batch_id and school_id=sid for update;
 if not found then raise exception 'عملية الترحيل غير موجودة'; end if;
 if b.status='completed' then return jsonb_build_object('ok',true,'already_completed',true,'message','تم تنفيذ هذه العملية سابقاً.'); end if;
 if b.status not in ('draft','reviewed','approved') then raise exception 'حالة عملية الترحيل لا تسمح بالتنفيذ'; end if;
 if not exists(select 1 from public.academic_years where id=b.source_academic_year_id and school_id=sid and active=true and coalesce(is_closed,false)=false)
  or not exists(select 1 from public.academic_years where id=b.target_academic_year_id and school_id=sid and active=false and coalesce(is_closed,false)=false)
  then raise exception 'تغيرت حالة إحدى السنتين منذ إعداد المعاينة؛ أعد المراجعة'; end if;
 if exists(select 1 from public.rollover_items where batch_id=p_batch_id and not reviewed) then raise exception 'راجع قرار كل طالب قبل تنفيذ الترحيل'; end if;
 if exists(select 1 from public.rollover_items where batch_id=p_batch_id and decision in ('promote','repeat') and target_class_id is null) then raise exception 'يجب تحديد الصف الهدف لكل طالب ناجح أو راسب قبل التنفيذ'; end if;
 if exists(select 1 from public.rollover_items ri join public.classes c on c.id=ri.target_class_id where ri.batch_id=p_batch_id and ri.decision in ('promote','repeat') and c.school_id<>sid) then raise exception 'يوجد صف هدف خارج المدرسة'; end if;
 if exists(select 1 from public.rollover_items ri join public.classes c on c.id=ri.target_class_id where ri.batch_id=p_batch_id and ri.decision in ('promote','repeat') and c.academic_year_id is not null and c.academic_year_id<>b.target_academic_year_id) then raise exception 'الصف الهدف لا ينتمي للسنة الجديدة'; end if;
 if exists(select 1 from public.student_opening_balances ob join public.rollover_items ri on ri.student_id=ob.student_id where ri.batch_id=p_batch_id and ob.academic_year_id=b.target_academic_year_id and ob.rollover_batch_id is distinct from p_batch_id) then raise exception 'توجد أرصدة افتتاحية مسبقة للسنة الهدف؛ راجعها قبل الترحيل لمنع تكرار الدين'; end if;
 update public.rollover_batches set status='running',approved_at=coalesce(approved_at,now()),approved_by=coalesce(approved_by,auth.uid()),updated_by=auth.uid() where id=p_batch_id;
 for i in select * from public.rollover_items where batch_id=p_batch_id order by student_id loop
  if i.decision in ('promote','repeat') then
   select e.id into v_enrollment from public.student_enrollments e where e.school_id=sid and e.student_id=i.student_id and e.academic_year_id=b.target_academic_year_id;
   if v_enrollment is not null then
    if not exists(select 1 from public.student_enrollments e where e.id=v_enrollment and e.promoted_from_enrollment_id=i.source_enrollment_id) then raise exception 'يوجد تسجيل سابق مختلف للطالب في السنة الهدف'; end if;
   else
    insert into public.student_enrollments(school_id,student_id,academic_year_id,class_id,status,source_student_id,promoted_from_enrollment_id,result_status)
    values(sid,i.student_id,b.target_academic_year_id,i.target_class_id,'active',i.student_id,i.source_enrollment_id,'pending') returning id into v_enrollment;
    v_students:=v_students+1;
   end if;
   update public.students set current_academic_year_id=b.target_academic_year_id,active=true,status='active' where id=i.student_id and school_id=sid;
   update public.rollover_items set target_enrollment_id=v_enrollment where id=i.id;
  elsif i.decision='graduate' then update public.students set active=false,status='graduated' where id=i.student_id and school_id=sid;
  elsif i.decision='transfer' then update public.students set active=false,status='transferred' where id=i.student_id and school_id=sid;
  end if;
 end loop;
 for i in select * from public.rollover_items where batch_id=p_batch_id and source_balance>0 order by student_id loop
  if i.opening_balance_id is not null then continue; end if;
  insert into public.student_opening_balances(school_id,student_id,academic_year_id,source_academic_year_id,rollover_batch_id,amount,note,created_by)
   values(sid,i.student_id,b.target_academic_year_id,b.source_academic_year_id,p_batch_id,i.source_balance,'رصيد مرحّل معتمد من السنة السابقة',auth.uid()) on conflict(student_id,academic_year_id) do nothing;
  select ob.id into v_balance_id from public.student_opening_balances ob where ob.school_id=sid and ob.student_id=i.student_id and ob.academic_year_id=b.target_academic_year_id;
  if v_balance_id is null then raise exception 'تعذر إنشاء الرصيد الافتتاحي'; end if;
  update public.rollover_items set opening_balance_id=v_balance_id where id=i.id; v_balances:=v_balances+1;
 end loop;
 update public.academic_years set active=false,is_closed=true,closed_at=now() where school_id=sid and id<>b.target_academic_year_id;
 update public.academic_years set active=true,is_closed=false,closed_at=null where id=b.target_academic_year_id and school_id=sid;
 update public.rollover_batches set status='completed',completed_at=now(),updated_by=auth.uid(),preview=preview||jsonb_build_object('created_enrollments',v_students,'opening_balances',v_balances) where id=p_batch_id;
 return jsonb_build_object('ok',true,'created_enrollments',v_students,'opening_balances',v_balances,'message','اكتمل الترحيل وتم إقفال السنوات السابقة.');
end
$function$


CREATE OR REPLACE FUNCTION public.export_backup(p_school uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_payload jsonb; v_school uuid;
begin
 v_payload:=public.export_backup_core_v4(p_school);
 v_school:=(v_payload->>'school_filter')::uuid;
 return v_payload || jsonb_build_object(
  'audit_log',(select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at),'[]'::jsonb)
    from public.audit_log a where a.school_id=v_school and a.details->>'restored_from_audit_id' is null),
  'audit_log_school_id',v_school);
end $function$


CREATE OR REPLACE FUNCTION public.export_backup_core_v2(p_school uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_role text := private.my_role();
  v_school uuid;
begin
  if v_role = 'owner' then
    if p_school is null then raise exception 'يجب تحديد المدرسة للنسخ الاحتياطي'; end if;
    v_school := p_school;
  elsif v_role = 'admin' then
    v_school := private.my_school();
    if p_school is not null and p_school <> v_school then raise exception 'غير مصرح'; end if;
  else
    raise exception 'ليست لديك صلاحية لهذا الإجراء';
  end if;

  if v_school is null or not exists(select 1 from public.schools s where s.id=v_school) then
    raise exception 'المدرسة غير موجودة';
  end if;

  return jsonb_build_object(
    'format','lamin-school-backup-v2',
    'taken_at',now(),
    'school_filter',v_school,
    'schools',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.schools t where t.id=v_school),
    'profiles',(select coalesce(jsonb_agg(jsonb_build_object('username',t.username,'role',t.role,'active',t.active,'school_id',t.school_id)),'[]') from public.profiles t where t.role<>'owner' and t.school_id=v_school),
    'academic_years',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.academic_years t where t.school_id=v_school),
    'classes',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.classes t where t.school_id=v_school),
    'fee_schedules',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.fee_schedules t where t.school_id=v_school),
    'discount_rules',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.discount_rules t where t.school_id=v_school),
    'students',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.students t where t.school_id=v_school),
    'student_parents',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_parents t where t.school_id=v_school),
    'student_fees',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_fees t where t.school_id=v_school),
    'student_fee_assessments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_fee_assessments t where t.school_id=v_school),
    'student_discount_awards',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_discount_awards t where t.school_id=v_school),
    'student_opening_balances',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_opening_balances t where t.school_id=v_school),
    'payments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.payments t where t.school_id=v_school),
    'subjects',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.subjects t where t.school_id=v_school),
    'class_subjects',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.class_subjects t where t.school_id=v_school),
    'grades',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.grades t where t.school_id=v_school),
    'student_results',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_results t where t.school_id=v_school),
    'student_behavior',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_behavior t where t.school_id=v_school),
    'attendance',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.attendance t where t.school_id=v_school),
    'teachers',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.teachers t where t.school_id=v_school),
    'staff',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.staff t where t.school_id=v_school),
    'staff_payments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.staff_payments t where t.school_id=v_school),
    'payroll_transactions',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.payroll_transactions t where t.school_id=v_school),
    'expenses',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.expenses t where t.school_id=v_school),
    'school_branding',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.school_branding t where t.school_id=v_school),
    'student_enrollments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.student_enrollments t where t.school_id=v_school),
    'backup_registry',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.backup_registry t where t.school_id=v_school)
  );
end
$function$

