-- Lamīn post-baseline drift reconciliation, stage 12.
-- This is a deliberately selective replay of verified repository deltas absent from the live production catalog.
-- It is NOT the historical migration chain and must not be applied to production as a migration repair.
-- Apply only after the catalog-derived base passes exact schema fingerprint comparison in an isolated database.
-- Verified differences addressed:
-- 1) create_next_academic_year must only create an inactive target year; no pre-review student migration.
-- 2) rollover preview must calculate outstanding debt from allocations (formula version 2).
-- 3) rollover execution must close only its source year and activate only its target year.
-- 4) owners need explicit school-scoped teacher insert/update/delete policies.

-- Selected verified source delta: supabase/migrations/20261012064000_lamin_disable_legacy_rollover_bypasses.sql
-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Reviewed rollover wizard is the only exposed path for bulk promotion and debt carry.
revoke all on function public.carry_forward_open_balances(uuid,uuid) from public,anon,authenticated;
revoke all on function public.promote_passed_students(uuid,uuid) from public,anon,authenticated;
revoke all on function public.set_student_promotion(uuid,uuid,text) from public,anon,authenticated;

-- Creating a target year must not close or migrate the source year before review.
create or replace function public.create_next_academic_year(
 p_name text,p_starts_on date default null,p_ends_on date default null,
 p_migrate_students boolean default true,p_migrate_staff boolean default true
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); v_id uuid;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'غير مصرح'; end if;
 if length(btrim(coalesce(p_name,'')))<3 or length(btrim(p_name))>60 then raise exception 'اسم السنة الدراسية غير صالح'; end if;
 if p_starts_on is not null and p_ends_on is not null and p_ends_on<p_starts_on then raise exception 'تاريخ نهاية السنة يسبق بدايتها'; end if;
 if exists(select 1 from public.academic_years where school_id=sid and lower(name)=lower(btrim(p_name))) then raise exception 'اسم السنة الدراسية موجود مسبقاً'; end if;
 insert into public.academic_years(school_id,name,starts_on,ends_on,active,is_closed)
 values(sid,btrim(p_name),p_starts_on,p_ends_on,false,false) returning id into v_id;
 return v_id;
end $function$;
revoke all on function public.create_next_academic_year(text,date,date,boolean,boolean) from public,anon;
grant execute on function public.create_next_academic_year(text,date,date,boolean,boolean) to authenticated;

-- Selected verified source delta: supabase/migrations/20261013190000_lamin_rollover_balance_from_allocations.sql
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
 if v_batch is not null then
  -- Never reuse an old preview after the ledger formula changes. Preserve its
  -- history by cancelling only batches that have no reviewed items; reviewed
  -- batches require an explicit human resolution rather than silent replacement.
  if exists(select 1 from public.rollover_items where batch_id=v_batch and reviewed) then
   raise exception 'توجد معاينة ترحيل سابقة تمت مراجعتها؛ أوقفها وراجع قراراتها قبل إنشاء معاينة جديدة';
  end if;
  update public.rollover_batches set status='cancelled',
   error_summary='Superseded by allocation-ledger balance formula v2; no reviewed items were changed',
   updated_by=auth.uid()
  where id=v_batch and school_id=sid and status in ('draft','reviewed');
  v_batch:=null;
 end if;
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
 update public.rollover_batches set preview=jsonb_build_object('balance_formula_version',2,
  'student_count',(select count(*) from public.rollover_items where batch_id=v_batch),
  'total_opening_balance',(select coalesce(sum(source_balance),0) from public.rollover_items where batch_id=v_batch),
  'needs_class',(select count(*) from public.rollover_items where batch_id=v_batch and decision in ('promote','repeat') and target_class_id is null),
  'needs_review',(select count(*) from public.rollover_items where batch_id=v_batch and not reviewed)) where id=v_batch;
 return v_batch;
end
$function$;

