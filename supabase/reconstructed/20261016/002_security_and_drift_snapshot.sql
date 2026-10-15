-- Lamīn reconstructed security and drift bridge, 2026-10-16.
-- NOT original historical SQL. Disposable clean-install testing only.
-- Apply after supabase/reconstructed/20261016/001_schema_snapshot.sql.
-- Never apply to production or use to rewrite migration history.

-- ===== Source baseline stage 0011 =====
-- Lamīn baseline candidate, stage 11: RLS, policies, triggers, and privileges.
-- Captured 2026-10-15 UTC from read-only PostgreSQL catalogs on stbrhcgzfxvpayfnnqfl.
-- No application data is included. Apply only after stages 0001-0010.
-- Supabase-managed roles and auth schema must exist in the target environment.

-- Enable RLS as observed in the live catalog.

ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.license_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onedrive_access_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_gate_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rollover_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rollover_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_behavior ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_discount_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fee_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_opening_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_deletion_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_notifications ENABLE ROW LEVEL SECURITY;

-- Exact policy expressions from pg_policies.

CREATE POLICY academic_years_write ON public.academic_years AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY attendance_write ON public.attendance AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY audit_select ON public.audit_log AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY backup_registry_delete ON public.backup_registry AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY backup_registry_insert ON public.backup_registry AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY backup_registry_select ON public.backup_registry AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = private.my_school()));

CREATE POLICY backup_registry_update ON public.backup_registry AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK ((school_id = private.my_school()));

CREATE POLICY class_subjects_write ON public.class_subjects AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY classes_write ON public.classes AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY lamin_discount_rules_delete ON public.discount_rules AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_discount_rules_insert ON public.discount_rules AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_discount_rules_select ON public.discount_rules AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_discount_rules_update ON public.discount_rules AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY expenses_delete ON public.expenses AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY expenses_insert ON public.expenses AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY expenses_select ON public.expenses AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY expenses_update ON public.expenses AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY lamin_fee_schedules_delete ON public.fee_schedules AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_fee_schedules_insert ON public.fee_schedules AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_fee_schedules_select ON public.fee_schedules AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_fee_schedules_update ON public.fee_schedules AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_financial_adjustments_insert ON public.financial_adjustments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_financial_adjustments_select ON public.financial_adjustments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_financial_adjustments_update ON public.financial_adjustments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY grades_delete ON public.grades AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY grades_insert ON public.grades AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY grades_select ON public.grades AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY grades_update ON public.grades AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY onedrive_access_audit_insert ON public.onedrive_access_audit AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY onedrive_access_audit_select ON public.onedrive_access_audit AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_payment_allocations_insert ON public.payment_allocations AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_payment_allocations_select ON public.payment_allocations AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_payment_allocations_update ON public.payment_allocations AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY payments_delete ON public.payments AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY payments_insert ON public.payments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY payments_select ON public.payments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_payroll_periods_select ON public.payroll_periods AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_payroll_periods_write ON public.payroll_periods AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY payroll_transactions_delete ON public.payroll_transactions AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY payroll_transactions_insert ON public.payroll_transactions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])) AND (created_by = ( SELECT auth.uid() AS uid))));

CREATE POLICY payroll_transactions_select ON public.payroll_transactions AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY payroll_transactions_update ON public.payroll_transactions AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY profiles_select ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR ((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)) OR (( SELECT private.my_role() AS my_role) = 'owner'::text)));

CREATE POLICY lamin_rollover_batches_insert ON public.rollover_batches AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_rollover_batches_select ON public.rollover_batches AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_rollover_batches_update ON public.rollover_batches AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_rollover_items_insert ON public.rollover_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_rollover_items_select ON public.rollover_items AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_rollover_items_update ON public.rollover_items AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY lamin_salary_assignments_insert ON public.salary_assignments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_salary_assignments_select ON public.salary_assignments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_salary_assignments_update ON public.salary_assignments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY school_branding_insert_admin ON public.school_branding AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY school_branding_select_same_school ON public.school_branding AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) OR (( SELECT private.my_role() AS my_role) = 'owner'::text)));

