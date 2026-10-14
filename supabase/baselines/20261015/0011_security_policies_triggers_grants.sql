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
