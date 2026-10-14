-- Current-state public routine definitions extracted read-only from Supabase.
-- This file is a schema reference, not a historical migration.
-- Captured 2026-10-14 UTC; no application data included.

-- Function: add_student(p_name text, p_class text, p_phone text, p_fee numeric)
CREATE OR REPLACE FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_school uuid := (select private.my_school()); v_id uuid;
begin
  if (select private.my_role()) is distinct from 'admin' then raise exception 'ليست لديك صلاحية لهذا الإجراء'; end if;
  insert into public.students(school_id, name, class_name, phone)
  values (v_school, btrim(p_name), btrim(p_class), p_phone) returning id into v_id;
  insert into public.student_fees(student_id, school_id, total_fee) values (v_id, v_school, p_fee);
  insert into public.student_behavior(student_id, school_id) values (v_id, v_school);
  return v_id;
end $function$;

-- Function: attendance_summary(p_date date)
CREATE OR REPLACE FUNCTION public.attendance_summary(p_date date DEFAULT CURRENT_DATE)
 RETURNS TABLE(total bigint, present bigint, absent bigint, late bigint, excused bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$ select count(*), count(*) filter(where status='present'), count(*) filter(where status='absent'), count(*) filter(where status='late'), count(*) filter(where status='excused') from public.attendance where school_id=private.my_school() and attendance_date=p_date $function$;

-- Function: bootstrap_owner_school(p_code text, p_name text)
CREATE OR REPLACE FUNCTION public.bootstrap_owner_school(p_code text, p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_role text;
  v_school uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  select p.role into v_role
  from public.profiles p
  where p.user_id = v_user and p.active = true;

  -- IS DISTINCT FROM treats a missing/inactive profile (NULL role) as unauthorized.
  if v_role is distinct from 'owner' then
    raise exception 'owner_only';
  end if;

  select p.school_id into v_school
  from public.profiles p
  where p.user_id = v_user and p.active = true;

  if v_school is not null then
    return v_school;
  end if;

  if p_code is null or trim(p_code) !~ '^[[:alnum:]_ -]{3,40}$' then
    raise exception 'invalid_school_code';
  end if;

  if p_name is null or length(btrim(p_name)) < 3 or length(btrim(p_name)) > 80 then
    raise exception 'invalid_school_name';
  end if;

  insert into public.schools(code, name, currency, country_code, licensed, trial_started_at)
  values (lower(trim(p_code)), trim(p_name), 'LYD', '218', false, now())
  returning id into v_school;

  update public.profiles
  set school_id = v_school
  where user_id = v_user and active = true and role = 'owner' and school_id is null;

  if not found then
    raise exception 'owner_profile_changed';
  end if;

  return v_school;
end;
$function$;

-- Function: carry_forward_open_balances(p_old_year uuid, p_new_year uuid)
CREATE OR REPLACE FUNCTION public.carry_forward_open_balances(p_old_year uuid, p_new_year uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare sid uuid:=private.my_school(); n integer:=0; r record; bal numeric;
begin
  if sid is null or private.my_role() not in ('owner','admin') then raise exception 'غير مصرح'; end if;
  if not exists(select 1 from academic_years where id=p_old_year and school_id=sid) or not exists(select 1 from academic_years where id=p_new_year and school_id=sid) then raise exception 'السنة غير صالحة'; end if;
  for r in select distinct s.id,s.name from students s where s.school_id=sid and s.active loop
    select greatest(coalesce(sum(f.total_fee-f.discount),0)-coalesce((select sum(p.amount) from payments p where p.student_id=r.id and p.school_id=sid and p.academic_year_id=p_old_year),0),0)
      into bal from student_fees f where f.student_id=r.id and f.school_id=sid and f.academic_year_id=p_old_year;
    if bal>0 then
      insert into student_opening_balances(school_id,student_id,academic_year_id,amount)
      values(sid,r.id,p_new_year,bal)
      on conflict(student_id,academic_year_id) do update set amount=excluded.amount;
      n:=n+1;
    end if;
  end loop;
  return n;
end;
$function$;

-- Function: create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean)
CREATE OR REPLACE FUNCTION public.create_next_academic_year(p_name text, p_starts_on date DEFAULT NULL::date, p_ends_on date DEFAULT NULL::date, p_migrate_students boolean DEFAULT true, p_migrate_staff boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); v_id uuid;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'غير مصرح'; end if;
 if length(btrim(coalesce(p_name,'')))<3 or length(btrim(p_name))>60 then raise exception 'اسم السنة الدراسية غير صالح'; end if;
 if p_starts_on is not null and p_ends_on is not null and p_ends_on<p_starts_on then raise exception 'تاريخ نهاية السنة يسبق بدايتها'; end if;
 if exists(select 1 from public.academic_years where school_id=sid and lower(name)=lower(btrim(p_name))) then raise exception 'اسم السنة الدراسية موجود مسبقاً'; end if;
 insert into public.academic_years(school_id,name,starts_on,ends_on,active,is_closed)
 values(sid,btrim(p_name),p_starts_on,p_ends_on,false,false) returning id into v_id;
 return v_id;
end
$function$;

-- Function: create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text)
CREATE OR REPLACE FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text DEFAULT ''::text, p_term_fee numeric DEFAULT 0, p_term text DEFAULT 'الفصل الأول'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_student_id uuid;
  v_school_id uuid := private.my_school();
  v_role text := private.my_role();
  v_year_id uuid;
  v_year_name text;
  v_class_id uuid;
  v_grade_order integer;
  v_term text := coalesce(nullif(btrim(p_term),''),'الفصل الأول');
  v_fee numeric(12,2) := coalesce(p_term_fee,0);
begin
  if auth.uid() is null or v_school_id is null then raise exception 'يجب تسجيل الدخول إلى المدرسة أولاً'; end if;
  if v_role not in ('admin','owner','supervisor') then raise exception 'ليست لديك صلاحية إضافة طالب'; end if;
  if char_length(btrim(coalesce(p_name,''))) < 2 or char_length(btrim(coalesce(p_name,''))) > 120 then raise exception 'اسم الطالب مطلوب'; end if;
  if char_length(btrim(coalesce(p_class_name,''))) < 1 or char_length(btrim(coalesce(p_class_name,''))) > 100 then raise exception 'الصف أو الفصل مطلوب'; end if;
  if v_fee < 0 then raise exception 'رسوم الفصل لا يمكن أن تكون سالبة'; end if;
  if v_fee > 0 and v_role not in ('admin','owner') then raise exception 'تحديد الرسوم متاح لمدير المدرسة فقط'; end if;

  select ay.id, ay.name into v_year_id, v_year_name
  from public.academic_years ay
  where ay.school_id=v_school_id and ay.active=true and coalesce(ay.is_closed,false)=false
  order by ay.starts_on desc nulls last, ay.created_at desc limit 1;

  if v_year_id is not null then
    select c.id,c.grade_order into v_class_id,v_grade_order
    from public.classes c
    where c.school_id=v_school_id and c.name=btrim(p_class_name)
      and (c.academic_year_id is null or c.academic_year_id=v_year_id)
    order by (c.academic_year_id=v_year_id) desc, c.created_at desc limit 1;

    if v_fee=0 and v_grade_order is not null then
      select fs.amount into v_fee
      from public.fee_schedules fs
      where fs.school_id=v_school_id and fs.academic_year_id=v_year_id
        and fs.grade_order=v_grade_order and fs.term=v_term and fs.active=true
      limit 1;
      v_fee:=coalesce(v_fee,0);
    end if;
  end if;

  insert into public.students(school_id,name,class_name,phone)
  values(v_school_id,btrim(p_name),btrim(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g')))
  returning id into v_student_id;

  if v_year_id is not null then
    insert into public.student_enrollments(school_id,student_id,academic_year_id,class_id,status,source_student_id)
    values(v_school_id,v_student_id,v_year_id,v_class_id,'active',v_student_id)
    on conflict(student_id,academic_year_id) do nothing;
    update public.students set current_academic_year_id=v_year_id where id=v_student_id and school_id=v_school_id;
  end if;

  if v_fee>0 then
    insert into public.student_fee_assessments(
      school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,created_by
    ) values(v_school_id,v_student_id,v_year_id,coalesce(v_year_name,'غير محدد'),v_term,v_fee,0,auth.uid());
  end if;

  return v_student_id;
end
$function$;

-- Function: delete_school_user(p_user_id uuid)
CREATE OR REPLACE FUNCTION public.delete_school_user(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare sid uuid:=private.my_school(); urec record;
begin
 if sid is null or private.my_role() not in ('owner','admin') then raise exception 'غير مصرح'; end if;
 select user_id,username,role into urec from profiles where user_id=p_user_id and school_id=sid;
 if not found then raise exception 'المستخدم غير موجود'; end if;
 if urec.role not in ('accountant','supervisor') then raise exception 'لا يمكن حذف هذا النوع من الحسابات'; end if;
 update profiles set active=false,onedrive_access_granted=false,onedrive_permission_id=null,onedrive_revoked_at=now() where user_id=p_user_id and school_id=sid;
 insert into user_deletion_audit(school_id,target_user_id,target_username,target_role) values(sid,urec.user_id,urec.username,urec.role);
 insert into onedrive_access_audit(school_id,target_user_id,target_username,action) values(sid,urec.user_id,urec.username,'auto_revoke');
end;
$function$;

-- Function: execute_academic_rollover(p_batch_id uuid)
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
$function$;

-- Function: export_backup(p_school uuid)
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
end $function$;

-- Function: export_backup_core_v2(p_school uuid)
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
$function$;

-- Function: export_backup_core_v3(p_school uuid)
CREATE OR REPLACE FUNCTION public.export_backup_core_v3(p_school uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_payload jsonb;
begin
 v_payload:=public.export_backup_core_v2(p_school);
 return v_payload || jsonb_build_object(
  'payment_allocations',(select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb) from public.payment_allocations a where a.school_id=(v_payload->>'school_filter')::uuid)
 );
end $function$;

-- Function: export_backup_core_v4(p_school uuid)
CREATE OR REPLACE FUNCTION public.export_backup_core_v4(p_school uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_payload jsonb; v_school uuid;
begin
 v_payload:=public.export_backup_core_v3(p_school);
 v_school:=(v_payload->>'school_filter')::uuid;
 return v_payload || jsonb_build_object(
  'financial_adjustments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.financial_adjustments t where t.school_id=v_school),
  'rollover_batches',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.rollover_batches t where t.school_id=v_school),
  'rollover_items',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.rollover_items t where t.school_id=v_school),
  'payroll_periods',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.payroll_periods t where t.school_id=v_school),
  'salary_assignments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.salary_assignments t where t.school_id=v_school)
 );
end $function$;

-- Function: grant_onedrive_access(p_user_id uuid, p_permission_id text)
CREATE OR REPLACE FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare sid uuid:=private.my_school(); u record;
begin
 if sid is null or private.my_role() not in ('owner','admin') then raise exception 'غير مصرح'; end if;
 select user_id,username,role,active into u from profiles where user_id=p_user_id and school_id=sid;
 if not found then raise exception 'المستخدم غير موجود'; end if;
 if u.role not in ('accountant','supervisor') then raise exception 'صلاحية OneDrive مخصصة للمحاسب والمشرف'; end if;
 if not u.active then raise exception 'الحساب موقوف'; end if;
 update profiles set onedrive_access_granted=true,onedrive_permission_id=nullif(trim(p_permission_id),''),onedrive_granted_at=now(),onedrive_revoked_at=null where user_id=p_user_id and school_id=sid;
 insert into onedrive_access_audit(school_id,target_user_id,target_username,action,permission_id) values(sid,u.user_id,u.username,'grant',nullif(trim(p_permission_id),''));
end;
$function$;

-- Function: import_students(p_rows jsonb)
CREATE OR REPLACE FUNCTION public.import_students(p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_school uuid := (select private.my_school());
  r jsonb; i int := 0; v_ins int := 0; v_skip int := 0; v_id uuid;
  v_name text; v_class text; v_phone text; v_fee numeric;
begin
  if (select private.my_role()) is distinct from 'admin' then raise exception 'ليست لديك صلاحية لهذا الإجراء'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'صيغة البيانات غير صحيحة'; end if;
  if jsonb_array_length(p_rows) > 2000 then raise exception 'الحد الأقصى 2000 طالب في المرة الواحدة'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    i := i + 1;
    v_name := btrim(coalesce(r->>'name', ''));
    v_class := btrim(coalesce(r->>'class', ''));
    v_phone := coalesce(r->>'phone', '');
    begin v_fee := (r->>'fee')::numeric; exception when others then v_fee := null; end;
    if v_name = '' or v_class = '' then raise exception 'السطر %: الاسم والفصل مطلوبان', i; end if;
    if v_phone !~ '^[0-9]{8,15}$' then raise exception 'السطر %: رقم الهاتف غير صحيح', i; end if;
    if v_fee is null or v_fee < 0 then raise exception 'السطر %: الرسوم غير صحيحة', i; end if;
    insert into public.students(school_id, name, class_name, phone)
    values (v_school, v_name, v_class, v_phone)
    on conflict (school_id, lower(name), phone) do nothing returning id into v_id;
    if v_id is null then
      v_skip := v_skip + 1;
    else
      insert into public.student_fees(student_id, school_id, total_fee) values (v_id, v_school, v_fee);
      insert into public.student_behavior(student_id, school_id) values (v_id, v_school);
      v_ins := v_ins + 1;
    end if;
    v_id := null;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'skipped', v_skip);
end $function$;

-- Function: lamin_capture_manual_discount()
CREATE OR REPLACE FUNCTION public.lamin_capture_manual_discount()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_awards numeric(12,2):=0; v_role text:=private.my_role();
begin
 if current_setting('lamin.sync_award_discount',true)='on' then
  if TG_OP='UPDATE' then NEW.manual_discount:=OLD.manual_discount; end if;
 elsif TG_OP='INSERT' then
  NEW.manual_discount:=coalesce(NEW.discount,0);
 elsif NEW.discount is distinct from OLD.discount then
  if v_role not in ('owner','admin') then raise exception 'تعديل الخصم المباشر متاح لمدير المدرسة فقط؛ أرسل طلب خصم للاعتماد'; end if;
  select coalesce(sum(a.amount),0) into v_awards from public.student_discount_awards a
   where a.fee_assessment_id=NEW.id and a.school_id=NEW.school_id and a.status='approved';
  NEW.manual_discount:=greatest(coalesce(NEW.discount,0)-v_awards,0);
 else
  NEW.manual_discount:=OLD.manual_discount;
 end if;
 return NEW;
end
$function$;

-- Function: lamin_guard_rollover_year_state()
CREATE OR REPLACE FUNCTION public.lamin_guard_rollover_year_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if TG_OP='INSERT' or NEW.status='running' then
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.source_academic_year_id and ay.school_id=NEW.school_id and ay.active=true and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة المصدر يجب أن تكون السنة النشطة غير المغلقة';
  end if;
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.target_academic_year_id and ay.school_id=NEW.school_id and ay.active=false and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة الهدف يجب أن تكون سنة غير نشطة وغير مغلقة';
  end if;
 end if;
 return NEW;
end
$function$;

-- Function: lamin_set_updated_at()
CREATE OR REPLACE FUNCTION public.lamin_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  NEW.updated_at := now();
  if NEW.updated_by is null then NEW.updated_by := auth.uid(); end if;
  return NEW;
end
$function$;

-- Function: lamin_sync_award_discount()
CREATE OR REPLACE FUNCTION public.lamin_sync_award_discount()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_assessment uuid; v_school uuid; v_student uuid; v_fee numeric(12,2); v_manual numeric(12,2); v_awards numeric(12,2);
begin
 if TG_OP='DELETE' then v_assessment:=OLD.fee_assessment_id; v_school:=OLD.school_id; v_student:=OLD.student_id;
 else v_assessment:=NEW.fee_assessment_id; v_school:=NEW.school_id; v_student:=NEW.student_id; end if;
 select sfa.total_fee,sfa.manual_discount into v_fee,v_manual from public.student_fee_assessments sfa
  where sfa.id=v_assessment and sfa.school_id=v_school and sfa.student_id=v_student;
 if not found then if TG_OP='DELETE' then return OLD; else return NEW; end if; end if;
 select coalesce(sum(a.amount),0) into v_awards from public.student_discount_awards a
  where a.fee_assessment_id=v_assessment and a.school_id=v_school and a.status='approved';
 perform set_config('lamin.sync_award_discount','on',true);
 update public.student_fee_assessments set discount=least(v_fee,v_manual+v_awards)
  where id=v_assessment and school_id=v_school and student_id=v_student;
 perform set_config('lamin.sync_award_discount','off',true);
 if TG_OP='DELETE' then return OLD; else return NEW; end if;
end
$function$;

-- Function: lamin_validate_discount_award()
CREATE OR REPLACE FUNCTION public.lamin_validate_discount_award()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_fee numeric(12,2); v_manual numeric(12,2); v_existing numeric(12,2); v_rule record; v_existing_rule numeric(12,2);
begin
 if TG_OP='INSERT' and NEW.status<>'pending' then raise exception 'يجب إنشاء الخصم بحالة انتظار الاعتماد'; end if;
 if TG_OP='UPDATE' and NEW.status is distinct from OLD.status and NEW.status in ('approved','rejected','reversed')
    and private.my_role() not in ('owner','admin') then raise exception 'اعتماد الخصومات متاح للمدير فقط'; end if;
 if NEW.status='approved' then
  select sfa.total_fee,sfa.manual_discount into v_fee,v_manual
   from public.student_fee_assessments sfa
   where sfa.id=NEW.fee_assessment_id and sfa.school_id=NEW.school_id and sfa.student_id=NEW.student_id;
  if not found then raise exception 'استحقاق الرسوم غير موجود'; end if;
  select dr.* into v_rule from public.discount_rules dr
   where dr.id=NEW.discount_rule_id and dr.school_id=NEW.school_id;
  if NEW.discount_rule_id is not null and not found then raise exception 'قاعدة الخصم لا تخص المدرسة الحالية'; end if;
  if NEW.discount_rule_id is not null and v_rule.max_amount is not null and NEW.amount>v_rule.max_amount then
   raise exception 'قيمة الخصم تتجاوز الحد المسموح للقاعدة';
  end if;
  select coalesce(sum(a.amount),0) into v_existing from public.student_discount_awards a
   where a.fee_assessment_id=NEW.fee_assessment_id and a.school_id=NEW.school_id and a.status='approved' and a.id<>NEW.id;
  if coalesce(v_rule.stacking_policy,'max_only')='max_only' and v_existing>0 then
   raise exception 'قاعدة الخصم لا تسمح بدمج أكثر من خصم على الاستحقاق';
  end if;
  if v_manual+v_existing+NEW.amount>v_fee then raise exception 'إجمالي الخصومات يتجاوز رسوم الطالب'; end if;
  if NEW.discount_rule_id is not null and v_rule.cap_amount is not null then
   select coalesce(sum(a.amount),0) into v_existing_rule from public.student_discount_awards a
    where a.fee_assessment_id=NEW.fee_assessment_id and a.school_id=NEW.school_id
      and a.discount_rule_id=NEW.discount_rule_id and a.status='approved' and a.id<>NEW.id;
   if v_existing_rule+NEW.amount>v_rule.cap_amount then raise exception 'إجمالي الخصم يتجاوز سقف القاعدة'; end if;
  end if;
  if TG_OP='INSERT' or OLD.status is distinct from NEW.status then
   NEW.approved_by:=auth.uid(); NEW.approved_at:=now();
  end if;
 elsif NEW.status='reversed' and (TG_OP='INSERT' or OLD.status is distinct from NEW.status) then
  NEW.reversed_by:=auth.uid(); NEW.reversed_at:=now();
 end if;
 return NEW;
end
$function$;

-- Function: lamin_validate_payment_allocation()
CREATE OR REPLACE FUNCTION public.lamin_validate_payment_allocation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_payment_amount numeric(12,2); v_allocated numeric(12,2);
begin
 if NEW.reversed_at is not null then return NEW; end if;
 select p.amount into v_payment_amount from public.payments p
  where p.id=NEW.payment_id and p.school_id=NEW.school_id and p.student_id=NEW.student_id for update;
 if v_payment_amount is null then raise exception 'الدفعة غير موجودة ضمن حساب الطالب والمدرسة'; end if;
 select coalesce(sum(a.amount),0) into v_allocated from public.payment_allocations a
  where a.payment_id=NEW.payment_id and a.reversed_at is null and a.id<>NEW.id;
 if v_allocated + NEW.amount > v_payment_amount then raise exception 'مجموع تخصيصات الدفعة يتجاوز مبلغ الدفعة'; end if;
 return NEW;
end
$function$;

-- Function: lamin_write_audit_event()
CREATE OR REPLACE FUNCTION public.lamin_write_audit_event()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_school uuid;
  v_id text;
begin
  if TG_OP = 'DELETE' then
    v_old := to_jsonb(OLD);
    v_row := v_old;
  else
    v_new := to_jsonb(NEW);
    v_row := v_new;
  end if;
  v_school := nullif(v_row->>'school_id','')::uuid;
  v_id := coalesce(v_row->>'id', v_row->>'school_id', 'unknown');
  insert into public.audit_log(school_id, user_id, username, action, entity, entity_id, details, created_at)
  values (
    v_school,
    auth.uid(),
    null,
    TG_OP,
    TG_TABLE_NAME,
    v_id,
    jsonb_build_object('old', v_old, 'new', v_new),
    now()
  );
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end
$function$;

-- Function: license_trial_status(p_school uuid)
CREATE OR REPLACE FUNCTION public.license_trial_status(p_school uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object('licensed',s.licensed,'trial_started_at',s.trial_started_at,'trial_ends_at',case when s.trial_started_at is null then null else s.trial_started_at+interval '1 month' end,'license_activated_at',s.license_activated_at)
  from public.schools s
  where s.id=p_school
    and ((select private.my_role())='owner' or s.id=(select private.my_school()));
$function$;

-- Function: normalize_school_code()
CREATE OR REPLACE FUNCTION public.normalize_school_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.code := lower(trim(new.code));
  if char_length(new.code) < 3 or char_length(new.code) > 40 then raise exception 'رمز المدرسة يجب أن يكون بين 3 و40 حرفاً'; end if;
  return new;
end;
$function$;

-- Function: owner_stats()
CREATE OR REPLACE FUNCTION public.owner_stats()
 RETURNS TABLE(sid uuid, n_students bigint, n_users bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select private.my_role()) is distinct from 'owner' then raise exception 'ليست لديك صلاحية لهذا الإجراء'; end if;
  return query
    select s.id,
           (select count(*) from public.students st where st.school_id = s.id),
           (select count(*) from public.profiles p where p.school_id = s.id)
    from public.schools s;
end $function$;

-- Function: prepare_academic_rollover(p_source_year uuid, p_target_year uuid)
CREATE OR REPLACE FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); v_batch uuid; r record; v_balance numeric(12,2); v_decision text; v_target_class uuid;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'إعداد الترحيل متاح لمدير المدرسة فقط'; end if;
 if p_source_year=p_target_year then raise exception 'يجب اختيار سنتين مختلفتين'; end if;
 if not exists(select 1 from public.academic_years where id=p_source_year and school_id=sid and active=true and coalesce(is_closed,false)=false) then raise exception 'السنة المصدر يجب أن تكون السنة النشطة غير المغلقة'; end if;
 if not exists(select 1 from public.academic_years where id=p_target_year and school_id=sid and active=false and coalesce(is_closed,false)=false) then raise exception 'السنة الهدف يجب أن تكون سنة غير نشطة وغير مغلقة'; end if;
 if exists(select 1 from public.rollover_batches where school_id=sid and source_academic_year_id=p_source_year and target_academic_year_id=p_target_year and status='completed') then raise exception 'تم ترحيل هاتين السنتين سابقاً'; end if;
 select id into v_batch from public.rollover_batches where school_id=sid and source_academic_year_id=p_source_year and target_academic_year_id=p_target_year and status in ('draft','reviewed') order by created_at desc limit 1;
 if v_batch is not null then return v_batch; end if;
 insert into public.rollover_batches(school_id,source_academic_year_id,target_academic_year_id,status,created_by) values(sid,p_source_year,p_target_year,'draft',auth.uid()) returning id into v_batch;
 for r in select e.id enrollment_id,e.student_id,e.class_id,e.result_status,c.grade_order,c.section from public.student_enrollments e left join public.classes c on c.id=e.class_id and c.school_id=sid where e.school_id=sid and e.academic_year_id=p_source_year order by e.created_at,e.student_id loop
  v_decision:=case when r.result_status='passed' then 'promote' when r.result_status='failed' then 'repeat' when r.result_status in ('graduated','graduate') then 'graduate' when r.result_status in ('transferred','transfer') then 'transfer' else 'exclude' end;
  v_target_class:=null;
  if v_decision in ('promote','repeat') and r.grade_order is not null then
   select c2.id into v_target_class from public.classes c2 where c2.school_id=sid and (c2.academic_year_id=p_target_year or c2.academic_year_id is null)
    and c2.grade_order=case when v_decision='promote' then r.grade_order+1 else r.grade_order end and (r.section is null or r.section='' or c2.section=r.section)
    order by (c2.academic_year_id=p_target_year) desc,c2.created_at desc limit 1;
  end if;
  select greatest(coalesce((select sum(ob.amount) from public.student_opening_balances ob where ob.school_id=sid and ob.student_id=r.student_id and ob.academic_year_id=p_source_year),0)
    +coalesce((select sum(f.total_fee-f.discount) from public.student_fee_assessments f where f.school_id=sid and f.student_id=r.student_id and f.academic_year_id=p_source_year),0)
    -coalesce((select sum(p.amount) from public.payments p where p.school_id=sid and p.student_id=r.student_id and p.academic_year_id=p_source_year),0),0) into v_balance;
  insert into public.rollover_items(school_id,batch_id,student_id,source_enrollment_id,decision,source_class_id,target_class_id,source_balance,created_by,reviewed)
   values(sid,v_batch,r.student_id,r.enrollment_id,v_decision,r.class_id,v_target_class,v_balance,auth.uid(),false);
 end loop;
 update public.rollover_batches set preview=jsonb_build_object('student_count',(select count(*) from public.rollover_items where batch_id=v_batch),
  'total_opening_balance',(select coalesce(sum(source_balance),0) from public.rollover_items where batch_id=v_batch),
  'needs_class',(select count(*) from public.rollover_items where batch_id=v_batch and decision in ('promote','repeat') and target_class_id is null),
  'needs_review',(select count(*) from public.rollover_items where batch_id=v_batch and not reviewed)) where id=v_batch;
 return v_batch;
end
$function$;

-- Function: promote_passed_students(p_old_year uuid, p_new_year uuid)
CREATE OR REPLACE FUNCTION public.promote_passed_students(p_old_year uuid, p_new_year uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare sid uuid:=private.my_school(); n integer:=0; r record; target uuid;
begin
  if sid is null or private.my_role() not in ('owner','admin') then raise exception 'غير مصرح'; end if;
  for r in
    select e.id,e.student_id,e.class_id,c.grade_order,c.section
    from student_enrollments e
    left join classes c on c.id=e.class_id
    where e.school_id=sid and e.academic_year_id=p_old_year and e.result_status='passed'
  loop
    target:=null;
    if r.grade_order is not null then
      select c2.id into target from classes c2
      where c2.school_id=sid and c2.academic_year_id=p_new_year and c2.grade_order=r.grade_order+1
        and (r.section is null or r.section='' or c2.section=r.section)
      order by c2.id limit 1;
    end if;
    insert into student_enrollments(school_id,student_id,academic_year_id,class_id,status,source_student_id,promoted_from_enrollment_id,result_status)
    values(sid,r.student_id,p_new_year,target,'active',r.student_id,r.id,'pending')
    on conflict(student_id,academic_year_id) do update set class_id=excluded.class_id,status='active',promoted_from_enrollment_id=r.id;
    update students set current_academic_year_id=p_new_year,status='active',active=true where id=r.student_id and school_id=sid;
    n:=n+1;
  end loop;
  return n;
end;
$function$;

-- Function: record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text)
CREATE OR REPLACE FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text DEFAULT ''::text, p_term text DEFAULT 'غير محدد'::text, p_fee_assessment_id uuid DEFAULT NULL::uuid, p_idempotency_key text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_school uuid:=private.my_school();
 v_role text:=private.my_role();
 v_year uuid;
 v_payment uuid;
 v_term text:=coalesce(nullif(btrim(p_term),''),'غير محدد');
 v_remaining numeric(12,2):=round(coalesce(p_amount,0),2);
 r record;
 v_take numeric(12,2);
begin
 if auth.uid() is null or v_school is null then raise exception 'يجب تسجيل الدخول إلى المدرسة أولاً'; end if;
 if v_role not in ('owner','admin','accountant') then raise exception 'ليست لديك صلاحية تسجيل الدفعات'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'قيمة الدفعة غير صحيحة'; end if;
 if length(coalesce(p_note,''))>200 then raise exception 'الملاحظة طويلة أكثر من اللازم'; end if;
 if not exists(select 1 from public.students s where s.id=p_student_id and s.school_id=v_school) then raise exception 'الطالب غير موجود ضمن المدرسة الحالية'; end if;

 if p_idempotency_key is not null then
  select p.id into v_payment from public.payments p where p.school_id=v_school and p.idempotency_key=p_idempotency_key;
  if v_payment is not null then return v_payment; end if;
 end if;

 select ay.id into v_year from public.academic_years ay
  where ay.school_id=v_school and ay.active=true and coalesce(ay.is_closed,false)=false
  order by ay.starts_on desc nulls last,ay.created_at desc limit 1;

 if p_fee_assessment_id is not null then
  select sfa.term into v_term from public.student_fee_assessments sfa
   where sfa.id=p_fee_assessment_id and sfa.school_id=v_school and sfa.student_id=p_student_id;
  if not found then raise exception 'بند الرسوم المحدد لا يخص هذا الطالب'; end if;
 end if;

 insert into public.payments(school_id,student_id,academic_year_id,fee_assessment_id,term,payment_date,amount,note,created_by,idempotency_key)
 values(v_school,p_student_id,v_year,p_fee_assessment_id,v_term,current_date,round(p_amount,2),btrim(coalesce(p_note,'')),auth.uid(),p_idempotency_key)
 returning id into v_payment;

 -- Settle carried opening balances first, preserving each balance's target year.
 for r in
  select ob.id, greatest(ob.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa
    where pa.opening_balance_id=ob.id and pa.reversed_at is null),0),0) as outstanding
  from public.student_opening_balances ob
  where ob.school_id=v_school and ob.student_id=p_student_id
  order by ob.created_at,ob.id
 loop
  exit when v_remaining<=0;
  if r.outstanding<=0 then continue; end if;
  v_take:=least(v_remaining,r.outstanding);
  insert into public.payment_allocations(school_id,student_id,payment_id,opening_balance_id,amount,created_by)
  values(v_school,p_student_id,v_payment,r.id,v_take,auth.uid());
  v_remaining:=v_remaining-v_take;
 end loop;

 -- Then allocate to student fee assessments. Legacy payments without allocations are counted
 -- when calculating the pre-existing paid amount, preventing a double charge during migration.
 for r in
  select sfa.id,
   greatest(sfa.total_fee-sfa.discount
    -coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.fee_assessment_id=sfa.id and pa.reversed_at is null),0)
    -coalesce((select sum(oldp.amount) from public.payments oldp where oldp.fee_assessment_id=sfa.id and oldp.id<>v_payment
       and not exists(select 1 from public.payment_allocations olda where olda.payment_id=oldp.id and olda.reversed_at is null)),0),0) as outstanding
  from public.student_fee_assessments sfa
  where sfa.school_id=v_school and sfa.student_id=p_student_id
  order by (sfa.id=p_fee_assessment_id) desc, sfa.due_date asc nulls last, sfa.created_at, sfa.id
 loop
  exit when v_remaining<=0;
  if r.outstanding<=0 then continue; end if;
  v_take:=least(v_remaining,r.outstanding);
  insert into public.payment_allocations(school_id,student_id,payment_id,fee_assessment_id,amount,created_by)
  values(v_school,p_student_id,v_payment,r.id,v_take,auth.uid());
  v_remaining:=v_remaining-v_take;
 end loop;

 return v_payment;
