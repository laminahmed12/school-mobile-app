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
