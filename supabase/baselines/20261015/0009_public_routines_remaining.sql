-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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
$function$


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
end $function$


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
$function$


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
); $function$


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
$function$


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
end $function$


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
$function$

