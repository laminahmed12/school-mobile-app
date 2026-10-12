-- Scope opening-balance provenance to the same school and student.
-- Preflight on 2026-10-12 found zero mismatches for both relationships.
ALTER TABLE public.student_opening_balances
  DROP CONSTRAINT IF EXISTS student_opening_balances_source_assessment_fk;
ALTER TABLE public.student_opening_balances
  ADD CONSTRAINT opening_balances_source_assessment_school_student_fk
  FOREIGN KEY (source_fee_assessment_id, school_id, student_id)
  REFERENCES public.student_fee_assessments (id, school_id, student_id)
  ON DELETE RESTRICT;

ALTER TABLE public.student_opening_balances
  DROP CONSTRAINT IF EXISTS student_opening_balances_rollover_batch_fk;
ALTER TABLE public.student_opening_balances
  ADD CONSTRAINT opening_balances_rollover_batch_school_fk
  FOREIGN KEY (rollover_batch_id, school_id)
  REFERENCES public.rollover_batches (id, school_id)
  ON DELETE RESTRICT;
