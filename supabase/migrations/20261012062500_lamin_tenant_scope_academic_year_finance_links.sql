-- Keep academic-year links tenant-scoped and prevent deletion of years that own financial history.
-- Preflight on 2026-10-12 found zero cross-school mismatches in these links.
ALTER TABLE public.student_opening_balances
  DROP CONSTRAINT IF EXISTS student_opening_balances_academic_year_id_fkey;
ALTER TABLE public.student_opening_balances
  ADD CONSTRAINT opening_balances_target_year_school_fk
  FOREIGN KEY (academic_year_id, school_id)
  REFERENCES public.academic_years (id, school_id)
  ON DELETE RESTRICT;

ALTER TABLE public.student_opening_balances
  DROP CONSTRAINT IF EXISTS student_opening_balances_source_year_fk;
ALTER TABLE public.student_opening_balances
  ADD CONSTRAINT opening_balances_source_year_school_fk
  FOREIGN KEY (source_academic_year_id, school_id)
  REFERENCES public.academic_years (id, school_id)
  ON DELETE RESTRICT;

ALTER TABLE public.payments
  DROP CONSTRAINT IF EXISTS payments_academic_year_id_fkey;
ALTER TABLE public.payments
  ADD CONSTRAINT payments_academic_year_school_fk
  FOREIGN KEY (academic_year_id, school_id)
  REFERENCES public.academic_years (id, school_id)
  ON DELETE RESTRICT;

ALTER TABLE public.fee_schedules
  DROP CONSTRAINT IF EXISTS fee_schedules_academic_year_id_fkey;
ALTER TABLE public.fee_schedules
  ADD CONSTRAINT fee_schedules_academic_year_school_fk
  FOREIGN KEY (academic_year_id, school_id)
  REFERENCES public.academic_years (id, school_id)
  ON DELETE RESTRICT;