end
$function$;

-- Function: redeem_license_code(p_school_id uuid, p_code_hash text)
CREATE OR REPLACE FUNCTION public.redeem_license_code(p_school_id uuid, p_code_hash text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_license public.license_codes%rowtype;
  v_now timestamptz := now();
begin
  if p_school_id is null or p_code_hash is null or length(trim(p_code_hash)) <> 64 then
    return jsonb_build_object('ok', false, 'error', 'INVALID');
  end if;

  select *
    into v_license
    from public.license_codes
   where code_hash = lower(trim(p_code_hash))
     and used_at is null
     and school_id = p_school_id
   for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'INVALID');
  end if;

  update public.license_codes
     set used_at = v_now,
         used_school_id = p_school_id
   where id = v_license.id
     and used_at is null;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'RACE');
  end if;

  update public.schools
     set licensed = true,
         license_activated_at = v_now,
         license_code_id = v_license.id
   where id = p_school_id
     and licensed = false;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'SCHOOL_ALREADY_LICENSED');
  end if;

  return jsonb_build_object('ok', true, 'license_id', v_license.id, 'activated_at', v_now);
end;
$function$;

-- Function: restore_backup(p_backup jsonb)
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
end $function$;

-- Function: restore_backup_core_v2(p_backup jsonb)
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
$function$;

