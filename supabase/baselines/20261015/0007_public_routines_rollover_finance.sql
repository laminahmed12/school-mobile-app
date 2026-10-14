-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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
$function$


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
$function$


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
$function$


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
$function$

