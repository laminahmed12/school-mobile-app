-- 2026-10-13 (Libya time, UTC+02:00).
-- Correct rollover balance calculation to follow the allocation ledger.
-- This migration is additive and does not rewrite existing financial records.
create or replace function public.prepare_academic_rollover(p_source_year uuid,p_target_year uuid)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); v_batch uuid; r record; v_balance numeric(12,2); v_decision text; v_target_class uuid;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'إعداد الترحيل متاح لمدير المدرسة فقط'; end if;
 if p_source_year=p_target_year then raise exception 'يجب اختيار سنتين مختلفتين'; end if;
 if not exists(select 1 from public.academic_years where id=p_source_year and school_id=sid) then raise exception 'السنة المصدر غير صحيحة'; end if;
 if not exists(select 1 from public.academic_years where id=p_target_year and school_id=sid and coalesce(is_closed,false)=false) then raise exception 'السنة الهدف غير صحيحة أو مغلقة'; end if;
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
  -- Carry debt by its actual obligations and active allocations, not by subtracting
  -- every payment in the year (a payment may have paid a prior-year opening balance).
  -- Legacy payments with no allocations are only applied to their explicitly linked assessment.
  select
    coalesce((
      select sum(greatest(ob.amount - coalesce((
        select sum(pa.amount) from public.payment_allocations pa
        where pa.opening_balance_id=ob.id and pa.reversed_at is null
      ),0),0))
      from public.student_opening_balances ob
      where ob.school_id=sid and ob.student_id=r.student_id and ob.academic_year_id=p_source_year
    ),0)
    + coalesce((
      select sum(greatest(f.total_fee-f.discount
        - coalesce((select sum(pa.amount) from public.payment_allocations pa
          where pa.fee_assessment_id=f.id and pa.reversed_at is null),0)
        - coalesce((select sum(p.amount) from public.payments p
          where p.school_id=sid and p.student_id=r.student_id
            and p.fee_assessment_id=f.id and p.academic_year_id=p_source_year
            and not exists(select 1 from public.payment_allocations pa
              where pa.payment_id=p.id)),0),0))
      from public.student_fee_assessments f
      where f.school_id=sid and f.student_id=r.student_id and f.academic_year_id=p_source_year
    ),0)
    into v_balance;
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

