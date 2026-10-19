-- REBUILT historical migration 002_rls_policies_rpcs for Lamīn.
-- Reconstructed from the catalog-derived current-state baseline, NOT recovered original SQL.
-- Intended for clean database bootstrap only; do not replay against an existing production database.
-- Generated 2026-10-19. Contains routines, RLS/policies/grants and current verified reconciliation.

-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

CREATE OR REPLACE FUNCTION private.audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_row jsonb; v_details jsonb; v_name text; v_school uuid;
begin
  if tg_op = 'DELETE' then
    v_row := to_jsonb(old); v_details := v_row;
  elsif tg_op = 'INSERT' then
    v_row := to_jsonb(new); v_details := v_row;
  else
    v_row := to_jsonb(new);
    v_details := jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new));
  end if;
  v_school := (v_row->>'school_id')::uuid;
  if v_school is null or not exists (select 1 from public.schools where id = v_school) then
    return null;
  end if;
  select username into v_name from public.profiles where user_id = auth.uid();
  insert into public.audit_log(school_id, user_id, username, action, entity, entity_id, details)
  values (v_school, auth.uid(), v_name, lower(tg_op), tg_table_name,
          coalesce(v_row->>'id', v_row->>'student_id'), v_details);
  return null;
end $function$;


CREATE OR REPLACE FUNCTION private.check_fee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_paid numeric;
begin
  if new.total_fee < old.total_fee then
    select coalesce(sum(amount), 0) into v_paid from public.payments where student_id = new.student_id;
    if new.total_fee < v_paid then
      raise exception 'إجمالي الرسوم أقل من المبلغ المدفوع (%)', v_paid;
    end if;
  end if;
  return new;
end $function$;


CREATE OR REPLACE FUNCTION private.check_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_fee numeric;
  v_paid numeric;
BEGIN
  SELECT total_fee
    INTO v_fee
    FROM public.student_fees
   WHERE student_id = NEW.student_id
   FOR UPDATE;

  -- A payment is allowed even if the school has not configured a fee record yet.
  -- When a fee exists, keep the protection against payments exceeding the balance.
  IF v_fee IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(SUM(amount), 0)
    INTO v_paid
    FROM public.payments
   WHERE student_id = NEW.student_id;

  IF v_paid + NEW.amount > v_fee THEN
    RAISE EXCEPTION 'المبلغ أكبر من المتبقي (%)', (v_fee - v_paid);
  END IF;

  RETURN NEW;
END
$function$;


CREATE OR REPLACE FUNCTION private.my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p.role
  FROM public.profiles p
  WHERE p.user_id = auth.uid()
    AND p.active
    AND (
      p.role = 'owner'
      OR EXISTS (
        SELECT 1
        FROM public.schools s
        WHERE s.id = p.school_id
          AND s.active
          AND (
            s.licensed
            OR (
              s.trial_started_at IS NOT NULL
              AND s.trial_started_at + interval '1 month' > now()
            )
          )
      )
    )
$function$;


CREATE OR REPLACE FUNCTION private.my_school()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p.school_id
  FROM public.profiles p
  JOIN public.schools s ON s.id = p.school_id
  WHERE p.user_id = auth.uid()
    AND p.active
    AND s.active
    AND (
      s.licensed
      OR (
        s.trial_started_at IS NOT NULL
        AND s.trial_started_at + interval '1 month' > now()
      )
    )
$function$;


CREATE OR REPLACE FUNCTION private.restore_school_data(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t text; c int; n jsonb := '{}'::jsonb;
begin
  if p->>'format' is distinct from 'laameen-backup-v1' then raise exception 'صيغة النسخة غير معروفة'; end if;
  foreach t in array array['schools','students','student_fees','payments','subjects','grades','student_behavior','attendance','teachers','expenses'] loop
    execute format('insert into public.%I select * from jsonb_populate_recordset(null::public.%I, $1) on conflict do nothing', t, t)
      using coalesce(p->t, '[]'::jsonb);
    get diagnostics c = row_count;
    n := n || jsonb_build_object(t, c);
  end loop;
  return n;
end $function$;


CREATE OR REPLACE FUNCTION private.validate_payroll_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.payee_type = 'teacher' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.teachers t
      WHERE t.id = NEW.payee_id AND t.school_id = NEW.school_id
    ) THEN
      RAISE EXCEPTION 'المعلم غير موجود في هذه المدرسة';
    END IF;
  ELSIF NEW.payee_type = 'staff' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.staff s
      WHERE s.id = NEW.payee_id AND s.school_id = NEW.school_id AND s.active
    ) THEN
      RAISE EXCEPTION 'الموظف غير موجود أو موقوف في هذه المدرسة';
    END IF;
  ELSE
    RAISE EXCEPTION 'نوع المستفيد غير صالح';
  END IF;
  RETURN NEW;