CREATE POLICY school_branding_update_admin ON public.school_branding AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY schools_owner_delete ON public.schools AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT private.my_role() AS my_role) = 'owner'::text));

CREATE POLICY schools_owner_insert ON public.schools AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT private.my_role() AS my_role) = 'owner'::text));

CREATE POLICY schools_owner_update ON public.schools AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT private.my_role() AS my_role) = 'owner'::text)) WITH CHECK ((( SELECT private.my_role() AS my_role) = 'owner'::text));

CREATE POLICY schools_select ON public.schools AS PERMISSIVE FOR SELECT TO authenticated USING (((id = ( SELECT private.my_school() AS my_school)) OR (( SELECT private.my_role() AS my_role) = 'owner'::text)));

CREATE POLICY staff_select ON public.staff AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY staff_write ON public.staff AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY staff_payments_write ON public.staff_payments AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY behavior_insert ON public.student_behavior AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY behavior_select ON public.student_behavior AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY behavior_update ON public.student_behavior AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY lamin_discount_awards_insert ON public.student_discount_awards AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])) AND (status = 'pending'::text) AND ((requested_by IS NULL) OR (requested_by = ( SELECT auth.uid() AS uid))) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY lamin_discount_awards_read ON public.student_discount_awards AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY lamin_discount_awards_update ON public.student_discount_awards AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY student_enrollments_delete ON public.student_enrollments AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY student_enrollments_insert ON public.student_enrollments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY student_enrollments_select ON public.student_enrollments AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = private.my_school()));

CREATE POLICY student_enrollments_update ON public.student_enrollments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text])))) WITH CHECK ((school_id = private.my_school()));

CREATE POLICY student_fee_assessments_delete ON public.student_fee_assessments AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text]))));

CREATE POLICY student_fee_assessments_insert ON public.student_fee_assessments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])) AND ((created_by IS NULL) OR (created_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY student_fee_assessments_select ON public.student_fee_assessments AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY student_fee_assessments_update ON public.student_fee_assessments AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text])))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text]))));

CREATE POLICY fees_insert ON public.student_fees AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY fees_select ON public.student_fees AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'accountant'::text]))));

CREATE POLICY fees_update ON public.student_fees AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY opening_balances_delete ON public.student_opening_balances AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY opening_balances_insert ON public.student_opening_balances AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text]))));

CREATE POLICY opening_balances_select ON public.student_opening_balances AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = private.my_school()));

CREATE POLICY opening_balances_update ON public.student_opening_balances AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text])))) WITH CHECK ((school_id = private.my_school()));

CREATE POLICY student_parents_write ON public.student_parents AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY student_results_write ON public.student_results AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text]))));

CREATE POLICY students_delete ON public.students AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY students_insert ON public.students AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY students_select ON public.students AS PERMISSIVE FOR SELECT TO authenticated USING ((school_id = ( SELECT private.my_school() AS my_school)));

CREATE POLICY students_update ON public.students AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY subjects_delete ON public.subjects AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY subjects_insert ON public.subjects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY subjects_select ON public.subjects AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'supervisor'::text]))));

CREATE POLICY teachers_delete ON public.teachers AS PERMISSIVE FOR DELETE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY teachers_insert ON public.teachers AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY teachers_select ON public.teachers AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = ANY (ARRAY['admin'::text, 'owner'::text, 'accountant'::text, 'supervisor'::text]))));

CREATE POLICY teachers_update ON public.teachers AS PERMISSIVE FOR UPDATE TO authenticated USING (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text))) WITH CHECK (((school_id = ( SELECT private.my_school() AS my_school)) AND (( SELECT private.my_role() AS my_role) = 'admin'::text)));

CREATE POLICY user_deletion_audit_insert ON public.user_deletion_audit AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY user_deletion_audit_select ON public.user_deletion_audit AS PERMISSIVE FOR SELECT TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['owner'::text, 'admin'::text]))));

CREATE POLICY whatsapp_write ON public.whatsapp_notifications AS PERMISSIVE FOR ALL TO authenticated USING (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text, 'accountant'::text])))) WITH CHECK (((school_id = private.my_school()) AND (private.my_role() = ANY (ARRAY['admin'::text, 'owner'::text, 'supervisor'::text, 'accountant'::text]))));

