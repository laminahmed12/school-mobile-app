-- Durable idempotency for offline student creation.
-- This migration is applied only through the reviewed release migration process.
BEGIN;

-- Repair the existing student creation RPC: the previous implementation omitted
-- class_name from its INSERT value list and therefore failed at runtime.
CREATE OR REPLACE FUNCTION public.create_student_with_fee(
  p_name text,
  p_class_name text,
  p_phone text DEFAULT ''::text,
  p_term_fee numeric DEFAULT 0,
  p_term text DEFAULT 'الفصل الأول'::text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_student_id uuid;
  v_school_id uuid := private.my_school();
  v_role text := private.my_role();
  v_year_id uuid;
  v_year_name text;
  v_class_id uuid;
  v_grade_order integer;
  v_term text := coalesce(nullif(btrim(p_term), ''), 'الفصل الأول');
  v_fee numeric(12,2) := coalesce(p_term_fee, 0);
BEGIN
  IF auth.uid() IS NULL OR v_school_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول إلى المدرسة أولاً';
  END IF;
  IF v_role NOT IN ('admin','owner','supervisor') THEN
    RAISE EXCEPTION 'ليست لديك صلاحية إضافة طالب';
  END IF;
  IF char_length(btrim(coalesce(p_name,''))) < 2
     OR char_length(btrim(coalesce(p_name,''))) > 120 THEN
    RAISE EXCEPTION 'اسم الطالب مطلوب';
  END IF;
  IF char_length(btrim(coalesce(p_class_name,''))) < 1
     OR char_length(btrim(coalesce(p_class_name,''))) > 100 THEN
    RAISE EXCEPTION 'الصف أو الفصل مطلوب';
  END IF;
  IF v_fee < 0 THEN RAISE EXCEPTION 'رسوم الفصل لا يمكن أن تكون سالبة'; END IF;
  IF v_fee > 0 AND v_role NOT IN ('admin','owner') THEN
    RAISE EXCEPTION 'تحديد الرسوم متاح لمدير المدرسة فقط';
  END IF;

  SELECT ay.id, ay.name INTO v_year_id, v_year_name
  FROM public.academic_years AS ay
  WHERE ay.school_id = v_school_id
    AND ay.active = true
    AND coalesce(ay.is_closed,false) = false
  ORDER BY ay.starts_on DESC NULLS LAST, ay.created_at DESC
  LIMIT 1;

  IF v_year_id IS NOT NULL THEN
    SELECT c.id, c.grade_order INTO v_class_id, v_grade_order
    FROM public.classes AS c
    WHERE c.school_id = v_school_id
      AND c.name = btrim(p_class_name)
      AND (c.academic_year_id IS NULL OR c.academic_year_id = v_year_id)
    ORDER BY (c.academic_year_id = v_year_id) DESC, c.created_at DESC
    LIMIT 1;

    IF v_fee = 0 AND v_grade_order IS NOT NULL THEN
      SELECT fs.amount INTO v_fee
      FROM public.fee_schedules AS fs
      WHERE fs.school_id = v_school_id
        AND fs.academic_year_id = v_year_id
        AND fs.grade_order = v_grade_order
        AND fs.term = v_term
        AND fs.active = true
      LIMIT 1;
      v_fee := coalesce(v_fee,0);
    END IF;
  END IF;

  INSERT INTO public.students(school_id,name,class_name,phone)
  VALUES (
    v_school_id,
    btrim(p_name),
    btrim(p_class_name),
    btrim(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'))
  )
  RETURNING id INTO v_student_id;

  IF v_year_id IS NOT NULL THEN
    INSERT INTO public.student_enrollments(
      school_id,student_id,academic_year_id,class_id,status,source_student_id
    )
    VALUES(v_school_id,v_student_id,v_year_id,v_class_id,'active',v_student_id)
    ON CONFLICT(student_id,academic_year_id) DO NOTHING;
    UPDATE public.students
    SET current_academic_year_id = v_year_id
    WHERE id = v_student_id AND school_id = v_school_id;
  END IF;

  IF v_fee > 0 THEN
    INSERT INTO public.student_fee_assessments(
      school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,created_by
    )
    VALUES(v_school_id,v_student_id,v_year_id,coalesce(v_year_name,'غير محدد'),v_term,v_fee,0,auth.uid());
  END IF;

  RETURN v_student_id;
END
$function$;

-- Durable idempotency for offline student creation.
-- Keep the production RPC argument names/order and SECURITY INVOKER contract.
-- The client_operations table is school-scoped by RLS and records the authenticated creator.

-- Reconstruct the same school-scoped idempotency ledger used by production.
CREATE TABLE IF NOT EXISTS public.client_operations (
  school_id uuid NOT NULL DEFAULT private.my_school()
    REFERENCES public.schools(id) ON DELETE CASCADE,
  operation_id text NOT NULL
    CHECK (char_length(operation_id) >= 8 AND char_length(operation_id) <= 80),
  kind text NOT NULL,
  result_id uuid,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id, operation_id)
);

ALTER TABLE public.client_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.client_operations FROM PUBLIC, anon;
GRANT SELECT, INSERT ON TABLE public.client_operations TO authenticated;

DROP POLICY IF EXISTS client_operations_select ON public.client_operations;
DROP POLICY IF EXISTS client_operations_insert ON public.client_operations;
CREATE POLICY client_operations_select ON public.client_operations
  FOR SELECT TO authenticated
  USING (school_id = (SELECT private.my_school()));
CREATE POLICY client_operations_insert ON public.client_operations
  FOR INSERT TO authenticated
  WITH CHECK (
    school_id = (SELECT private.my_school())
    AND created_by = (SELECT auth.uid())
  );

CREATE OR REPLACE FUNCTION public.create_student_with_fee_idempotent(
  p_name text,
  p_class_name text,
  p_phone text,
  p_term_fee numeric,
  p_term text,
  p_operation_id text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_school uuid := private.my_school();
  v_op text := btrim(coalesce(p_operation_id, ''));
  v_existing uuid;
  v_seen boolean;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR v_school IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول إلى المدرسة أولاً';
  END IF;
  IF char_length(v_op) < 8 OR char_length(v_op) > 80 THEN
    RAISE EXCEPTION 'معرّف العملية غير صالح';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_school::text || ':' || v_op, 0));

  SELECT true, result_id INTO v_seen, v_existing
  FROM public.client_operations
  WHERE school_id = v_school AND operation_id = v_op
    AND kind = 'create_student' AND created_by = auth.uid();

  IF coalesce(v_seen, false) THEN
    RETURN v_existing;
  END IF;

  v_id := public.create_student_with_fee(
    p_name, p_class_name, coalesce(p_phone, ''), coalesce(p_term_fee, 0),
    coalesce(nullif(btrim(p_term), ''), 'الفصل الأول')
  );

  INSERT INTO public.client_operations(school_id, operation_id, kind, result_id)
  VALUES (v_school, v_op, 'create_student', v_id);

  RETURN v_id;
END
$function$;

REVOKE ALL ON FUNCTION public.create_student_with_fee_idempotent(text,text,text,numeric,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_student_with_fee_idempotent(text,text,text,numeric,text,text)
  TO authenticated, service_role;

COMMIT;