END
$function$;



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



-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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



-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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



-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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
$function$;


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



-- Catalog-derived current routine definitions, captured 2026-10-15 UTC from stbrhcgzfxvpayfnnqfl.
-- No school/user/financial rows are included. Supabase auth helpers/roles are external dependencies.
SET search_path = public, extensions, pg_catalog;

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
$function$;


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



-- Lamīn baseline candidate, stage 11: RLS, policies, triggers, and privileges.
-- Captured 2026-10-15 UTC from read-only PostgreSQL catalogs on stbrhcgzfxvpayfnnqfl.
-- No application data is included. Apply only after stages 0001-0010.
-- Supabase-managed roles and auth schema must exist in the target environment.

-- Enable RLS as observed in the live catalog.

ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.license_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onedrive_access_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_gate_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rollover_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rollover_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_behavior ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_discount_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fee_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_opening_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_deletion_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_notifications ENABLE ROW LEVEL SECURITY;

-- Exact policy expressions from pg_policies.

CREATE POLICY academic_years_write ON public.academic_years AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY attendance_write ON public.attendance AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY audit_select ON public.audit_log AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY backup_registry_delete ON public.backup_registry AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY backup_registry_insert ON public.backup_registry AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY backup_registry_select ON public.backup_registry AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = private.my_school()));

CREATE POLICY backup_registry_update ON public.backup_registry AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK ((school_id = private.my_school()));

CREATE POLICY class_subjects_write ON public.class_subjects AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY classes_write ON public.classes AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY lamin_discount_rules_delete ON public.discount_rules AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_discount_rules_insert ON public.discount_rules AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_discount_rules_select ON public.discount_rules AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_discount_rules_update ON public.discount_rules AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY expenses_delete ON public.expenses AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY expenses_insert ON public.expenses AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY expenses_select ON public.expenses AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY expenses_update ON public.expenses AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY lamin_fee_schedules_delete ON public.fee_schedules AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_fee_schedules_insert ON public.fee_schedules AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_fee_schedules_select ON public.fee_schedules AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_fee_schedules_update ON public.fee_schedules AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_financial_adjustments_insert ON public.financial_adjustments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_financial_adjustments_select ON public.financial_adjustments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_financial_adjustments_update ON public.financial_adjustments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY grades_delete ON public.grades AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY grades_insert ON public.grades AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY grades_select ON public.grades AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY grades_update ON public.grades AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY onedrive_access_audit_insert ON public.onedrive_access_audit AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY onedrive_access_audit_select ON public.onedrive_access_audit AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_payment_allocations_insert ON public.payment_allocations AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_payment_allocations_select ON public.payment_allocations AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_payment_allocations_update ON public.payment_allocations AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY payments_delete ON public.payments AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY payments_insert ON public.payments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY payments_select ON public.payments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_payroll_periods_select ON public.payroll_periods AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_payroll_periods_write ON public.payroll_periods AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY payroll_transactions_delete ON public.payroll_transactions AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY payroll_transactions_insert ON public.payroll_transactions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])) AND (created_by = ( SELECT auth.uid() AS uid))));

CREATE POLICY payroll_transactions_select ON public.payroll_transactions AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY payroll_transactions_update ON public.payroll_transactions AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY profiles_select ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR ((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)) OR (( SELECT private.my_role() AS my_role) = 'owner'::text)));