-- Function: restore_backup_core_v3(p_backup jsonb)
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
end $function$;

-- Function: restore_backup_core_v4(p_backup jsonb)
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
end $function$;

-- Function: revoke_onedrive_access(p_user_id uuid, p_action text)
CREATE OR REPLACE FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text DEFAULT 'revoke'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare sid uuid:=private.my_school(); u record; act text;
begin
 if sid is null or private.my_role() not in ('owner','admin') then raise exception 'غير مصرح'; end if;
 select user_id,username,role,onedrive_permission_id into u from profiles where user_id=p_user_id and school_id=sid;
 if not found then raise exception 'المستخدم غير موجود'; end if;
 act:=case when p_action='auto_revoke' then 'auto_revoke' else 'revoke' end;
 update profiles set onedrive_access_granted=false,onedrive_permission_id=null,onedrive_revoked_at=now() where user_id=p_user_id and school_id=sid;
 insert into onedrive_access_audit(school_id,target_user_id,target_username,action,permission_id) values(sid,u.user_id,u.username,act,u.onedrive_permission_id);
end;
$function$;

-- Function: save_attendance_day(p_date date, p_rows jsonb)
CREATE OR REPLACE FUNCTION public.save_attendance_day(p_date date, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_school uuid := (select private.my_school());
  r jsonb; v_status text; v_late int; v_note text; v_sid uuid; v_n int := 0;
begin
  if (select private.my_role()) not in ('admin','supervisor') then raise exception 'ليست لديك صلاحية لهذا الإجراء'; end if;
  if p_date is null then raise exception 'التاريخ مطلوب'; end if;
  if p_date > current_date then raise exception 'لا يمكن تسجيل حضور تاريخ مستقبلي'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'صيغة البيانات غير صحيحة'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    v_sid := (r->>'student_id')::uuid;
    v_status := r->>'status';
    v_late := coalesce((r->>'minutes_late')::int, 0);
    v_note := coalesce(r->>'note', '');
    if v_status not in ('present','absent','late','excused') then raise exception 'حالة حضور غير صحيحة'; end if;
    if not exists (select 1 from public.students where id = v_sid and school_id = v_school) then
      raise exception 'طالب غير موجود في مدرستك';
    end if;
    insert into public.attendance(school_id, student_id, attendance_date, status, minutes_late, note)
    values (v_school, v_sid, p_date, v_status, v_late, v_note)
    on conflict (student_id, attendance_date)
    do update set status = excluded.status, minutes_late = excluded.minutes_late, note = excluded.note, created_by = auth.uid(), created_at = now();
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('saved', v_n);
end $function$;

-- Function: save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text)
CREATE OR REPLACE FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_school uuid := (select private.my_school());
  k text;
  v jsonb;
  v_subject uuid;