-- User-defined triggers.

CREATE TRIGGER trg_audit_attendance AFTER INSERT OR UPDATE ON attendance FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON discount_rules FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON discount_rules FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER trg_audit_expenses AFTER INSERT OR DELETE OR UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON fee_schedules FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON fee_schedules FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON financial_adjustments FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON financial_adjustments FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON payment_allocations FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_validate_payment_allocation BEFORE INSERT OR UPDATE ON payment_allocations FOR EACH ROW EXECUTE FUNCTION lamin_validate_payment_allocation();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER trg_audit_payments AFTER INSERT OR DELETE ON payments FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER trg_check_payment BEFORE INSERT ON payments FOR EACH ROW EXECUTE FUNCTION private.check_payment();
CREATE TRIGGER payroll_transaction_validate_recipient BEFORE INSERT OR UPDATE OF school_id, payee_type, payee_id ON payroll_transactions FOR EACH ROW EXECUTE FUNCTION private.validate_payroll_transaction();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON rollover_batches FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_guard_rollover_year_state BEFORE INSERT OR UPDATE OF status ON rollover_batches FOR EACH ROW EXECUTE FUNCTION lamin_guard_rollover_year_state();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON rollover_batches FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON rollover_items FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER schools_normalize_code BEFORE INSERT OR UPDATE OF code ON schools FOR EACH ROW EXECUTE FUNCTION normalize_school_code();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_sync_award_discount AFTER INSERT OR DELETE OR UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_sync_award_discount();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER lamin_validate_discount_award BEFORE INSERT OR UPDATE ON student_discount_awards FOR EACH ROW EXECUTE FUNCTION lamin_validate_discount_award();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON student_fee_assessments FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_capture_manual_discount BEFORE INSERT OR UPDATE OF discount ON student_fee_assessments FOR EACH ROW EXECUTE FUNCTION lamin_capture_manual_discount();
CREATE TRIGGER trg_audit_fees AFTER INSERT OR UPDATE ON student_fees FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER trg_check_fee BEFORE UPDATE ON student_fees FOR EACH ROW EXECUTE FUNCTION private.check_fee();
CREATE TRIGGER lamin_audit_row AFTER INSERT OR DELETE OR UPDATE ON student_opening_balances FOR EACH ROW EXECUTE FUNCTION lamin_write_audit_event();
CREATE TRIGGER lamin_updated_at BEFORE UPDATE ON student_opening_balances FOR EACH ROW EXECUTE FUNCTION lamin_set_updated_at();
CREATE TRIGGER trg_audit_students AFTER INSERT OR DELETE OR UPDATE ON students FOR EACH ROW EXECUTE FUNCTION private.audit();
CREATE TRIGGER trg_audit_teachers AFTER INSERT OR DELETE ON teachers FOR EACH ROW EXECUTE FUNCTION private.audit();

-- Schema privileges.

GRANT USAGE ON SCHEMA extensions TO anon;
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT CREATE ON SCHEMA extensions TO dashboard_user;
GRANT USAGE ON SCHEMA extensions TO dashboard_user;
GRANT USAGE ON SCHEMA extensions TO service_role;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT USAGE ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO service_role;

-- Explicit table, view, and sequence privileges.