CREATE POLICY lamin_rollover_batches_insert ON public.rollover_batches AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_rollover_batches_select ON public.rollover_batches AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_rollover_batches_update ON public.rollover_batches AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_rollover_items_insert ON public.rollover_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_rollover_items_select ON public.rollover_items AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_rollover_items_update ON public.rollover_items AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_salary_assignments_insert ON public.salary_assignments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_salary_assignments_select ON public.salary_assignments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_salary_assignments_update ON public.salary_assignments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY school_branding_insert_admin ON public.school_branding AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY school_branding_select_same_school ON public.school_branding AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) OR (( SELECT private.my_role() AS my_role) = 'owner'::text)));

CREATE POLICY school_branding_update_admin ON public.school_branding AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY schools_owner_delete ON public.schools AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT private.my_role() AS my_role) = 'owner'::text));

CREATE POLICY schools_owner_insert ON public.schools AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT private.my_role() AS my_role) = 'owner'::text));

CREATE POLICY schools_owner_update ON public.schools AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT private.my_role() AS my_role) = 'owner'::text)) WITH CHECK ((( SELECT private.my_role() AS my_role) = 'owner'::text));

CREATE POLICY schools_select ON public.schools AS PERMISSIVE FOR SELECT TO authenticated USING (((id = ( SELECT private.my_school() AS my_school)) OR (( SELECT private.my_role() AS my_role) = 'owner'::text)));

CREATE POLICY staff_select ON public.staff AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY staff_write ON public.staff AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY staff_payments_write ON public.staff_payments AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY behavior_insert ON public.student_behavior AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY behavior_select ON public.student_behavior AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY behavior_update ON public.student_behavior AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY lamin_discount_awards_insert ON public.student_discount_awards AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND (status = 'pending'::text) AND ((requested_by IS NULL) OR (requested_by = ( SELECT auth.uid() AS uid))) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_discount_awards_read ON public.student_discount_awards AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_discount_awards_update ON public.student_discount_awards AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY student_enrollments_delete ON public.student_enrollments AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY student_enrollments_insert ON public.student_enrollments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY student_enrollments_select ON public.student_enrollments AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = private.my_school()));

CREATE POLICY student_enrollments_update ON public.student_enrollments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK ((school_id = private.my_school()));

CREATE POLICY student_fee_assessments_delete ON public.student_fee_assessments AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY student_fee_assessments_insert ON public.student_fee_assessments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY student_fee_assessments_select ON public.student_fee_assessments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY student_fee_assessments_update ON public.student_fee_assessments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY fees_insert ON public.student_fees AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY fees_select ON public.student_fees AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY fees_update ON public.student_fees AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY opening_balances_delete ON public.student_opening_balances AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY opening_balances_insert ON public.student_opening_balances AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY opening_balances_select ON public.student_opening_balances AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = private.my_school()));

CREATE POLICY opening_balances_update ON public.student_opening_balances AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])))) WITH CHECK ((school_id = private.my_school()));

CREATE POLICY student_parents_write ON public.student_parents AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY student_results_write ON public.student_results AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY students_delete ON public.students AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY students_insert ON public.students AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY students_select ON public.students AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = ( SELECT private.my_school() AS my_school)));

CREATE POLICY students_update ON public.students AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY subjects_delete ON public.subjects AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY subjects_insert ON public.subjects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY subjects_select ON public.subjects AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY teachers_delete ON public.teachers AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY teachers_insert ON public.teachers AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY teachers_select ON public.teachers AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text, 'supervisor'::text]))));

CREATE POLICY teachers_update ON public.teachers AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY user_deletion_audit_insert ON public.user_deletion_audit AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY user_deletion_audit_select ON public.user_deletion_audit AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY whatsapp_write ON public.whatsapp_notifications AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text, 'accountant'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text, 'accountant'::text]))));

-- User-defined triggers.