-- Block execution of rollover previews created under the older, payment-total formula.
create or replace function public.lamin_guard_rollover_year_state()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if TG_OP='INSERT' or NEW.status='running' then
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.source_academic_year_id and ay.school_id=NEW.school_id and ay.active=true and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة المصدر يجب أن تكون السنة النشطة غير المغلقة';
  end if;
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.target_academic_year_id and ay.school_id=NEW.school_id and ay.active=false and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة الهدف يجب أن تكون سنة غير نشطة وغير مغلقة';
  end if;
  if NEW.status='running' and coalesce(NEW.preview->>'balance_formula_version','')<>'2' then
   raise exception 'معاينة الترحيل قديمة؛ أعد إعداد المعاينة ومراجعة جميع الطلاب قبل التنفيذ';
  end if;
 end if;
 return NEW;
end $function$;
revoke all on function public.lamin_guard_rollover_year_state() from public,anon,authenticated;

-- Selected verified source delta: supabase/migrations/20261014050000_fix_academic_rollover_year_closing.sql
-- Close only the source academic year during rollover.
-- Do not accidentally close other future/planned academic years for the school.
create or replace function public.execute_academic_rollover(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  sid uuid := private.my_school();
  v_role text := private.my_role();
  b record;
  i record;
  v_enrollment uuid;
  v_balance_id uuid;
  v_students integer := 0;
  v_balances integer := 0;
begin
  if sid is null or v_role not in ('owner','admin') then
    raise exception 'تنفيذ الترحيل متاح لمدير المدرسة فقط';
  end if;

  select * into b
  from public.rollover_batches
  where id = p_batch_id and school_id = sid
  for update;

  if not found then raise exception 'عملية الترحيل غير موجودة'; end if;
  if b.status = 'completed' then
    return jsonb_build_object('ok', true, 'already_completed', true, 'message', 'تم تنفيذ هذه العملية سابقاً.');
  end if;
  if b.status not in ('draft','reviewed','approved') then
    raise exception 'حالة عملية الترحيل لا تسمح بالتنفيذ';
  end if;

  if not exists (
    select 1 from public.academic_years
    where id = b.source_academic_year_id and school_id = sid
      and active = true and coalesce(is_closed, false) = false
  ) or not exists (
    select 1 from public.academic_years
    where id = b.target_academic_year_id and school_id = sid
      and active = false and coalesce(is_closed, false) = false
  ) then
    raise exception 'تغيرت حالة إحدى السنتين منذ إعداد المعاينة؛ أعد المراجعة';
  end if;

  if exists (
    select 1 from public.rollover_items
    where batch_id = p_batch_id and not reviewed
  ) then raise exception 'راجع قرار كل طالب قبل تنفيذ الترحيل'; end if;

  if exists (
    select 1 from public.rollover_items
    where batch_id = p_batch_id and decision in ('promote','repeat')
      and target_class_id is null
  ) then raise exception 'يجب تحديد الصف الهدف لكل طالب ناجح أو راسب قبل التنفيذ'; end if;

  if exists (
    select 1 from public.rollover_items ri
    join public.classes c on c.id = ri.target_class_id
    where ri.batch_id = p_batch_id and ri.decision in ('promote','repeat')
      and c.school_id <> sid
  ) then raise exception 'يوجد صف هدف خارج المدرسة'; end if;

  if exists (
    select 1 from public.rollover_items ri
    join public.classes c on c.id = ri.target_class_id
    where ri.batch_id = p_batch_id and ri.decision in ('promote','repeat')
      and c.academic_year_id is not null
      and c.academic_year_id <> b.target_academic_year_id
  ) then raise exception 'الصف الهدف لا ينتمي للسنة الجديدة'; end if;

  if exists (
    select 1 from public.student_opening_balances ob
    join public.rollover_items ri on ri.student_id = ob.student_id
    where ri.batch_id = p_batch_id
      and ob.academic_year_id = b.target_academic_year_id
      and ob.rollover_batch_id is distinct from p_batch_id
  ) then raise exception 'توجد أرصدة افتتاحية مسبقة للسنة الهدف؛ راجعها قبل الترحيل لمنع تكرار الدين'; end if;

  update public.rollover_batches
  set status = 'running',
      approved_at = coalesce(approved_at, now()),
      approved_by = coalesce(approved_by, auth.uid()),
      updated_by = auth.uid()
  where id = p_batch_id;

  for i in
    select * from public.rollover_items
    where batch_id = p_batch_id order by student_id
  loop
    if i.decision in ('promote','repeat') then
      select e.id into v_enrollment
      from public.student_enrollments e
      where e.school_id = sid and e.student_id = i.student_id
        and e.academic_year_id = b.target_academic_year_id;

      if v_enrollment is not null then
        if not exists (
          select 1 from public.student_enrollments e
          where e.id = v_enrollment
            and e.promoted_from_enrollment_id = i.source_enrollment_id
        ) then raise exception 'يوجد تسجيل سابق مختلف للطالب في السنة الهدف'; end if;
      else
        insert into public.student_enrollments(
          school_id, student_id, academic_year_id, class_id, status,
          source_student_id, promoted_from_enrollment_id, result_status
        ) values (
          sid, i.student_id, b.target_academic_year_id, i.target_class_id,
          'active', i.student_id, i.source_enrollment_id, 'pending'
        ) returning id into v_enrollment;
        v_students := v_students + 1;
      end if;

      update public.students
      set current_academic_year_id = b.target_academic_year_id,
          active = true, status = 'active'
      where id = i.student_id and school_id = sid;

      update public.rollover_items
      set target_enrollment_id = v_enrollment
      where id = i.id;
    elsif i.decision = 'graduate' then
      update public.students set active = false, status = 'graduated'
      where id = i.student_id and school_id = sid;
    elsif i.decision = 'transfer' then
      update public.students set active = false, status = 'transferred'
      where id = i.student_id and school_id = sid;
    end if;
  end loop;

  for i in
    select * from public.rollover_items
    where batch_id = p_batch_id and source_balance > 0
    order by student_id
  loop
    if i.opening_balance_id is not null then continue; end if;

    insert into public.student_opening_balances(
      school_id, student_id, academic_year_id, source_academic_year_id,
      rollover_batch_id, amount, note, created_by
    ) values (
      sid, i.student_id, b.target_academic_year_id, b.source_academic_year_id,
      p_batch_id, i.source_balance, 'رصيد مرحّل معتمد من السنة السابقة', auth.uid()
    ) on conflict(student_id, academic_year_id) do nothing;

    select ob.id into v_balance_id
    from public.student_opening_balances ob
    where ob.school_id = sid and ob.student_id = i.student_id
      and ob.academic_year_id = b.target_academic_year_id;

    if v_balance_id is null then raise exception 'تعذر إنشاء الرصيد الافتتاحي'; end if;

    update public.rollover_items set opening_balance_id = v_balance_id
    where id = i.id;
    v_balances := v_balances + 1;
  end loop;

  -- Only close the source year for this rollover. Preserve any other
  -- inactive/unclosed future year that the school has already prepared.
  update public.academic_years
  set active = false, is_closed = true, closed_at = now()
  where school_id = sid and id = b.source_academic_year_id;

  update public.academic_years
  set active = true, is_closed = false, closed_at = null
  where id = b.target_academic_year_id and school_id = sid;

  update public.rollover_batches
  set status = 'completed', completed_at = now(), updated_by = auth.uid(),
      preview = preview || jsonb_build_object(
        'created_enrollments', v_students, 'opening_balances', v_balances
      )
  where id = p_batch_id;

  return jsonb_build_object(
    'ok', true, 'created_enrollments', v_students,
    'opening_balances', v_balances,
    'message', 'اكتمل الترحيل وتم إقفال السنة المصدر فقط.'
  );
end
$function$;

-- Selected verified source delta: supabase/migrations/20261014030000_allow_owner_teacher_management.sql
-- Allow school owners as well as admins to maintain teacher records.
-- Existing school-scoped SELECT policy remains unchanged.
drop policy if exists teachers_owner_insert on public.teachers;
create policy teachers_owner_insert on public.teachers
  for insert to authenticated
  with check (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

drop policy if exists teachers_owner_update on public.teachers;
create policy teachers_owner_update on public.teachers
  for update to authenticated
  using (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  )
  with check (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

drop policy if exists teachers_owner_delete on public.teachers;
create policy teachers_owner_delete on public.teachers
  for delete to authenticated
  using (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

