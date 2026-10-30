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

CREATE TABLE IF NOT EXISTS public.lamin_offline_operation_receipts (
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  operation_id text NOT NULL,
  operation_type text NOT NULL CHECK (operation_type = 'create_student'),
  result_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id, operation_id)
);

ALTER TABLE public.lamin_offline_operation_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lamin_offline_operation_receipts FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_student_with_fee_idempotent(
  p_operation_id text,
  p_name text,
  p_class_name text,
  p_phone text DEFAULT '',
  p_term_fee numeric DEFAULT 0,
  p_term text DEFAULT 'الفصل الأول'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_school_id uuid := private.my_school();
  v_student_id uuid;
BEGIN
  IF auth.uid() IS NULL OR v_school_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول إلى المدرسة أولاً';
  END IF;
  IF private.my_role() NOT IN ('admin','owner','supervisor') THEN
    RAISE EXCEPTION 'ليست لديك صلاحية إضافة طالب';
  END IF;
  IF p_operation_id IS NULL OR btrim(p_operation_id) = '' THEN
    RAISE EXCEPTION 'معرّف العملية المحلية مطلوب';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_school_id::text || ':' || p_operation_id, 0)
  );

  SELECT receipt.result_id INTO v_student_id
  FROM public.lamin_offline_operation_receipts AS receipt
  WHERE receipt.school_id = v_school_id
    AND receipt.operation_id = p_operation_id
    AND receipt.operation_type = 'create_student';

  IF v_student_id IS NOT NULL THEN
    RETURN v_student_id;
  END IF;

  v_student_id := public.create_student_with_fee(
    p_name, p_class_name, coalesce(p_phone, ''), coalesce(p_term_fee, 0),
    coalesce(p_term, 'الفصل الأول')
  );

  INSERT INTO public.lamin_offline_operation_receipts(
    school_id, operation_id, operation_type, result_id
  ) VALUES (v_school_id, p_operation_id, 'create_student', v_student_id);

  RETURN v_student_id;
END
$function$;

REVOKE ALL ON FUNCTION public.create_student_with_fee_idempotent(text,text,text,text,numeric,text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.create_student_with_fee_idempotent(text,text,text,text,numeric,text)
  TO authenticated;

COMMIT;
