-- Consolidate equivalent RLS policies without changing role/tenant access,
-- remove one duplicate audit index, and index the remaining foreign keys flagged by advisors.
BEGIN;

-- payroll_periods: the ALL policy already covers SELECT for the same school/roles.
DROP POLICY IF EXISTS lamin_payroll_periods_select ON public.payroll_periods;

-- staff: keep the accountant read policy, but split the admin/owner ALL policy
-- so it no longer overlaps SELECT and cannot broaden accountant write access.
DROP POLICY IF EXISTS staff_write ON public.staff;
CREATE POLICY staff_insert ON public.staff
  FOR INSERT TO authenticated
  WITH CHECK (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));
CREATE POLICY staff_update ON public.staff
  FOR UPDATE TO authenticated
  USING (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'))
  WITH CHECK (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));
CREATE POLICY staff_delete ON public.staff
  FOR DELETE TO authenticated
  USING (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));

-- teachers: admin and owner have identical school-scoped CRUD rights.
DROP POLICY IF EXISTS teachers_delete ON public.teachers;
DROP POLICY IF EXISTS teachers_insert ON public.teachers;
DROP POLICY IF EXISTS teachers_owner_delete ON public.teachers;
DROP POLICY IF EXISTS teachers_owner_insert ON public.teachers;
DROP POLICY IF EXISTS teachers_owner_update ON public.teachers;
DROP POLICY IF EXISTS teachers_update ON public.teachers;
CREATE POLICY teachers_insert ON public.teachers
  FOR INSERT TO authenticated
  WITH CHECK (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));
CREATE POLICY teachers_update ON public.teachers
  FOR UPDATE TO authenticated
  USING (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'))
  WITH CHECK (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));
CREATE POLICY teachers_delete ON public.teachers
  FOR DELETE TO authenticated
  USING (school_id=(SELECT private.my_school()) AND (SELECT private.my_role()) IN ('admin','owner'));

-- Remove the duplicate index; keep the same (school_id, created_at DESC) index.
DROP INDEX IF EXISTS public.audit_log_school_idx;

CREATE INDEX IF NOT EXISTS student_extra_charges_academic_year_idx ON public.student_extra_charges(academic_year_id);
CREATE INDEX IF NOT EXISTS student_extra_charges_school_idx ON public.student_extra_charges(school_id);
CREATE INDEX IF NOT EXISTS student_extra_charges_student_idx ON public.student_extra_charges(student_id);
CREATE INDEX IF NOT EXISTS student_payment_installments_school_idx ON public.student_payment_installments(school_id);
CREATE INDEX IF NOT EXISTS student_payment_plans_academic_year_idx ON public.student_payment_plans(academic_year_id);
CREATE INDEX IF NOT EXISTS student_payment_plans_school_idx ON public.student_payment_plans(school_id);
CREATE INDEX IF NOT EXISTS student_payment_plans_student_idx ON public.student_payment_plans(student_id);
CREATE INDEX IF NOT EXISTS teacher_academic_year_records_academic_year_idx ON public.teacher_academic_year_records(academic_year_id);
CREATE INDEX IF NOT EXISTS teacher_academic_year_records_teacher_idx ON public.teacher_academic_year_records(teacher_id);

COMMIT;
