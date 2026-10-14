-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
create index if not exists financial_adjustments_source_adjustment_idx on public.financial_adjustments(source_adjustment_id);
create index if not exists financial_adjustments_student_fk_idx on public.financial_adjustments(student_id,school_id);
create index if not exists financial_adjustments_year_fk_idx on public.financial_adjustments(academic_year_id,school_id);
create index if not exists payment_allocations_payment_fk_idx on public.payment_allocations(payment_id,school_id,student_id);
create index if not exists rollover_batches_source_year_fk_idx on public.rollover_batches(source_academic_year_id,school_id);
create index if not exists rollover_batches_target_year_fk_idx on public.rollover_batches(target_academic_year_id,school_id);
create index if not exists rollover_items_school_idx on public.rollover_items(school_id);
create index if not exists rollover_items_opening_balance_fk_idx on public.rollover_items(opening_balance_id,school_id,student_id);
create index if not exists rollover_items_source_class_fk_idx on public.rollover_items(source_class_id,school_id);
create index if not exists rollover_items_target_class_fk_idx on public.rollover_items(target_class_id,school_id);
create index if not exists rollover_items_source_enrollment_fk_idx on public.rollover_items(source_enrollment_id,school_id,student_id);
create index if not exists rollover_items_target_enrollment_fk_idx on public.rollover_items(target_enrollment_id,school_id,student_id);
create index if not exists rollover_items_student_fk_idx on public.rollover_items(student_id,school_id);
create index if not exists student_fee_assessments_year_id_idx on public.student_fee_assessments(academic_year_id);
create index if not exists audit_log_school_created_idx on public.audit_log(school_id,created_at desc);
