-- Manager-requested annual teacher records and student financial charges/plans.
-- Additive migration: does not alter or delete existing production records.
CREATE TABLE IF NOT EXISTS public.teacher_academic_year_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  teacher_id uuid NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE RESTRICT,
  subject text,
  salary numeric(12,2),
  phone text,
  active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (school_id, teacher_id, academic_year_id)
);

CREATE TABLE IF NOT EXISTS public.student_extra_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE RESTRICT,
  charge_type text NOT NULL CHECK (charge_type IN ('transport','tutoring','damage','other')),
  title text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  incident_date date,
  notes text,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.student_payment_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE RESTRICT,
  title text NOT NULL,
  total_amount numeric(12,2) NOT NULL CHECK (total_amount > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid DEFAULT auth.uid()
);

CREATE TABLE IF NOT EXISTS public.student_payment_installments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.student_payment_plans(id) ON DELETE CASCADE,
  installment_number integer NOT NULL CHECK (installment_number > 0),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  due_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_id, installment_number)
);

ALTER TABLE public.teacher_academic_year_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_extra_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_payment_installments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS teacher_year_records_school_admin ON public.teacher_academic_year_records;
CREATE POLICY teacher_year_records_school_admin ON public.teacher_academic_year_records
  FOR ALL TO authenticated
  USING (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'))
  WITH CHECK (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));

DROP POLICY IF EXISTS student_extra_charges_school_finance ON public.student_extra_charges;
CREATE POLICY student_extra_charges_school_finance ON public.student_extra_charges
  FOR ALL TO authenticated
  USING (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner','accountant'))
  WITH CHECK (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner','accountant'));

DROP POLICY IF EXISTS student_payment_plans_school_finance ON public.student_payment_plans;
CREATE POLICY student_payment_plans_school_finance ON public.student_payment_plans
  FOR ALL TO authenticated
  USING (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner','accountant'))
  WITH CHECK (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner','accountant'));

DROP POLICY IF EXISTS student_payment_installments_school_finance ON public.student_payment_installments;
CREATE POLICY student_payment_installments_school_finance ON public.student_payment_installments
  FOR ALL TO authenticated
  USING (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner','accountant'))
  WITH CHECK (school_id = (SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner','accountant'));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.teacher_academic_year_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_extra_charges TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_payment_plans TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_payment_installments TO authenticated;
