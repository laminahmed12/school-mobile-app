-- REBUILT historical migration 001_core_tables for Lamīn.
-- Reconstructed from the catalog-derived current-state baseline, NOT recovered original SQL.
-- Creates schemas, sequences and tables only. No application records.
-- Generated 2026-10-19; clean-database bootstrap path only.

-- Lamīn baseline candidate, stage 1: schemas, sequences, and table columns.
-- Generated 2026-10-15 UTC from read-only Supabase PostgreSQL catalogs (stbrhcgzfxvpayfnnqfl).
-- Schema-only; no school, student, user, or financial records are included.
-- New baseline candidate, not the missing historical migration. Apply only to an isolated empty database.
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS extensions;
SET search_path = public, extensions, pg_catalog;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- Create all application tables before adding cyclic foreign keys.

CREATE TABLE public.academic_years (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  starts_on date,
  ends_on date,
  active boolean NOT NULL,
  created_at timestamp with time zone NOT NULL,
  closed_at timestamp with time zone,
  is_closed boolean NOT NULL
);

CREATE TABLE public.attendance (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  attendance_date date NOT NULL,
  status text NOT NULL,
  minutes_late integer NOT NULL,
  note text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  school_id uuid NOT NULL,
  user_id uuid,
  username text,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id text,
  details jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.backup_registry (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  provider text NOT NULL,
  drive_item_id text,
  file_name text NOT NULL,
  last_uploaded_at timestamp with time zone,
  checksum text,
  version integer NOT NULL,
  created_at timestamp with time zone NOT NULL,
  updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.class_subjects (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  teacher_id uuid,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.classes (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  section text NOT NULL,
  academic_year_id uuid,
  created_at timestamp with time zone NOT NULL,
  grade_order integer
);

CREATE TABLE public.discount_rules (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  rule_type text NOT NULL,
  value_type text NOT NULL,
  value numeric(12,2) NOT NULL,
  max_amount numeric(12,2),
  stacking_policy text NOT NULL,
  cap_amount numeric(12,2),
  conditions jsonb NOT NULL,
  active boolean NOT NULL,
  starts_on date,
  ends_on date,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  updated_at timestamp with time zone NOT NULL,
  updated_by uuid
);

CREATE TABLE public.expenses (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  title text NOT NULL,
  category text NOT NULL,
  amount numeric NOT NULL,
  note text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL,
  academic_year_id uuid
);

CREATE TABLE public.fee_schedules (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  grade_order integer NOT NULL,
  term text NOT NULL,
  amount numeric(12,2) NOT NULL,
  due_date date,
  active boolean NOT NULL,
  note text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  updated_at timestamp with time zone NOT NULL,
  updated_by uuid
);

CREATE TABLE public.financial_adjustments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  fee_assessment_id uuid,
  adjustment_type text NOT NULL,
  amount numeric(12,2) NOT NULL,
  reason text NOT NULL,
  status text NOT NULL,
  source_adjustment_id uuid,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  updated_at timestamp with time zone NOT NULL,
  updated_by uuid,
  approved_at timestamp with time zone,
  approved_by uuid
);

CREATE TABLE public.grades (
  student_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  school_id uuid NOT NULL,
  score numeric(5,2) NOT NULL,
  academic_year_id uuid
);

CREATE TABLE public.license_codes (
  id uuid NOT NULL,
  code_hash text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  used_at timestamp with time zone,
  used_school_id uuid,
  school_id uuid
);

CREATE TABLE public.login_attempts (
  key text NOT NULL,
  fails integer NOT NULL,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.onedrive_access_audit (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  target_user_id uuid NOT NULL,
  target_username text NOT NULL,
  action text NOT NULL,
  permission_id text,
  performed_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.owner_gate_attempts (
  gate_key text NOT NULL,
  window_started_at timestamp with time zone NOT NULL,
  attempts integer NOT NULL,
  updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.payment_allocations (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  payment_id uuid NOT NULL,
  fee_assessment_id uuid,
  opening_balance_id uuid,
  amount numeric(12,2) NOT NULL,
  allocated_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  reversed_at timestamp with time zone,
  reversed_by uuid,
  reversal_reason text
);

CREATE TABLE public.payments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  amount numeric(14,2) NOT NULL,
  note text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL,
  academic_year_id uuid,
  fee_assessment_id uuid,
  term text NOT NULL,
  payment_date date NOT NULL,
  updated_at timestamp with time zone NOT NULL,
  updated_by uuid,
  idempotency_key text
);

CREATE TABLE public.payroll_periods (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  status text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  closed_at timestamp with time zone,
  closed_by uuid
);

CREATE TABLE public.payroll_transactions (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  payee_type text NOT NULL,
  payee_id uuid NOT NULL,
  transaction_type text NOT NULL,
  amount numeric(12,2) NOT NULL,
  payment_date date NOT NULL,
  note text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.profiles (
  user_id uuid NOT NULL,
  school_id uuid,
  username text NOT NULL,
  role text NOT NULL,
  active boolean NOT NULL,
  must_change_password boolean NOT NULL,
  created_at timestamp with time zone NOT NULL,
  microsoft_email text,
  onedrive_access_granted boolean NOT NULL,
  onedrive_permission_id text,
  onedrive_granted_at timestamp with time zone,
  onedrive_revoked_at timestamp with time zone
);

CREATE TABLE public.rollover_batches (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  source_academic_year_id uuid NOT NULL,
  target_academic_year_id uuid NOT NULL,
  status text NOT NULL,
  preview jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  updated_at timestamp with time zone NOT NULL,
  updated_by uuid,
  approved_at timestamp with time zone,
  approved_by uuid,
  completed_at timestamp with time zone,
  error_summary text
);

CREATE TABLE public.rollover_items (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  batch_id uuid NOT NULL,
  student_id uuid NOT NULL,
  source_enrollment_id uuid,
  target_enrollment_id uuid,
  decision text NOT NULL,
  source_class_id uuid,
  target_class_id uuid,
  source_balance numeric(12,2) NOT NULL,
  opening_balance_id uuid,
  created_at timestamp with time zone NOT NULL,
  created_by uuid,
  reviewed boolean NOT NULL,
  reviewed_by uuid,
  reviewed_at timestamp with time zone
);

CREATE TABLE public.salary_assignments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  payee_type text NOT NULL,
  payee_id uuid NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency text NOT NULL,
  starts_on date NOT NULL,
  ends_on date,
  note text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  created_by uuid
);

CREATE TABLE public.school_branding (
  school_id uuid NOT NULL,
  logo_data text,
  logo_mime_type text,
  updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.schools (
  id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  currency text NOT NULL,
  country_code text NOT NULL,
  licensed boolean NOT NULL,
  created_at timestamp with time zone NOT NULL,
  trial_started_at timestamp with time zone,
  license_activated_at timestamp with time zone,
  license_code_id uuid,
  active boolean NOT NULL
);

CREATE TABLE public.staff (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  role text NOT NULL,
  phone text NOT NULL,
  salary numeric NOT NULL,
  active boolean NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.staff_payments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  note text NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.student_behavior (
  student_id uuid NOT NULL,
  school_id uuid NOT NULL,
  absences integer NOT NULL,
  lates integer NOT NULL,
  discipline text NOT NULL,
  notes text NOT NULL,
  updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.student_discount_awards (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  fee_assessment_id uuid NOT NULL,
  discount_rule_id uuid,
  rule_snapshot jsonb NOT NULL,
  amount numeric(12,2) NOT NULL,
  reason text NOT NULL,
  status text NOT NULL,
  requested_by uuid,
  created_at timestamp with time zone NOT NULL,
  updated_by uuid,
  updated_at timestamp with time zone NOT NULL,
  approved_by uuid,
  approved_at timestamp with time zone,
  reversed_by uuid,
  reversed_at timestamp with time zone,
  created_by uuid
);

CREATE TABLE public.student_enrollments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  class_id uuid,
  status text NOT NULL,
  source_student_id uuid,
  promoted_from_enrollment_id uuid,
  created_at timestamp with time zone NOT NULL,
  result_status text NOT NULL
);

CREATE TABLE public.student_fee_assessments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  academic_year_id uuid,
  academic_year_label text NOT NULL,
  term text NOT NULL,
  total_fee numeric(12,2) NOT NULL,
  discount numeric(12,2) NOT NULL,
  due_date date,
  note text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL,
  manual_discount numeric(12,2) NOT NULL
);

CREATE TABLE public.student_fees (
  student_id uuid NOT NULL,
  school_id uuid NOT NULL,
  total_fee numeric(14,2) NOT NULL,
  discount numeric NOT NULL,
  due_date date,
  note text NOT NULL,
  academic_year_id uuid
);

CREATE TABLE public.student_opening_balances (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  amount numeric NOT NULL,
  note text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  source_academic_year_id uuid,
  source_fee_assessment_id uuid,
  created_by uuid,
  updated_at timestamp with time zone NOT NULL,
  updated_by uuid,
  rollover_batch_id uuid
);

CREATE TABLE public.student_parents (
  student_id uuid NOT NULL,
  school_id uuid NOT NULL,
  parent_name text NOT NULL,
  phone text NOT NULL,
  relation text NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.student_results (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  subject_id uuid,
  term text NOT NULL,
  exam_name text NOT NULL,
  score numeric NOT NULL,
  max_score numeric NOT NULL,
  note text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL,
  academic_year_id uuid
);

CREATE TABLE public.students (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  class_name text NOT NULL,
  phone text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  active boolean NOT NULL,
  status text NOT NULL,
  current_academic_year_id uuid
);

CREATE TABLE public.subjects (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.teachers (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  subject text NOT NULL,
  phone text NOT NULL,
  created_at timestamp with time zone NOT NULL,
  salary numeric(12,2) NOT NULL
);

CREATE TABLE public.user_deletion_audit (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  target_user_id uuid NOT NULL,
  target_username text NOT NULL,
  target_role text NOT NULL,
  deleted_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.whatsapp_notifications (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid,
  kind text NOT NULL,
  message text NOT NULL,
  phone text NOT NULL,
  sent boolean NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL
);
