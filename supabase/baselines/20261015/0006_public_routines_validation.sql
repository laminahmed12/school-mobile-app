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