-- Supabase projects can apply broader default table ACLs at CREATE TABLE time.
-- Reset anon/authenticated table ACLs, then replay the catalog-derived grants below,
-- so a fresh Supabase project matches the captured reference rather than inheriting extras.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.academic_years TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.academic_years TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.attendance TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.attendance TO service_role;
GRANT SELECT ON TABLE public.audit_log TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.audit_log TO service_role;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.audit_log_id_seq TO anon;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.audit_log_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.audit_log_id_seq TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.backup_registry TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.backup_registry TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.backup_registry TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.class_subjects TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.class_subjects TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.classes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.classes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.discount_rules TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.discount_rules TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.discount_rules TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.expenses TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.expenses TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fee_schedules TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fee_schedules TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.fee_schedules TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.financial_adjustments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.financial_adjustments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.financial_adjustments TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.grades TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.grades TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.license_codes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.login_attempts TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.onedrive_access_audit TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.onedrive_access_audit TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.onedrive_access_audit TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.owner_gate_attempts TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payment_allocations TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payment_allocations TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payment_allocations TO service_role;
GRANT DELETE, INSERT, SELECT ON TABLE public.payments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payments TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_periods TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_periods TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_periods TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_transactions TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_transactions TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.payroll_transactions TO service_role;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_batches TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_batches TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_batches TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_items TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_items TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rollover_items TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salary_assignments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salary_assignments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.salary_assignments TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.school_branding TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.school_branding TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.school_branding TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.schools TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.schools TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.staff TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.staff TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.staff_payments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.staff_payments TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.student_behavior TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_behavior TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_discount_awards TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_discount_awards TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_discount_awards TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_enrollments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_enrollments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_enrollments TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fee_assessments TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fee_assessments TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fee_assessments TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.student_fees TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_fees TO service_role;
GRANT SELECT ON TABLE public.student_finance TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_finance TO service_role;
GRANT SELECT ON TABLE public.student_financial_summary TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_financial_summary TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_opening_balances TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_opening_balances TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_opening_balances TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.student_parents TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_parents TO service_role;
GRANT SELECT ON TABLE public.student_result_summary TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_result_summary TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.student_results TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.student_results TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.students TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.students TO service_role;
GRANT DELETE, INSERT, SELECT ON TABLE public.subjects TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.subjects TO service_role;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.teachers TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.teachers TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_deletion_audit TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_deletion_audit TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_deletion_audit TO service_role;
GRANT DELETE, INSERT, MAINTAIN, SELECT, UPDATE ON TABLE public.whatsapp_notifications TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.whatsapp_notifications TO service_role;

