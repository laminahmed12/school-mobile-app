-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
alter table public.rollover_items add column if not exists reviewed boolean not null default false;
alter table public.rollover_items add column if not exists reviewed_by uuid;
alter table public.rollover_items add column if not exists reviewed_at timestamptz;

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

create or replace function public.execute_academic_rollover(p_batch_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); b record; i record; v_enrollment uuid; v_balance_id uuid; v_students integer:=0; v_balances integer:=0;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'تنفيذ الترحيل متاح لمدير المدرسة فقط'; end if;
 select * into b from public.rollover_batches where id=p_batch_id and school_id=sid for update;
 if not found then raise exception 'عملية الترحيل غير موجودة'; end if;
 if b.status='completed' then return jsonb_build_object('ok',true,'already_completed',true,'message','تم تنفيذ هذه العملية سابقاً.'); end if;
 if b.status not in ('draft','reviewed','approved') then raise exception 'حالة عملية الترحيل لا تسمح بالتنفيذ'; end if;
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
 update public.academic_years set is_closed=true,active=false,closed_at=now() where id=b.source_academic_year_id and school_id=sid;
 update public.academic_years set active=true,is_closed=false,closed_at=null where id=b.target_academic_year_id and school_id=sid;
 update public.rollover_batches set status='completed',completed_at=now(),updated_by=auth.uid(),preview=preview||jsonb_build_object('created_enrollments',v_students,'opening_balances',v_balances) where id=p_batch_id;
 return jsonb_build_object('ok',true,'created_enrollments',v_students,'opening_balances',v_balances,'message','اكتمل الترحيل وتم إقفال السنة المصدر.');
end
$function$;
revoke all on function public.prepare_academic_rollover(uuid,uuid) from public,anon;
revoke all on function public.execute_academic_rollover(uuid) from public,anon;
grant execute on function public.prepare_academic_rollover(uuid,uuid) to authenticated;
grant execute on function public.execute_academic_rollover(uuid) to authenticated;