begin
  if (select private.my_role()) not in ('admin','supervisor') then
    raise exception 'ليست لديك صلاحية لهذا الإجراء';
  end if;

  if not exists (
    select 1 from public.students
    where id = p_student and school_id = v_school
  ) then
    raise exception 'الطالب غير موجود في مدرستك';
  end if;

  insert into public.student_behavior(
    student_id, school_id, absences, lates, discipline, notes, updated_at
  )
  values (
    p_student, v_school, p_absences, p_lates, p_discipline,
    btrim(coalesce(p_notes, '')), now()
  )
  on conflict (student_id) do update
    set absences = excluded.absences,
        lates = excluded.lates,
        discipline = excluded.discipline,
        notes = excluded.notes,
        updated_at = now();

  for k, v in select * from jsonb_each(coalesce(p_grades, '{}'::jsonb)) loop
    v_subject := k::uuid;

    if not exists (
      select 1 from public.subjects
      where id = v_subject and school_id = v_school
    ) then
      raise exception 'المادة غير موجودة في مدرستك';
    end if;

    if jsonb_typeof(v) = 'null' then
      delete from public.grades
      where student_id = p_student
        and subject_id = v_subject
        and school_id = v_school;
    else
      if (v #>> '{}')::numeric < 0 or (v #>> '{}')::numeric > 100 then
        raise exception 'الدرجة يجب أن تكون بين 0 و100';
      end if;

      insert into public.grades(student_id, subject_id, school_id, score)
      values (p_student, v_subject, v_school, (v #>> '{}')::numeric)
      on conflict (student_id, subject_id) do update
        set score = excluded.score;
    end if;
  end loop;
end;
$function$;

-- Function: school_daily_summary(p_date date)
CREATE OR REPLACE FUNCTION public.school_daily_summary(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
select jsonb_build_object(
 'students',(select count(*) from public.students where school_id=private.my_school()),
 'present',(select count(*) from public.attendance where school_id=private.my_school() and attendance_date=p_date and status='present'),
 'absent',(select count(*) from public.attendance where school_id=private.my_school() and attendance_date=p_date and status='absent'),
 'late',(select count(*) from public.attendance where school_id=private.my_school() and attendance_date=p_date and status='late'),
 'payments',(select coalesce(sum(amount),0) from public.payments where school_id=private.my_school() and created_at::date=p_date),
 'expenses',(select coalesce(sum(amount),0) from public.expenses where school_id=private.my_school() and created_at::date=p_date)
); $function$;

-- Function: set_student_promotion(p_student_id uuid, p_target_class_id uuid, p_status text)
CREATE OR REPLACE FUNCTION public.set_student_promotion(p_student_id uuid, p_target_class_id uuid, p_status text DEFAULT 'active'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare sid uuid := private.my_school(); ay uuid;
begin
  if sid is null or private.my_role() not in ('owner','admin') then raise exception 'غير مصرح'; end if;
  select id into ay from academic_years where school_id=sid and active=true order by starts_on desc nulls last,created_at desc limit 1;
  if ay is null then raise exception 'لا توجد سنة دراسية نشطة'; end if;
  if not exists(select 1 from students where id=p_student_id and school_id=sid) then raise exception 'الطالب غير موجود'; end if;
  if p_target_class_id is not null and not exists(select 1 from classes where id=p_target_class_id and school_id=sid and (academic_year_id is null or academic_year_id=ay)) then raise exception 'الصف غير صالح'; end if;
  insert into student_enrollments(school_id,student_id,academic_year_id,class_id,status)
  values(sid,p_student_id,ay,p_target_class_id,p_status)
  on conflict(student_id,academic_year_id) do update set class_id=excluded.class_id,status=excluded.status;
  update students set current_academic_year_id=ay, active=(p_status not in ('graduated','withdrawn')) , status=p_status where id=p_student_id and school_id=sid;
end;
$function$;

-- Function: update_school_settings(p_name text, p_currency text, p_country_code text)
CREATE OR REPLACE FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select private.my_role()) is distinct from 'admin' then raise exception 'ليست لديك صلاحية لهذا الإجراء'; end if;
  update public.schools set name = btrim(p_name), currency = btrim(p_currency), country_code = p_country_code
  where id = (select private.my_school());
end $function$;

-- Function: update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric)
CREATE OR REPLACE FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_school uuid := (select private.my_school());
begin
  if (select private.my_role()) is distinct from 'admin' then
    raise exception 'ليست لديك صلاحية لهذا الإجراء';
  end if;

  update public.students
  set name = btrim(p_name),
      class_name = btrim(p_class),
      phone = p_phone
  where id = p_id
    and school_id = v_school;

  if not found then
    raise exception 'الطالب غير موجود في مدرستك';
  end if;

  update public.student_fees
  set total_fee = p_fee
  where student_id = p_id
    and school_id = v_school;
end;
$function$;
