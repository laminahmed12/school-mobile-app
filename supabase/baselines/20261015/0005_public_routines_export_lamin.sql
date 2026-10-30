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