CREATE TRIGGER trg_audit_attendance AFTER INSERT OR UPDATE ON attendance FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON discount_rules FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON discount_rules FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER trg_audit_expenses AFTER INSERT OR DELETE OR UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON fee_schedules FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON fee_schedules FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON financial_adjustments FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON financial_adjustments FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON payment_allocations FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_validate_payment_allocation BEFORE INSERT OR UPDATE ON payment_allocations FOR EACH ROW EXECUTE FUNCTION lamin_validate_payment_allocation();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER trg_audit_payments AFTER INSERT OR DELETE ON payments FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER trg_check_payment BEFORE INSERT ON payments FOR EACH ROW EXECUTE FUNCTION private.check_payment();
CREATE TRIGGER payroll_transaction_validate_recipient BEFORE INSERT OR UPDATE OF school_id, payee_type, payee_id ON payroll_transactions FOR EACH ROW EXECUTE FUNCTION private.validate_payroll_transaction();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON rollover_batches FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_guard_rollover_year_state BEFORE INSERT OR UPDATE OF status ON rollover_batches FOR EACH ROW EXECUTE FUNCTION lamin_guard_rollover_year_state();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON rollover_batches FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON rollover_items FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER schools_normalize_code BEFORE INSERT OR UPDATE OF code ON schools FOR EACH ROW EXECUTE FUNCTION normalize_school_code();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_sync_award_discount AFTER INSERT OR DELETE OR UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_sync_award_discount();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_validate_discount_award BEFORE INSERT OR UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_validate_discount_award();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON student_fee_assessments FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_capture_manual_discount BEFORE INSERT OR UPDATE OF discount ON student_fee_assessments FOR EACH ROW EXECUTE FUNCTION lamin_capture_manual_discount();
CREATE TRIGGER trg_audit_fees AFTER INSERT OR UPDATE ON student_fees FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER trg_check_fee BEFORE UPDATE ON student_fees FOR EACH ROW EXECUTE FUNCTION private.check_fee();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON student_opening_balances FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON student_opening_balances FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER trg_audit_students AFTER INSERT OR DELETE OR UPDATE ON students FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER trg_audit_teachers AFTER INSERT OR DELETE ON teachers FOR EACH ROW EXECUTE FUNCTION private.audit();

-- Schema privileges.

GRANT USAGE ON SCHEMA extensions TO anon;
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT CREATE ON SCHEMA extensions TO dashboard_user;
GRANT USAGE ON SCHEMA extensions TO dashboard_user;
GRANT USAGE ON SCHEMA extensions TO service_role;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT USAGE ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO service_role;

-- Explicit table, view, and sequence privileges.

-- Supabase projects can apply broader default table ACLs at CREATE TABLE time.
-- Reset anon/authenticated table ACLs, then replay the catalog-derived grants below,
-- so a fresh Supabase project matches the captured reference rather than inheriting extras.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.academic_years TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.academic_years TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.attendance TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.attendance TO service_role;
GRANT SELECT ON TABLE public.audit_log TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.audit_log TO service_role;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.audit_log_id_seq TO anon;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.audit_log_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.audit_log_id_seq TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.backup_registry TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.backup_registry TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.backup_registry TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.class_subjects TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.class_subjects TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.classes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.classes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.discount_rules TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.discount_rules TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.discount_rules TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.expenses TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.expenses TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fee_schedules TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fee_schedules TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fee_schedules TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.financial_adjustments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.financial_adjustments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.financial_adjustments TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.grades TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.grades TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.license_codes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.login_attempts TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.onedrive_access_audit TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.onedrive_access_audit TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.onedrive_access_audit TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.owner_gate_attempts TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payment_allocations TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payment_allocations TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payment_allocations TO service_role;
GRANT DELETE, INSERT, SELECT ON TABLE public.payments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payments TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_periods TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_periods TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_periods TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_transactions TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_transactions TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_transactions TO service_role;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_batches TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_batches TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_batches TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_items TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_items TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_items TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salary_assignments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salary_assignments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salary_assignments TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.school_branding TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.school_branding TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.school_branding TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.schools TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.schools TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.staff TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.staff TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.staff_payments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.staff_payments TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.student_behavior TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_behavior TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_discount_awards TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_discount_awards TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_discount_awards TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_enrollments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_enrollments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_enrollments TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fee_assessments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fee_assessments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fee_assessments TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.student_fees TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fees TO service_role;
GRANT SELECT ON TABLE public.student_finance TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_finance TO service_role;
GRANT SELECT ON TABLE public.student_financial_summary TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_financial_summary TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_opening_balances TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_opening_balances TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_opening_balances TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.student_parents TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_parents TO service_role;
GRANT SELECT ON TABLE public.student_result_summary TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_result_summary TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.student_results TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_results TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.students TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.students TO service_role;
GRANT DELETE, INSERT, SELECT ON TABLE public.subjects TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.subjects TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.teachers TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.teachers TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_deletion_audit TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_deletion_audit TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_deletion_audit TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.whatsapp_notifications TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.whatsapp_notifications TO service_role;

-- Reset default PUBLIC EXECUTE ACLs, then restore only catalog-observed grants.
REVOKE ALL ON FUNCTION private.audit() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.check_fee() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.check_payment() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.my_role() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.my_school() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.restore_school_data(p jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.validate_payroll_transaction() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.attendance_summary(p_date date) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.bootstrap_owner_school(p_code text, p_name text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.carry_forward_open_balances(p_old_year uuid, p_new_year uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.delete_school_user(p_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.execute_academic_rollover(p_batch_id uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup_core_v2(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup_core_v3(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup_core_v4(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.import_students(p_rows jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_capture_manual_discount() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_guard_rollover_year_state() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_set_updated_at() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_sync_award_discount() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_validate_discount_award() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_validate_payment_allocation() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_write_audit_event() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.license_trial_status(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.normalize_school_code() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.owner_stats() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.promote_passed_students(p_old_year uuid, p_new_year uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.redeem_license_code(p_school_id uuid, p_code_hash text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup_core_v2(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup_core_v3(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup_core_v4(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.save_attendance_day(p_date date, p_rows jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.school_daily_summary(p_date date) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_student_promotion(p_student_id uuid, p_target_class_id uuid, p_status text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric) FROM PUBLIC, anon, authenticated, service_role;

-- Routine execute privileges.

GRANT EXECUTE ON FUNCTION private.my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION private.my_school() TO authenticated;
GRANT EXECUTE ON FUNCTION private.validate_payroll_transaction() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.attendance_summary(p_date date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_summary(p_date date) TO service_role;
GRANT EXECUTE ON FUNCTION public.bootstrap_owner_school(p_code text, p_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_owner_school(p_code text, p_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.carry_forward_open_balances(p_old_year uuid, p_new_year uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_school_user(p_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_school_user(p_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.execute_academic_rollover(p_batch_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.execute_academic_rollover(p_batch_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup(p_school uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.export_backup(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup_core_v2(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup_core_v3(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup_core_v4(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text) TO service_role;
GRANT EXECUTE ON FUNCTION public.import_students(p_rows jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.import_students(p_rows jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_capture_manual_discount() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_guard_rollover_year_state() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_set_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.lamin_set_updated_at() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_sync_award_discount() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_validate_discount_award() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_validate_payment_allocation() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_write_audit_event() TO service_role;
GRANT EXECUTE ON FUNCTION public.license_trial_status(p_school uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.license_trial_status(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO anon;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO service_role;
GRANT EXECUTE ON FUNCTION public.owner_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_stats() TO service_role;
GRANT EXECUTE ON FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.promote_passed_students(p_old_year uuid, p_new_year uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text) TO service_role;
GRANT EXECUTE ON FUNCTION public.redeem_license_code(p_school_id uuid, p_code_hash text) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup(p_backup jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_backup(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup_core_v2(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup_core_v3(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup_core_v4(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text) TO service_role;
GRANT EXECUTE ON FUNCTION public.save_attendance_day(p_date date, p_rows jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_attendance_day(p_date date, p_rows jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text) TO service_role;
GRANT EXECUTE ON FUNCTION public.school_daily_summary(p_date date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.school_daily_summary(p_date date) TO service_role;
GRANT EXECUTE ON FUNCTION public.set_student_promotion(p_student_id uuid, p_target_class_id uuid, p_status text) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric) TO service_role;

-- Default privileges for objects created later.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO service_role;


-- Lamīn post-baseline drift reconciliation, stage 12.
-- This is a deliberately selective replay of verified repository deltas absent from the live production catalog.
-- It is NOT the historical migration chain and must not be applied to production as a migration repair.
-- Apply only after the catalog-derived base passes exact schema fingerprint comparison in an isolated database.
-- Verified differences addressed:
-- 1) rollover preview must calculate outstanding debt from allocations (formula version 2).
-- 2) rollover execution must close only its source year and activate only its target year.
-- 3) owners need explicit school-scoped teacher insert/update/delete policies.

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

