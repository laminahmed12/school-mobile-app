-- 2026-10-13 20:xx UTC+02:00 (Libya).
-- Fail closed if historical idempotency keys already collide within a school.
-- This is required by the ON CONFLICT target below and makes concurrent retries safe.
do $preflight$
begin
 if exists (
  select 1 from public.payments
  where idempotency_key is not null
  group by school_id,idempotency_key
  having count(*)>1
 ) then
  raise exception 'Migration blocked: duplicate non-null school payment idempotency keys require audited resolution';
 end if;
end
$preflight$;

create unique index if not exists payments_school_idempotency_key_uidx
 on public.payments(school_id,idempotency_key)
 where idempotency_key is not null;

-- 2026-10-13 04:18 UTC+02:00 (Libya).
-- A payment explicitly assigned to a fee assessment must satisfy that assessment first.
-- Remaining amount then pays carried opening balances and finally other assessments.
create or replace function public.record_student_payment(
 p_student_id uuid,p_amount numeric,p_note text default '',p_term text default 'غير محدد',
 p_fee_assessment_id uuid default null,p_idempotency_key text default null
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare
 v_school uuid:=private.my_school(); v_role text:=private.my_role(); v_year uuid; v_payment uuid;
 v_term text:=coalesce(nullif(btrim(p_term),''),'غير محدد'); v_remaining numeric(12,2):=round(coalesce(p_amount,0),2);
 r record; v_take numeric(12,2); v_existing_student uuid; v_existing_amount numeric(12,2); v_existing_assessment uuid;
begin
 if auth.uid() is null or v_school is null then raise exception 'يجب تسجيل الدخول إلى المدرسة أولاً'; end if;
 if v_role not in ('owner','admin','accountant') then raise exception 'ليست لديك صلاحية تسجيل الدفعات'; end if;
 if p_amount is null or round(p_amount,2)<=0 or p_amount>100000000 then raise exception 'قيمة الدفعة غير صحيحة'; end if;
 if length(coalesce(p_note,''))>200 then raise exception 'الملاحظة طويلة أكثر من اللازم'; end if;
 if p_idempotency_key is not null and (length(p_idempotency_key)=0 or length(p_idempotency_key)>200) then raise exception 'مفتاح الدفعة غير صالح'; end if;
 if not exists(select 1 from public.students s where s.id=p_student_id and s.school_id=v_school) then raise exception 'الطالب غير موجود ضمن المدرسة الحالية'; end if;
 select ay.id into v_year from public.academic_years ay where ay.school_id=v_school and ay.active=true and coalesce(ay.is_closed,false)=false order by ay.starts_on desc nulls last,ay.created_at desc limit 1;
 if p_fee_assessment_id is not null then
  select sfa.term into v_term from public.student_fee_assessments sfa where sfa.id=p_fee_assessment_id and sfa.school_id=v_school and sfa.student_id=p_student_id;
  if not found then raise exception 'بند الرسوم المحدد لا يخص هذا الطالب'; end if;
 end if;
 insert into public.payments(school_id,student_id,academic_year_id,fee_assessment_id,term,payment_date,amount,note,created_by,idempotency_key)
 values(v_school,p_student_id,v_year,p_fee_assessment_id,v_term,current_date,round(p_amount,2),btrim(coalesce(p_note,'')),auth.uid(),p_idempotency_key)
 on conflict (school_id,idempotency_key) where idempotency_key is not null do nothing
 returning id into v_payment;
 if v_payment is null then
  select p.id,p.student_id,p.amount,p.fee_assessment_id into v_payment,v_existing_student,v_existing_amount,v_existing_assessment
  from public.payments p where p.school_id=v_school and p.idempotency_key=p_idempotency_key;
  if v_payment is null then raise exception 'تعذر التحقق من الدفعة المكررة؛ أعد المحاولة'; end if;
  if v_existing_student is distinct from p_student_id or v_existing_amount is distinct from round(p_amount,2)
    or v_existing_assessment is distinct from p_fee_assessment_id then
   raise exception 'مفتاح الدفعة مستخدم مسبقاً لبيانات مختلفة';
  end if;
  return v_payment;
 end if;

 -- Explicit target first: do not silently apply a fee-specific payment to older debt.
 if p_fee_assessment_id is not null then
  select sfa.id,greatest(sfa.total_fee-sfa.discount
   -coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.fee_assessment_id=sfa.id and pa.reversed_at is null),0)
   -coalesce((select sum(oldp.amount) from public.payments oldp where oldp.fee_assessment_id=sfa.id and oldp.id<>v_payment
     and not exists(select 1 from public.payment_allocations olda where olda.payment_id=oldp.id and olda.reversed_at is null)),0),0) outstanding
   into r from public.student_fee_assessments sfa
   where sfa.id=p_fee_assessment_id and sfa.school_id=v_school and sfa.student_id=p_student_id;
  v_take:=least(v_remaining,coalesce(r.outstanding,0));
  if v_take>0 then
   insert into public.payment_allocations(school_id,student_id,payment_id,fee_assessment_id,amount,created_by)
   values(v_school,p_student_id,v_payment,p_fee_assessment_id,v_take,auth.uid());
   v_remaining:=v_remaining-v_take;
  end if;
 end if;

 -- Carry-over balances are paid after an explicitly selected assessment.
 for r in select ob.id,greatest(ob.amount-coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.opening_balance_id=ob.id and pa.reversed_at is null),0),0) outstanding
  from public.student_opening_balances ob where ob.school_id=v_school and ob.student_id=p_student_id order by ob.created_at,ob.id loop
  exit when v_remaining<=0; if r.outstanding<=0 then continue; end if; v_take:=least(v_remaining,r.outstanding);
  insert into public.payment_allocations(school_id,student_id,payment_id,opening_balance_id,amount,created_by) values(v_school,p_student_id,v_payment,r.id,v_take,auth.uid());
  v_remaining:=v_remaining-v_take;
 end loop;
 for r in select sfa.id,greatest(sfa.total_fee-sfa.discount
  -coalesce((select sum(pa.amount) from public.payment_allocations pa where pa.fee_assessment_id=sfa.id and pa.reversed_at is null),0)
  -coalesce((select sum(oldp.amount) from public.payments oldp where oldp.fee_assessment_id=sfa.id and oldp.id<>v_payment
    and not exists(select 1 from public.payment_allocations olda where olda.payment_id=oldp.id and olda.reversed_at is null)),0),0) outstanding
  from public.student_fee_assessments sfa where sfa.school_id=v_school and sfa.student_id=p_student_id
   and (p_fee_assessment_id is null or sfa.id<>p_fee_assessment_id)
  order by sfa.due_date asc nulls last,sfa.created_at,sfa.id loop
  exit when v_remaining<=0; if r.outstanding<=0 then continue; end if; v_take:=least(v_remaining,r.outstanding);
  insert into public.payment_allocations(school_id,student_id,payment_id,fee_assessment_id,amount,created_by) values(v_school,p_student_id,v_payment,r.id,v_take,auth.uid());
  v_remaining:=v_remaining-v_take;
 end loop;
 return v_payment;
end
$function$;
revoke all on function public.record_student_payment(uuid,numeric,text,text,uuid,text) from public,anon;
grant execute on function public.record_student_payment(uuid,numeric,text,text,uuid,text) to authenticated;