-- Reset default PUBLIC EXECUTE ACLs, then restore only catalog-observed grants.
REVOKE ALL ON FUNCTION private.audit() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.check_fee() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.check_payment() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.my_role() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.my_school() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.restore_school_data(p jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.validate_payroll_transaction() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.attendance_summary(p_date date) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.bootstrap_owner_school(p_code text, p_name text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.carry_forward_open_balances(p_old_year uuid, p_new_year uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.delete_school_user(p_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.execute_academic_rollover(p_batch_id uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup_core_v2(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup_core_v3(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.export_backup_core_v4(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.import_students(p_rows jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_capture_manual_discount() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_guard_rollover_year_state() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_set_updated_at() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_sync_award_discount() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_validate_discount_award() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_validate_payment_allocation() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lamin_write_audit_event() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.license_trial_status(p_school uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.normalize_school_code() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.owner_stats() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.promote_passed_students(p_old_year uuid, p_new_year uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.redeem_license_code(p_school_id uuid, p_code_hash text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup_core_v2(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup_core_v3(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_backup_core_v4(p_backup jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.save_attendance_day(p_date date, p_rows jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.school_daily_summary(p_date date) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_student_promotion(p_student_id uuid, p_target_class_id uuid, p_status text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric) FROM PUBLIC, anon, authenticated, service_role;

-- Routine execute privileges.

GRANT EXECUTE ON FUNCTION private.my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION private.my_school() TO authenticated;
GRANT EXECUTE ON FUNCTION private.validate_payroll_transaction() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_student(p_name text, p_class text, p_phone text, p_fee numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.attendance_summary(p_date date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_summary(p_date date) TO service_role;
GRANT EXECUTE ON FUNCTION public.bootstrap_owner_school(p_code text, p_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_owner_school(p_code text, p_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.carry_forward_open_balances(p_old_year uuid, p_new_year uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_next_academic_year(p_name text, p_starts_on date, p_ends_on date, p_migrate_students boolean, p_migrate_staff boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_student_with_fee(p_name text, p_class_name text, p_phone text, p_term_fee numeric, p_term text) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_school_user(p_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_school_user(p_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.execute_academic_rollover(p_batch_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.execute_academic_rollover(p_batch_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup(p_school uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.export_backup(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup_core_v2(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup_core_v3(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.export_backup_core_v4(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text) TO service_role;
GRANT EXECUTE ON FUNCTION public.import_students(p_rows jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.import_students(p_rows jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_capture_manual_discount() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_guard_rollover_year_state() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_set_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.lamin_set_updated_at() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_sync_award_discount() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_validate_discount_award() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_validate_payment_allocation() TO service_role;
GRANT EXECUTE ON FUNCTION public.lamin_write_audit_event() TO service_role;
GRANT EXECUTE ON FUNCTION public.license_trial_status(p_school uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.license_trial_status(p_school uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO anon;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_school_code() TO service_role;
GRANT EXECUTE ON FUNCTION public.owner_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_stats() TO service_role;
GRANT EXECUTE ON FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.promote_passed_students(p_old_year uuid, p_new_year uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_student_payment(p_student_id uuid, p_amount numeric, p_note text, p_term text, p_fee_assessment_id uuid, p_idempotency_key text) TO service_role;
GRANT EXECUTE ON FUNCTION public.redeem_license_code(p_school_id uuid, p_code_hash text) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup(p_backup jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_backup(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup_core_v2(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup_core_v3(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup_core_v4(p_backup jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text) TO service_role;
GRANT EXECUTE ON FUNCTION public.save_attendance_day(p_date date, p_rows jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_attendance_day(p_date date, p_rows jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_report(p_student uuid, p_grades jsonb, p_absences integer, p_lates integer, p_discipline text, p_notes text) TO service_role;
GRANT EXECUTE ON FUNCTION public.school_daily_summary(p_date date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.school_daily_summary(p_date date) TO service_role;
GRANT EXECUTE ON FUNCTION public.set_student_promotion(p_student_id uuid, p_target_class_id uuid, p_status text) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_student(p_id uuid, p_name text, p_class text, p_phone text, p_fee numeric) TO service_role;

-- Default privileges for objects created later.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO service_role;


-- ===== Source baseline stage 0012 =====
-- Lamīn post-baseline drift reconciliation, stage 12.
-- This is a deliberately selective replay of verified repository deltas absent from the live production catalog.
-- It is NOT the historical migration chain and must not be applied to production as a migration repair.
-- Apply only after the catalog-derived base passes exact schema fingerprint comparison in an isolated database.
-- Verified differences addressed:
-- 1) rollover preview must calculate outstanding debt from allocations (formula version 2).
-- 2) rollover execution must close only its source year and activate only its target year.
-- 3) owners need explicit school-scoped teacher insert/update/delete policies.

-- Selected verified source delta: supabase/migrations/20261013190000_lamin_rollover_balance_from_allocations.sql
-- 2026-10-13 (Libya time, UTC+02:00).
-- Correct rollover balance calculation to follow the allocation ledger.
-- This migration is additive and does not rewrite existing financial records.
create or replace function public.prepare_academic_rollover(p_source_year uuid,p_target_year uuid)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); v_batch uuid; r record; v_balance numeric(12,2); v_decision text; v_target_class uuid;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'إعداد الترحيل متاح لمدير المدرسة فقط'; end if;
 if p_source_year=p_target_year then raise exception 'يجب اختيار سنتين مختلفتين'; end if;
 if not exists(select 1 from public.academic_years where id=p_source_year and school_id=sid) then raise exception 'السنة المصدر غير صحيحة'; end if;
 if not exists(select 1 from public.academic_years where id=p_target_year and school_id=sid and coalesce(is_closed,false)=false) then raise exception 'السنة الهدف غير صحيحة أو مغلقة'; end if;
 if exists(select 1 from public.rollover_batches where school_id=sid and source_academic_year_id=p_source_year and target_academic_year_id=p_target_year and status='completed') then raise exception 'تم ترحيل هاتين السنتين سابقاً'; end if;
 select id into v_batch from public.rollover_batches where school_id=sid and source_academic_year_id=p_source_year and target_academic_year_id=p_target_year and status in ('draft','reviewed') order by created_at desc limit 1;
 if v_batch is not null then
  -- Never reuse an old preview after the ledger formula changes. Preserve its
  -- history by cancelling only batches that have no reviewed items; reviewed
  -- batches require an explicit human resolution rather than silent replacement.
  if exists(select 1 from public.rollover_items where batch_id=v_batch and reviewed) then
   raise exception 'توجد معاينة ترحيل سابقة تمت مراجعتها؛ أوقفها وراجع قراراتها قبل إنشاء معاينة جديدة';
  end if;
  update public.rollover_batches set status='cancelled',
   error_summary='Superseded by allocation-ledger balance formula v2; no reviewed items were changed',
   updated_by=auth.uid()
  where id=v_batch and school_id=sid and status in ('draft','reviewed');
  v_batch:=null;
 end if;
 insert into public.rollover_batches(school_id,source_academic_year_id,target_academic_year_id,status,created_by) values(sid,p_source_year,p_target_year,'draft',auth.uid()) returning id into v_batch;
 for r in select e.id enrollment_id,e.student_id,e.class_id,e.result_status,c.grade_order,c.section from public.student_enrollments e left join public.classes c on c.id=e.class_id and c.school_id=sid where e.school_id=sid and e.academic_year_id=p_source_year order by e.created_at,e.student_id loop
  v_decision:=case when r.result_status='passed' then 'promote' when r.result_status='failed' then 'repeat' when r.result_status in ('graduated','graduate') then 'graduate' when r.result_status in ('transferred','transfer') then 'transfer' else 'exclude' end;
  v_target_class:=null;
  if v_decision in ('promote','repeat') and r.grade_order is not null then
   select c2.id into v_target_class from public.classes c2 where c2.school_id=sid and (c2.academic_year_id=p_target_year or c2.academic_year_id is null)
    and c2.grade_order=case when v_decision='promote' then r.grade_order+1 else r.grade_order end and (r.section is null or r.section='' or c2.section=r.section)
    order by (c2.academic_year_id=p_target_year) desc,c2.created_at desc limit 1;
  end if;
  -- Carry debt by its actual obligations and active allocations, not by subtracting
  -- every payment in the year (a payment may have paid a prior-year opening balance).
  -- Legacy payments with no allocations are only applied to their explicitly linked assessment.
  select
    coalesce((
      select sum(greatest(ob.amount - coalesce((
        select sum(pa.amount) from public.payment_allocations pa
        where pa.opening_balance_id=ob.id and pa.reversed_at is null
      ),0),0))
      from public.student_opening_balances ob
      where ob.school_id=sid and ob.student_id=r.student_id and ob.academic_year_id=p_source_year
    ),0)
    + coalesce((
      select sum(greatest(f.total_fee-f.discount
        - coalesce((select sum(pa.amount) from public.payment_allocations pa
          where pa.fee_assessment_id=f.id and pa.reversed_at is null),0)
        - coalesce((select sum(p.amount) from public.payments p
          where p.school_id=sid and p.student_id=r.student_id
            and p.fee_assessment_id=f.id and p.academic_year_id=p_source_year
            and not exists(select 1 from public.payment_allocations pa
              where pa.payment_id=p.id)),0),0))
      from public.student_fee_assessments f
      where f.school_id=sid and f.student_id=r.student_id and f.academic_year_id=p_source_year
    ),0)
    into v_balance;
  insert into public.rollover_items(school_id,batch_id,student_id,source_enrollment_id,decision,source_class_id,target_class_id,source_balance,created_by,reviewed)
  values(sid,v_batch,r.student_id,r.enrollment_id,v_decision,r.class_id,v_target_class,v_balance,auth.uid(),false);
 end loop;
 update public.rollover_batches set preview=jsonb_build_object('balance_formula_version',2,
  'student_count',(select count(*) from public.rollover_items where batch_id=v_batch),
  'total_opening_balance',(select coalesce(sum(source_balance),0) from public.rollover_items where batch_id=v_batch),
  'needs_class',(select count(*) from public.rollover_items where batch_id=v_batch and decision in ('promote','repeat') and target_class_id is null),
  'needs_review',(select count(*) from public.rollover_items where batch_id=v_batch and not reviewed)) where id=v_batch;
 return v_batch;
end
$function$;

-- Block execution of rollover previews created under the older, payment-total formula.
create or replace function public.lamin_guard_rollover_year_state()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if TG_OP='INSERT' or NEW.status='running' then
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.source_academic_year_id and ay.school_id=NEW.school_id and ay.active=true and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة المصدر يجب أن تكون السنة النشطة غير المغلقة';
  end if;
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.target_academic_year_id and ay.school_id=NEW.school_id and ay.active=false and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة الهدف يجب أن تكون سنة غير نشطة وغير مغلقة';
  end if;
  if NEW.status='running' and coalesce(NEW.preview->>'balance_formula_version','')<>'2' then
   raise exception 'معاينة الترحيل قديمة؛ أعد إعداد المعاينة ومراجعة جميع الطلاب قبل التنفيذ';
  end if;
 end if;
 return NEW;
end $function$;
revoke all on function public.lamin_guard_rollover_year_state() from public,anon,authenticated;

-- Selected verified source delta: supabase/migrations/20261014050000_fix_academic_rollover_year_closing.sql
-- Close only the source academic year during rollover.
-- Do not accidentally close other future/planned academic years for the school.
create or replace function public.execute_academic_rollover(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  sid uuid := private.my_school();
  v_role text := private.my_role();
  b record;
  i record;
  v_enrollment uuid;
  v_balance_id uuid;
  v_students integer := 0;
  v_balances integer := 0;
begin
  if sid is null or v_role not in ('owner','admin') then
    raise exception 'تنفيذ الترحيل متاح لمدير المدرسة فقط';
  end if;

  select * into b
  from public.rollover_batches
  where id = p_batch_id and school_id = sid
  for update;

  if not found then raise exception 'عملية الترحيل غير موجودة'; end if;
  if b.status = 'completed' then
    return jsonb_build_object('ok', true, 'already_completed', true, 'message', 'تم تنفيذ هذه العملية سابقاً.');
  end if;
  if b.status not in ('draft','reviewed','approved') then
    raise exception 'حالة عملية الترحيل لا تسمح بالتنفيذ';
  end if;

  if not exists (
    select 1 from public.academic_years
    where id = b.source_academic_year_id and school_id = sid
      and active = true and coalesce(is_closed, false) = false
  ) or not exists (
    select 1 from public.academic_years
    where id = b.target_academic_year_id and school_id = sid
      and active = false and coalesce(is_closed, false) = false
  ) then
    raise exception 'تغيرت حالة إحدى السنتين منذ إعداد المعاينة؛ أعد المراجعة';
  end if;

  if exists (
    select 1 from public.rollover_items
    where batch_id = p_batch_id and not reviewed
  ) then raise exception 'راجع قرار كل طالب قبل تنفيذ الترحيل'; end if;

  if exists (
    select 1 from public.rollover_items
    where batch_id = p_batch_id and decision in ('promote','repeat')
      and target_class_id is null
  ) then raise exception 'يجب تحديد الصف الهدف لكل طالب ناجح أو راسب قبل التنفيذ'; end if;

  if exists (
    select 1 from public.rollover_items ri
    join public.classes c on c.id = ri.target_class_id
    where ri.batch_id = p_batch_id and ri.decision in ('promote','repeat')
      and c.school_id <> sid
  ) then raise exception 'يوجد صف هدف خارج المدرسة'; end if;

  if exists (
    select 1 from public.rollover_items ri
    join public.classes c on c.id = ri.target_class_id
    where ri.batch_id = p_batch_id and ri.decision in ('promote','repeat')
      and c.academic_year_id is not null
      and c.academic_year_id <> b.target_academic_year_id
  ) then raise exception 'الصف الهدف لا ينتمي للسنة الجديدة'; end if;

  if exists (
    select 1 from public.student_opening_balances ob
    join public.rollover_items ri on ri.student_id = ob.student_id
    where ri.batch_id = p_batch_id
      and ob.academic_year_id = b.target_academic_year_id
      and ob.rollover_batch_id is distinct from p_batch_id
  ) then raise exception 'توجد أرصدة افتتاحية مسبقة للسنة الهدف؛ راجعها قبل الترحيل لمنع تكرار الدين'; end if;

  update public.rollover_batches
  set status = 'running',
      approved_at = coalesce(approved_at, now()),
      approved_by = coalesce(approved_by, auth.uid()),
      updated_by = auth.uid()
  where id = p_batch_id;

  for i in
    select * from public.rollover_items
    where batch_id = p_batch_id order by student_id
  loop
    if i.decision in ('promote','repeat') then
      select e.id into v_enrollment
      from public.student_enrollments e
      where e.school_id = sid and e.student_id = i.student_id
        and e.academic_year_id = b.target_academic_year_id;

      if v_enrollment is not null then
        if not exists (
          select 1 from public.student_enrollments e
          where e.id = v_enrollment
            and e.promoted_from_enrollment_id = i.source_enrollment_id
        ) then raise exception 'يوجد تسجيل سابق مختلف للطالب في السنة الهدف'; end if;
      else
        insert into public.student_enrollments(
          school_id, student_id, academic_year_id, class_id, status,
          source_student_id, promoted_from_enrollment_id, result_status
        ) values (
          sid, i.student_id, b.target_academic_year_id, i.target_class_id,
          'active', i.student_id, i.source_enrollment_id, 'pending'
        ) returning id into v_enrollment;
        v_students := v_students + 1;
      end if;

      update public.students
      set current_academic_year_id = b.target_academic_year_id,
          active = true, status = 'active'
      where id = i.student_id and school_id = sid;

      update public.rollover_items
      set target_enrollment_id = v_enrollment
      where id = i.id;
    elsif i.decision = 'graduate' then
      update public.students set active = false, status = 'graduated'
      where id = i.student_id and school_id = sid;
    elsif i.decision = 'transfer' then
      update public.students set active = false, status = 'transferred'
      where id = i.student_id and school_id = sid;
    end if;
  end loop;

  for i in
    select * from public.rollover_items
    where batch_id = p_batch_id and source_balance > 0
    order by student_id
  loop
    if i.opening_balance_id is not null then continue; end if;

    insert into public.student_opening_balances(
      school_id, student_id, academic_year_id, source_academic_year_id,
      rollover_batch_id, amount, note, created_by
    ) values (
      sid, i.student_id, b.target_academic_year_id, b.source_academic_year_id,
      p_batch_id, i.source_balance, 'رصيد مرحّل معتمد من السنة السابقة', auth.uid()
    ) on conflict(student_id, academic_year_id) do nothing;

    select ob.id into v_balance_id
    from public.student_opening_balances ob
    where ob.school_id = sid and ob.student_id = i.student_id
      and ob.academic_year_id = b.target_academic_year_id;

    if v_balance_id is null then raise exception 'تعذر إنشاء الرصيد الافتتاحي'; end if;

    update public.rollover_items set opening_balance_id = v_balance_id
    where id = i.id;
    v_balances := v_balances + 1;
  end loop;

  -- Only close the source year for this rollover. Preserve any other
  -- inactive/unclosed future year that the school has already prepared.
  update public.academic_years
  set active = false, is_closed = true, closed_at = now()
  where school_id = sid and id = b.source_academic_year_id;

  update public.academic_years
  set active = true, is_closed = false, closed_at = null
  where id = b.target_academic_year_id and school_id = sid;

  update public.rollover_batches
  set status = 'completed', completed_at = now(), updated_by = auth.uid(),
      preview = preview || jsonb_build_object(
        'created_enrollments', v_students, 'opening_balances', v_balances
      )
  where id = p_batch_id;

  return jsonb_build_object(
    'ok', true, 'created_enrollments', v_students,
    'opening_balances', v_balances,
    'message', 'اكتمل الترحيل وتم إقفال السنة المصدر فقط.'
  );
end
$function$;

-- Selected verified source delta: supabase/migrations/20261014030000_allow_owner_teacher_management.sql
-- Allow school owners as well as admins to maintain teacher records.
-- Existing school-scoped SELECT policy remains unchanged.
drop policy if exists teachers_owner_insert on public.teachers;
create policy teachers_owner_insert on public.teachers
  for insert to authenticated
  with check (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

drop policy if exists teachers_owner_update on public.teachers;
create policy teachers_owner_update on public.teachers
  for update to authenticated
  using (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  )
  with check (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

drop policy if exists teachers_owner_delete on public.teachers;
create policy teachers_owner_delete on public.teachers
  for delete to authenticated
  using (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );


