-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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


CREATE OR REPLACE FUNCTION public.attendance_summary(p_date date DEFAULT CURRENT_DATE)
 RETURNS TABLE(total bigint, present bigint, absent bigint, late bigint, excused bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$ select count(*), count(*) filter(where status='present'), count(*) filter(where status='absent'), count(*) filter(where status='late'), count(*) filter(where status='excused') from public.attendance where school_id=private.my_school() and attendance_date=p_date $function$;


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

