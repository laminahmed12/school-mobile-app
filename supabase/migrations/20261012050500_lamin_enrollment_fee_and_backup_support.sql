-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Student creation now snapshots the configured fee for the matching grade/year/term when no manual amount is supplied.
create or replace function public.create_student_with_fee(
  p_name text, p_class_name text, p_phone text default '', p_term_fee numeric default 0, p_term text default 'الفصل الأول'
)
returns uuid language plpgsql set search_path = ''
as $function$
declare
  v_student_id uuid; v_school_id uuid := private.my_school(); v_role text := private.my_role();
  v_year_id uuid; v_year_name text; v_class_id uuid; v_grade_order integer;
  v_term text := coalesce(nullif(btrim(p_term),''),'الفصل الأول');
  v_fee numeric(12,2) := coalesce(p_term_fee,0);
begin
  if auth.uid() is null or v_school_id is null then raise exception 'يجب تسجيل الدخول إلى المدرسة أولاً'; end if;
  if v_role not in ('admin','owner','supervisor') then raise exception 'ليست لديك صلاحية إضافة طالب'; end if;
  if char_length(btrim(coalesce(p_name,''))) < 2 or char_length(btrim(coalesce(p_name,''))) > 120 then raise exception 'اسم الطالب مطلوب'; end if;
  if char_length(btrim(coalesce(p_class_name,''))) < 1 or char_length(btrim(coalesce(p_class_name,''))) > 100 then raise exception 'الصف أو الفصل مطلوب'; end if;
  if v_fee < 0 then raise exception 'رسوم الفصل لا يمكن أن تكون سالبة'; end if;
  if v_fee > 0 and v_role not in ('admin','owner') then raise exception 'تحديد الرسوم متاح لمدير المدرسة فقط'; end if;
  select ay.id,ay.name into v_year_id,v_year_name from public.academic_years ay
    where ay.school_id=v_school_id and ay.active=true and coalesce(ay.is_closed,false)=false
    order by ay.starts_on desc nulls last,ay.created_at desc limit 1;
  if v_year_id is not null then
    select c.id,c.grade_order into v_class_id,v_grade_order from public.classes c
      where c.school_id=v_school_id and c.name=btrim(p_class_name)
        and (c.academic_year_id is null or c.academic_year_id=v_year_id)
      order by (c.academic_year_id=v_year_id) desc,c.created_at desc limit 1;
    if v_fee=0 and v_grade_order is not null then
      select fs.amount into v_fee from public.fee_schedules fs
        where fs.school_id=v_school_id and fs.academic_year_id=v_year_id
          and fs.grade_order=v_grade_order and fs.term=v_term and fs.active=true limit 1;
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
    insert into public.student_fee_assessments(school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,created_by)
      values(v_school_id,v_student_id,v_year_id,coalesce(v_year_name,'غير محدد'),v_term,v_fee,0,auth.uid());
  end if;
  return v_student_id;
end $function$;

-- Extend the existing v2 backup envelope without changing its format, preserving compatibility.
create or replace function public.export_backup(p_school uuid default null)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_role text:=private.my_role(); v_school uuid;
begin
 if v_role='owner' then
   if p_school is null then raise exception 'يجب تحديد المدرسة للنسخ الاحتياطي'; end if;
   v_school:=p_school;
 elsif v_role='admin' then
   v_school:=private.my_school();
   if p_school is not null and p_school<>v_school then raise exception 'غير مصرح'; end if;
 else raise exception 'ليست لديك صلاحية لهذا الإجراء'; end if;
 if v_school is null or not exists(select 1 from public.schools s where s.id=v_school) then raise exception 'المدرسة غير موجودة'; end if;
 return jsonb_build_object(
  'format','lamin-school-backup-v2','taken_at',now(),'school_filter',v_school,
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
end $function$;

create or replace function public.restore_backup(p_backup jsonb)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_school uuid; v_table text; v_count bigint; v_restored jsonb:='{}'::jsonb;
begin
 if private.my_role()<>'admin' then raise exception 'يُسمح لمدير المدرسة فقط باستعادة النسخة'; end if;
 v_school:=private.my_school();
 if v_school is null then raise exception 'المدرسة غير نشطة أو انتهت الفترة التجريبية؛ فعّل المدرسة أولاً'; end if;
 if p_backup is null or jsonb_typeof(p_backup)<>'object' or p_backup->>'format'<>'lamin-school-backup-v2'
    or p_backup->>'school_filter' is distinct from v_school::text then raise exception 'النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم'; end if;
 foreach v_table in array array[
  'academic_years','classes','students','teachers','staff','subjects','class_subjects','student_parents','student_fees',
  'student_enrollments','student_fee_assessments','student_opening_balances','payments','grades','student_results','student_behavior',
  'attendance','staff_payments','payroll_transactions','expenses','school_branding','backup_registry','fee_schedules','discount_rules','student_discount_awards'
 ] loop
  if jsonb_typeof(p_backup->v_table) is distinct from 'array' then continue; end if;
  execute format('insert into public.%I select incoming.* from jsonb_populate_recordset(null::public.%I,$1) as incoming where incoming.school_id=$2 on conflict do nothing',v_table,v_table)
    using p_backup->v_table,v_school;
  get diagnostics v_count=row_count; v_restored:=v_restored||jsonb_build_object(v_table,v_count);
 end loop;
 return jsonb_build_object('ok',true,'restored',v_restored,'message','تم دمج النسخة: أُضيفت السجلات الناقصة وتُركت السجلات المتطابقة دون تغيير.');
end $function$;
