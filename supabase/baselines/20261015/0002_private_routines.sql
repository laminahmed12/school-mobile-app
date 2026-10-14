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

