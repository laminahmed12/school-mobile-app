-- REBUILT historical migration 001_core_tables for Lamīn.
-- Reconstructed from the catalog-derived current-state baseline, NOT recovered original SQL.
-- Intended for clean database bootstrap only; do not replay against an existing production database.
-- Generated 2026-10-19. Schema-only; no application records.

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


-- Catalog-derived constraints, indexes, defaults, and views.
-- Lamīn baseline candidate, stage 10: defaults, constraints, indexes and views.
-- Captured 2026-10-15 UTC from read-only catalog queries on stbrhcgzfxvpayfnnqfl.
-- No application data is included. Apply only after 0001 and 0002-0009 routines.

ALTER TABLE public.academic_years ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.academic_years ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.academic_years ALTER COLUMN active SET DEFAULT false;
ALTER TABLE public.academic_years ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.academic_years ALTER COLUMN is_closed SET DEFAULT false;
ALTER TABLE public.attendance ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.attendance ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.attendance ALTER COLUMN attendance_date SET DEFAULT CURRENT_DATE;
ALTER TABLE public.attendance ALTER COLUMN minutes_late SET DEFAULT 0;
ALTER TABLE public.attendance ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.attendance ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.attendance ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.audit_log ALTER COLUMN details SET DEFAULT '{}'::jsonb;
ALTER TABLE public.audit_log ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.backup_registry ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.backup_registry ALTER COLUMN provider SET DEFAULT 'onedrive'::text;
ALTER TABLE public.backup_registry ALTER COLUMN version SET DEFAULT 1;
ALTER TABLE public.backup_registry ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.backup_registry ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.class_subjects ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.class_subjects ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.class_subjects ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.classes ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.classes ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.classes ALTER COLUMN section SET DEFAULT ''::text;
ALTER TABLE public.classes ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.discount_rules ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.discount_rules ALTER COLUMN stacking_policy SET DEFAULT 'max_only'::text;
ALTER TABLE public.discount_rules ALTER COLUMN conditions SET DEFAULT '{}'::jsonb;
ALTER TABLE public.discount_rules ALTER COLUMN active SET DEFAULT true;
ALTER TABLE public.discount_rules ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.discount_rules ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.discount_rules ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.expenses ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.expenses ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.expenses ALTER COLUMN category SET DEFAULT 'عام'::text;
ALTER TABLE public.expenses ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.expenses ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.expenses ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.fee_schedules ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.fee_schedules ALTER COLUMN active SET DEFAULT true;
ALTER TABLE public.fee_schedules ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.fee_schedules ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.fee_schedules ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.fee_schedules ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.financial_adjustments ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.financial_adjustments ALTER COLUMN status SET DEFAULT 'pending'::text;
ALTER TABLE public.financial_adjustments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.financial_adjustments ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.financial_adjustments ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.license_codes ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.license_codes ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.login_attempts ALTER COLUMN fails SET DEFAULT 0;
ALTER TABLE public.login_attempts ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.onedrive_access_audit ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.onedrive_access_audit ALTER COLUMN performed_by SET DEFAULT auth.uid();
ALTER TABLE public.onedrive_access_audit ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.owner_gate_attempts ALTER COLUMN window_started_at SET DEFAULT now();
ALTER TABLE public.owner_gate_attempts ALTER COLUMN attempts SET DEFAULT 0;
ALTER TABLE public.owner_gate_attempts ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.payment_allocations ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.payment_allocations ALTER COLUMN allocated_at SET DEFAULT now();
ALTER TABLE public.payment_allocations ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.payment_allocations ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.payments ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.payments ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.payments ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.payments ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.payments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.payments ALTER COLUMN term SET DEFAULT 'غير محدد'::text;
ALTER TABLE public.payments ALTER COLUMN payment_date SET DEFAULT CURRENT_DATE;
ALTER TABLE public.payments ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.payroll_periods ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.payroll_periods ALTER COLUMN status SET DEFAULT 'open'::text;
ALTER TABLE public.payroll_periods ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.payroll_periods ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.payroll_transactions ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.payroll_transactions ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.payroll_transactions ALTER COLUMN payment_date SET DEFAULT CURRENT_DATE;
ALTER TABLE public.payroll_transactions ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.payroll_transactions ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.payroll_transactions ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.profiles ALTER COLUMN active SET DEFAULT true;
ALTER TABLE public.profiles ALTER COLUMN must_change_password SET DEFAULT true;
ALTER TABLE public.profiles ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.profiles ALTER COLUMN onedrive_access_granted SET DEFAULT false;
ALTER TABLE public.rollover_batches ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.rollover_batches ALTER COLUMN status SET DEFAULT 'draft'::text;
ALTER TABLE public.rollover_batches ALTER COLUMN preview SET DEFAULT '{}'::jsonb;
ALTER TABLE public.rollover_batches ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.rollover_batches ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.rollover_batches ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.rollover_items ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.rollover_items ALTER COLUMN source_balance SET DEFAULT 0;
ALTER TABLE public.rollover_items ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.rollover_items ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.rollover_items ALTER COLUMN reviewed SET DEFAULT false;
ALTER TABLE public.salary_assignments ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.salary_assignments ALTER COLUMN currency SET DEFAULT 'LYD'::text;
ALTER TABLE public.salary_assignments ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.salary_assignments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.salary_assignments ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.school_branding ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.schools ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.schools ALTER COLUMN currency SET DEFAULT 'د.ل'::text;
ALTER TABLE public.schools ALTER COLUMN country_code SET DEFAULT '218'::text;
ALTER TABLE public.schools ALTER COLUMN licensed SET DEFAULT false;
ALTER TABLE public.schools ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.schools ALTER COLUMN active SET DEFAULT true;
ALTER TABLE public.staff ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.staff ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.staff ALTER COLUMN role SET DEFAULT 'موظف'::text;
ALTER TABLE public.staff ALTER COLUMN phone SET DEFAULT ''::text;
ALTER TABLE public.staff ALTER COLUMN salary SET DEFAULT 0;
ALTER TABLE public.staff ALTER COLUMN active SET DEFAULT true;
ALTER TABLE public.staff ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.staff_payments ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.staff_payments ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.staff_payments ALTER COLUMN payment_date SET DEFAULT CURRENT_DATE;
ALTER TABLE public.staff_payments ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.staff_payments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.student_behavior ALTER COLUMN absences SET DEFAULT 0;
ALTER TABLE public.student_behavior ALTER COLUMN lates SET DEFAULT 0;
ALTER TABLE public.student_behavior ALTER COLUMN discipline SET DEFAULT ''::text;
ALTER TABLE public.student_behavior ALTER COLUMN notes SET DEFAULT ''::text;
ALTER TABLE public.student_behavior ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.student_discount_awards ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.student_discount_awards ALTER COLUMN rule_snapshot SET DEFAULT '{}'::jsonb;
ALTER TABLE public.student_discount_awards ALTER COLUMN status SET DEFAULT 'pending'::text;
ALTER TABLE public.student_discount_awards ALTER COLUMN requested_by SET DEFAULT auth.uid();
ALTER TABLE public.student_discount_awards ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.student_discount_awards ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.student_discount_awards ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.student_enrollments ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.student_enrollments ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.student_enrollments ALTER COLUMN status SET DEFAULT 'active'::text;
ALTER TABLE public.student_enrollments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.student_enrollments ALTER COLUMN result_status SET DEFAULT 'pending'::text;
ALTER TABLE public.student_fee_assessments ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.student_fee_assessments ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.student_fee_assessments ALTER COLUMN academic_year_label SET DEFAULT 'غير محدد'::text;
ALTER TABLE public.student_fee_assessments ALTER COLUMN term SET DEFAULT 'الفصل الأول'::text;
ALTER TABLE public.student_fee_assessments ALTER COLUMN total_fee SET DEFAULT 0;
ALTER TABLE public.student_fee_assessments ALTER COLUMN discount SET DEFAULT 0;
ALTER TABLE public.student_fee_assessments ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.student_fee_assessments ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.student_fee_assessments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.student_fee_assessments ALTER COLUMN manual_discount SET DEFAULT 0;
ALTER TABLE public.student_fees ALTER COLUMN discount SET DEFAULT 0;
ALTER TABLE public.student_fees ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.student_opening_balances ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.student_opening_balances ALTER COLUMN note SET DEFAULT 'رصيد مرحّل من السنة السابقة'::text;
ALTER TABLE public.student_opening_balances ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.student_opening_balances ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.student_opening_balances ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.student_parents ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.student_parents ALTER COLUMN parent_name SET DEFAULT ''::text;
ALTER TABLE public.student_parents ALTER COLUMN phone SET DEFAULT ''::text;
ALTER TABLE public.student_parents ALTER COLUMN relation SET DEFAULT 'ولي الأمر'::text;
ALTER TABLE public.student_parents ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.student_results ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.student_results ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.student_results ALTER COLUMN term SET DEFAULT 'الفصل الأول'::text;
ALTER TABLE public.student_results ALTER COLUMN exam_name SET DEFAULT 'اختبار'::text;
ALTER TABLE public.student_results ALTER COLUMN max_score SET DEFAULT 100;
ALTER TABLE public.student_results ALTER COLUMN note SET DEFAULT ''::text;
ALTER TABLE public.student_results ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.student_results ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.students ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.students ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.students ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.students ALTER COLUMN active SET DEFAULT true;
ALTER TABLE public.students ALTER COLUMN status SET DEFAULT 'active'::text;
ALTER TABLE public.subjects ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.subjects ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.subjects ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.teachers ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.teachers ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.teachers ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.teachers ALTER COLUMN salary SET DEFAULT 0;
ALTER TABLE public.user_deletion_audit ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.user_deletion_audit ALTER COLUMN deleted_by SET DEFAULT auth.uid();
ALTER TABLE public.user_deletion_audit ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.whatsapp_notifications ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.whatsapp_notifications ALTER COLUMN school_id SET DEFAULT private.my_school();
ALTER TABLE public.whatsapp_notifications ALTER COLUMN phone SET DEFAULT ''::text;
ALTER TABLE public.whatsapp_notifications ALTER COLUMN sent SET DEFAULT false;
ALTER TABLE public.whatsapp_notifications ALTER COLUMN created_by SET DEFAULT auth.uid();
ALTER TABLE public.whatsapp_notifications ALTER COLUMN created_at SET DEFAULT now();

-- Primary, unique, and check constraints first so all referenced keys exist.

-- Non-foreign-key constraints (phase 1).

ALTER TABLE public.academic_years ADD CONSTRAINT academic_years_name_check CHECK (char_length(btrim(name)) >= 3 AND char_length(btrim(name)) <= 60);
ALTER TABLE public.academic_years ADD CONSTRAINT academic_years_pkey PRIMARY KEY (id);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_minutes_late_check CHECK (minutes_late >= 0 AND minutes_late <= 600);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_note_check CHECK (char_length(note) <= 300);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_status_check CHECK (status = ANY (ARRAY['present'::text, 'absent'::text, 'late'::text, 'excused'::text]));
ALTER TABLE public.attendance ADD CONSTRAINT attendance_student_id_attendance_date_key UNIQUE (student_id, attendance_date);
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);
ALTER TABLE public.backup_registry ADD CONSTRAINT backup_registry_pkey PRIMARY KEY (id);
ALTER TABLE public.backup_registry ADD CONSTRAINT backup_registry_school_id_academic_year_id_provider_key UNIQUE (school_id, academic_year_id, provider);
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_class_id_subject_id_key UNIQUE (class_id, subject_id);
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_pkey PRIMARY KEY (id);
ALTER TABLE public.classes ADD CONSTRAINT classes_name_check CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 60);
ALTER TABLE public.classes ADD CONSTRAINT classes_pkey PRIMARY KEY (id);
ALTER TABLE public.classes ADD CONSTRAINT classes_section_check CHECK (char_length(section) <= 30);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_cap_ck CHECK (cap_amount IS NULL OR cap_amount >= 0::numeric);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_dates_ck CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_id_school_uq UNIQUE (id, school_id);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_max_ck CHECK (max_amount IS NULL OR max_amount >= 0::numeric);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_name_check CHECK (length(TRIM(BOTH FROM name)) >= 1 AND length(TRIM(BOTH FROM name)) <= 120);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_percent_ck CHECK (value_type <> 'percent'::text OR value <= 100::numeric);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_pkey PRIMARY KEY (id);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_rule_type_check CHECK (rule_type = ANY (ARRAY['sibling'::text, 'category'::text, 'scholarship'::text, 'manual'::text, 'other'::text]));
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_stacking_policy_check CHECK (stacking_policy = ANY (ARRAY['stack'::text, 'max_only'::text]));
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_value_check CHECK (value >= 0::numeric);
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_value_type_check CHECK (value_type = ANY (ARRAY['fixed'::text, 'percent'::text]));
ALTER TABLE public.expenses ADD CONSTRAINT expenses_amount_check CHECK (amount > 0::numeric);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_category_check CHECK (char_length(category) <= 50);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_note_check CHECK (char_length(note) <= 300);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_title_check CHECK (char_length(btrim(title)) >= 1 AND char_length(btrim(title)) <= 120);
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_amount_check CHECK (amount >= 0::numeric);
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_grade_order_check CHECK (grade_order >= 0);
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_id_school_uq UNIQUE (id, school_id);
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_pkey PRIMARY KEY (id);
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_school_year_grade_term_uq UNIQUE (school_id, academic_year_id, grade_order, term);
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_term_check CHECK (length(TRIM(BOTH FROM term)) >= 1 AND length(TRIM(BOTH FROM term)) <= 80);
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_adjustment_type_check CHECK (adjustment_type = ANY (ARRAY['waiver'::text, 'charge'::text, 'refund'::text, 'reversal'::text, 'correction'::text, 'other'::text]));
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_amount_check CHECK (amount > 0::numeric);
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_pkey PRIMARY KEY (id);
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_reason_check CHECK (length(TRIM(BOTH FROM reason)) >= 1 AND length(TRIM(BOTH FROM reason)) <= 500);
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_status_check CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'reversed'::text]));
ALTER TABLE public.grades ADD CONSTRAINT grades_pkey PRIMARY KEY (student_id, subject_id);
ALTER TABLE public.grades ADD CONSTRAINT grades_score_check CHECK (score >= 0::numeric AND score <= 100::numeric);
ALTER TABLE public.license_codes ADD CONSTRAINT license_codes_code_hash_key UNIQUE (code_hash);
ALTER TABLE public.license_codes ADD CONSTRAINT license_codes_pkey PRIMARY KEY (id);
ALTER TABLE public.login_attempts ADD CONSTRAINT login_attempts_pkey PRIMARY KEY (key);

ALTER TABLE public.onedrive_access_audit ADD CONSTRAINT onedrive_access_audit_action_check CHECK (action = ANY (ARRAY['grant'::text, 'revoke'::text, 'auto_revoke'::text]));
ALTER TABLE public.onedrive_access_audit ADD CONSTRAINT onedrive_access_audit_pkey PRIMARY KEY (id);
ALTER TABLE public.owner_gate_attempts ADD CONSTRAINT owner_gate_attempts_pkey PRIMARY KEY (gate_key);
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_amount_check CHECK (amount > 0::numeric);
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_one_target_ck CHECK (((fee_assessment_id IS NOT NULL)::integer + (opening_balance_id IS NOT NULL)::integer) = 1);
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_pkey PRIMARY KEY (id);
ALTER TABLE public.payments ADD CONSTRAINT payments_amount_check CHECK (amount > 0::numeric);
ALTER TABLE public.payments ADD CONSTRAINT payments_note_check CHECK (char_length(note) <= 200);
ALTER TABLE public.payments ADD CONSTRAINT payments_pkey PRIMARY KEY (id);
ALTER TABLE public.payroll_periods ADD CONSTRAINT payroll_periods_dates_ck CHECK (ends_on >= starts_on);
ALTER TABLE public.payroll_periods ADD CONSTRAINT payroll_periods_pkey PRIMARY KEY (id);
ALTER TABLE public.payroll_periods ADD CONSTRAINT payroll_periods_school_name_uq UNIQUE (school_id, name);
ALTER TABLE public.payroll_periods ADD CONSTRAINT payroll_periods_status_check CHECK (status = ANY (ARRAY['open'::text, 'closed'::text]));
ALTER TABLE public.payroll_transactions ADD CONSTRAINT payroll_transactions_amount_check CHECK (amount > 0::numeric);
ALTER TABLE public.payroll_transactions ADD CONSTRAINT payroll_transactions_payee_type_check CHECK (payee_type = ANY (ARRAY['teacher'::text, 'staff'::text]));
ALTER TABLE public.payroll_transactions ADD CONSTRAINT payroll_transactions_pkey PRIMARY KEY (id);
ALTER TABLE public.payroll_transactions ADD CONSTRAINT payroll_transactions_transaction_type_check CHECK (transaction_type = ANY (ARRAY['salary'::text, 'advance'::text]));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_onedrive_role_chk CHECK (NOT onedrive_access_granted OR (role = ANY (ARRAY['accountant'::text, 'supervisor'::text])));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_owner_scope CHECK ((role = 'owner'::text) = (school_id IS NULL));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (user_id);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role = ANY (ARRAY['owner'::text, 'admin'::text, 'accountant'::text, 'supervisor'::text]));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_check CHECK (char_length(btrim(username)) >= 2 AND char_length(btrim(username)) <= 40);
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_batches_id_school_uq UNIQUE (id, school_id);
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_batches_pkey PRIMARY KEY (id);
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_batches_status_check CHECK (status = ANY (ARRAY['draft'::text, 'reviewed'::text, 'approved'::text, 'running'::text, 'completed'::text, 'failed'::text, 'cancelled'::text]));
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_distinct_years_ck CHECK (source_academic_year_id <> target_academic_year_id);
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_batch_student_uq UNIQUE (batch_id, student_id);
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_decision_check CHECK (decision = ANY (ARRAY['promote'::text, 'repeat'::text, 'graduate'::text, 'transfer'::text, 'exclude'::text]));
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_pkey PRIMARY KEY (id);
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_source_balance_check CHECK (source_balance >= 0::numeric);
ALTER TABLE public.salary_assignments ADD CONSTRAINT salary_assignments_amount_check CHECK (amount >= 0::numeric);
ALTER TABLE public.salary_assignments ADD CONSTRAINT salary_assignments_dates_ck CHECK (ends_on IS NULL OR ends_on >= starts_on);
ALTER TABLE public.salary_assignments ADD CONSTRAINT salary_assignments_payee_type_check CHECK (payee_type = ANY (ARRAY['teacher'::text, 'staff'::text]));
ALTER TABLE public.salary_assignments ADD CONSTRAINT salary_assignments_pkey PRIMARY KEY (id);
ALTER TABLE public.school_branding ADD CONSTRAINT school_branding_logo_mime CHECK (logo_mime_type IS NULL OR (logo_mime_type = ANY (ARRAY['image/png'::text, 'image/jpeg'::text])));
ALTER TABLE public.school_branding ADD CONSTRAINT school_branding_logo_size CHECK (logo_data IS NULL OR length(logo_data) <= 1300000);
ALTER TABLE public.school_branding ADD CONSTRAINT school_branding_pkey PRIMARY KEY (school_id);
ALTER TABLE public.schools ADD CONSTRAINT schools_code_check CHECK (code ~ '^[a-z0-9]{3,20}$'::text);
ALTER TABLE public.schools ADD CONSTRAINT schools_code_format_chk CHECK (char_length(TRIM(BOTH FROM code)) >= 3 AND char_length(TRIM(BOTH FROM code)) <= 40 AND TRIM(BOTH FROM code) <> ''::text);
ALTER TABLE public.schools ADD CONSTRAINT schools_code_key UNIQUE (code);
ALTER TABLE public.schools ADD CONSTRAINT schools_country_code_check CHECK (country_code ~ '^[0-9]{1,4}$'::text);
ALTER TABLE public.schools ADD CONSTRAINT schools_currency_check CHECK (char_length(btrim(currency)) >= 1 AND char_length(btrim(currency)) <= 10);
ALTER TABLE public.schools ADD CONSTRAINT schools_name_check CHECK (char_length(btrim(name)) >= 3 AND char_length(btrim(name)) <= 80);
ALTER TABLE public.schools ADD CONSTRAINT schools_pkey PRIMARY KEY (id);
ALTER TABLE public.staff ADD CONSTRAINT staff_name_check CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 120);
ALTER TABLE public.staff ADD CONSTRAINT staff_pkey PRIMARY KEY (id);
ALTER TABLE public.staff ADD CONSTRAINT staff_salary_check CHECK (salary >= 0::numeric);
ALTER TABLE public.staff_payments ADD CONSTRAINT staff_payments_amount_check CHECK (amount > 0::numeric);
ALTER TABLE public.staff_payments ADD CONSTRAINT staff_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.student_behavior ADD CONSTRAINT student_behavior_absences_check CHECK (absences >= 0 AND absences <= 400);
ALTER TABLE public.student_behavior ADD CONSTRAINT student_behavior_discipline_check CHECK (discipline = ANY (ARRAY[''::text, 'ممتاز'::text, 'جيد'::text, 'مقبول'::text, 'يحتاج متابعة'::text]));
ALTER TABLE public.student_behavior ADD CONSTRAINT student_behavior_lates_check CHECK (lates >= 0 AND lates <= 400);
ALTER TABLE public.student_behavior ADD CONSTRAINT student_behavior_notes_check CHECK (char_length(notes) <= 1000);
ALTER TABLE public.student_behavior ADD CONSTRAINT student_behavior_pkey PRIMARY KEY (student_id);
ALTER TABLE public.student_discount_awards ADD CONSTRAINT student_discount_awards_amount_check CHECK (amount >= 0::numeric);
ALTER TABLE public.student_discount_awards ADD CONSTRAINT student_discount_awards_pkey PRIMARY KEY (id);
ALTER TABLE public.student_discount_awards ADD CONSTRAINT student_discount_awards_reason_check CHECK (length(TRIM(BOTH FROM reason)) >= 1 AND length(TRIM(BOTH FROM reason)) <= 500);
ALTER TABLE public.student_discount_awards ADD CONSTRAINT student_discount_awards_status_check CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'reversed'::text]));
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_pkey PRIMARY KEY (id);
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_student_id_academic_year_id_key UNIQUE (student_id, academic_year_id);
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_check CHECK (discount >= 0::numeric AND discount <= total_fee);
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_id_school_student_key UNIQUE (id, school_id, student_id);
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_pkey PRIMARY KEY (id);
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_total_fee_check CHECK (total_fee >= 0::numeric);
ALTER TABLE public.student_fees ADD CONSTRAINT student_fees_discount_check CHECK (discount >= 0::numeric);
ALTER TABLE public.student_fees ADD CONSTRAINT student_fees_pkey PRIMARY KEY (student_id);
ALTER TABLE public.student_fees ADD CONSTRAINT student_fees_total_fee_check CHECK (total_fee >= 0::numeric);
ALTER TABLE public.student_opening_balances ADD CONSTRAINT student_opening_balances_amount_check CHECK (amount >= 0::numeric);
ALTER TABLE public.student_opening_balances ADD CONSTRAINT student_opening_balances_pkey PRIMARY KEY (id);
ALTER TABLE public.student_opening_balances ADD CONSTRAINT student_opening_balances_student_id_academic_year_id_key UNIQUE (student_id, academic_year_id);
ALTER TABLE public.student_parents ADD CONSTRAINT student_parents_parent_name_check CHECK (char_length(parent_name) <= 100);
ALTER TABLE public.student_parents ADD CONSTRAINT student_parents_phone_check CHECK (phone = ''::text OR phone ~ '^[0-9]{8,15}$'::text);
ALTER TABLE public.student_parents ADD CONSTRAINT student_parents_pkey PRIMARY KEY (student_id);
ALTER TABLE public.student_parents ADD CONSTRAINT student_parents_relation_check CHECK (char_length(relation) <= 30);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_exam_name_check CHECK (char_length(exam_name) <= 100);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_max_score_check CHECK (max_score > 0::numeric);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_note_check CHECK (char_length(note) <= 300);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_pkey PRIMARY KEY (id);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_score_check CHECK (score >= 0::numeric);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_term_check CHECK (char_length(term) <= 50);
ALTER TABLE public.students ADD CONSTRAINT students_class_name_check CHECK (char_length(btrim(class_name)) >= 1 AND char_length(btrim(class_name)) <= 40);
ALTER TABLE public.students ADD CONSTRAINT students_id_school_uq UNIQUE (id, school_id);
ALTER TABLE public.students ADD CONSTRAINT students_name_check CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 100);
ALTER TABLE public.students ADD CONSTRAINT students_phone_check CHECK (phone ~ '^[0-9]{8,15}$'::text);
ALTER TABLE public.students ADD CONSTRAINT students_pkey PRIMARY KEY (id);
ALTER TABLE public.subjects ADD CONSTRAINT subjects_id_school_uq UNIQUE (id, school_id);
ALTER TABLE public.subjects ADD CONSTRAINT subjects_name_check CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 40);
ALTER TABLE public.subjects ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);
ALTER TABLE public.teachers ADD CONSTRAINT teachers_name_check CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 100);
ALTER TABLE public.teachers ADD CONSTRAINT teachers_phone_check CHECK (phone = ''::text OR phone ~ '^[0-9]{8,15}$'::text);
ALTER TABLE public.teachers ADD CONSTRAINT teachers_pkey PRIMARY KEY (id);
ALTER TABLE public.teachers ADD CONSTRAINT teachers_salary_check CHECK (salary >= 0::numeric);
ALTER TABLE public.teachers ADD CONSTRAINT teachers_subject_check CHECK (char_length(btrim(subject)) >= 1 AND char_length(btrim(subject)) <= 60);
ALTER TABLE public.user_deletion_audit ADD CONSTRAINT user_deletion_audit_pkey PRIMARY KEY (id);
ALTER TABLE public.whatsapp_notifications ADD CONSTRAINT whatsapp_notifications_kind_check CHECK (kind = ANY (ARRAY['absence'::text, 'late'::text, 'fee'::text, 'payment'::text, 'result'::text, 'announcement'::text]));
ALTER TABLE public.whatsapp_notifications ADD CONSTRAINT whatsapp_notifications_message_check CHECK (char_length(message) >= 1 AND char_length(message) <= 2000);
ALTER TABLE public.whatsapp_notifications ADD CONSTRAINT whatsapp_notifications_pkey PRIMARY KEY (id);

-- Non-constraint indexes, including standalone unique indexes referenced by foreign keys.

CREATE UNIQUE INDEX academic_years_id_school_unique ON public.academic_years USING btree (id, school_id);
CREATE UNIQUE INDEX academic_years_one_active_per_school_uq ON public.academic_years USING btree (school_id) WHERE (active = true);
CREATE UNIQUE INDEX academic_years_school_name_idx ON public.academic_years USING btree (school_id, name);
CREATE INDEX attendance_school_date_idx ON public.attendance USING btree (school_id, attendance_date);
CREATE INDEX attendance_student_school_idx ON public.attendance USING btree (student_id, school_id);
CREATE INDEX audit_log_school_created_idx ON public.audit_log USING btree (school_id, created_at DESC);
CREATE INDEX audit_log_school_idx ON public.audit_log USING btree (school_id, created_at DESC);
CREATE INDEX backup_registry_academic_year_idx ON public.backup_registry USING btree (academic_year_id);
CREATE INDEX class_subjects_school_class_idx ON public.class_subjects USING btree (school_id, class_id);
CREATE INDEX class_subjects_subject_idx ON public.class_subjects USING btree (subject_id);
CREATE INDEX class_subjects_teacher_idx ON public.class_subjects USING btree (teacher_id);
CREATE INDEX classes_academic_year_idx ON public.classes USING btree (academic_year_id);
CREATE UNIQUE INDEX classes_id_school_uq ON public.classes USING btree (id, school_id);
CREATE INDEX classes_school_idx ON public.classes USING btree (school_id);
CREATE INDEX classes_school_year_idx ON public.classes USING btree (school_id, academic_year_id);
CREATE INDEX discount_rules_school_idx ON public.discount_rules USING btree (school_id);
CREATE INDEX expenses_academic_year_idx ON public.expenses USING btree (academic_year_id);
CREATE INDEX expenses_school_created_idx ON public.expenses USING btree (school_id, created_at);
CREATE INDEX expenses_school_date_idx ON public.expenses USING btree (school_id, created_at DESC);
CREATE INDEX expenses_school_year_idx ON public.expenses USING btree (school_id, academic_year_id);
CREATE INDEX fee_schedules_school_idx ON public.fee_schedules USING btree (school_id);
CREATE INDEX fee_schedules_year_school_idx ON public.fee_schedules USING btree (academic_year_id, school_id);
CREATE INDEX financial_adjustments_assessment_fk_idx ON public.financial_adjustments USING btree (fee_assessment_id, school_id, student_id);
CREATE INDEX financial_adjustments_school_student_year_idx ON public.financial_adjustments USING btree (school_id, student_id, academic_year_id);
CREATE INDEX financial_adjustments_source_adjustment_idx ON public.financial_adjustments USING btree (source_adjustment_id);
CREATE INDEX financial_adjustments_student_fk_idx ON public.financial_adjustments USING btree (student_id, school_id);
CREATE INDEX financial_adjustments_year_fk_idx ON public.financial_adjustments USING btree (academic_year_id, school_id);
CREATE INDEX grades_academic_year_idx ON public.grades USING btree (academic_year_id);
CREATE INDEX grades_school_idx ON public.grades USING btree (school_id);
CREATE INDEX grades_school_student_idx ON public.grades USING btree (school_id, student_id);
CREATE INDEX grades_school_year_idx ON public.grades USING btree (school_id, academic_year_id);
CREATE INDEX grades_student_school_idx ON public.grades USING btree (student_id, school_id);
CREATE INDEX grades_subject_idx ON public.grades USING btree (subject_id, school_id);
CREATE INDEX idx_license_codes_unused ON public.license_codes USING btree (code_hash) WHERE (used_at IS NULL);
CREATE UNIQUE INDEX license_codes_one_unused_per_school_idx ON public.license_codes USING btree (school_id) WHERE ((school_id IS NOT NULL) AND (used_at IS NULL));
CREATE INDEX license_codes_school_idx ON public.license_codes USING btree (school_id);
CREATE INDEX license_codes_used_school_idx ON public.license_codes USING btree (used_school_id);

CREATE INDEX onedrive_access_audit_school_idx ON public.onedrive_access_audit USING btree (school_id);
CREATE INDEX owner_gate_attempts_updated_idx ON public.owner_gate_attempts USING btree (updated_at);
CREATE INDEX payment_allocations_assessment_fk_idx ON public.payment_allocations USING btree (fee_assessment_id, school_id, student_id);
CREATE INDEX payment_allocations_opening_fk_idx ON public.payment_allocations USING btree (opening_balance_id, school_id, student_id);
CREATE UNIQUE INDEX payment_allocations_payment_assessment_uq ON public.payment_allocations USING btree (payment_id, fee_assessment_id) WHERE ((fee_assessment_id IS NOT NULL) AND (reversed_at IS NULL));
CREATE INDEX payment_allocations_payment_fk_idx ON public.payment_allocations USING btree (payment_id, school_id, student_id);
CREATE UNIQUE INDEX payment_allocations_payment_opening_uq ON public.payment_allocations USING btree (payment_id, opening_balance_id) WHERE ((opening_balance_id IS NOT NULL) AND (reversed_at IS NULL));
CREATE INDEX payment_allocations_school_student_idx ON public.payment_allocations USING btree (school_id, student_id);
CREATE INDEX payments_academic_year_idx ON public.payments USING btree (academic_year_id);
CREATE INDEX payments_academic_year_school_fk_idx ON public.payments USING btree (academic_year_id, school_id);
CREATE INDEX payments_assessment_school_student_idx ON public.payments USING btree (fee_assessment_id, school_id, student_id);
CREATE UNIQUE INDEX payments_id_school_student_uq ON public.payments USING btree (id, school_id, student_id);
CREATE INDEX payments_school_created_idx ON public.payments USING btree (school_id, created_at);
CREATE UNIQUE INDEX payments_school_idempotency_key_uq ON public.payments USING btree (school_id, idempotency_key) WHERE (idempotency_key IS NOT NULL);
CREATE INDEX payments_school_idx ON public.payments USING btree (school_id);
CREATE INDEX payments_school_student_date_idx ON public.payments USING btree (school_id, student_id, payment_date DESC);
CREATE INDEX payments_school_year_idx ON public.payments USING btree (school_id, academic_year_id);
CREATE INDEX payments_student_idx ON public.payments USING btree (student_id);
CREATE INDEX payments_student_school_idx ON public.payments USING btree (student_id, school_id);
CREATE INDEX payroll_periods_school_dates_idx ON public.payroll_periods USING btree (school_id, starts_on, ends_on);
CREATE INDEX payroll_transactions_payee_idx ON public.payroll_transactions USING btree (school_id, payee_type, payee_id, payment_date DESC);
CREATE INDEX payroll_transactions_school_date_idx ON public.payroll_transactions USING btree (school_id, payment_date DESC);
CREATE UNIQUE INDEX profiles_owner_username_uq ON public.profiles USING btree (lower(username)) WHERE (school_id IS NULL);
CREATE INDEX profiles_school_idx ON public.profiles USING btree (school_id);
CREATE INDEX profiles_school_microsoft_email_idx ON public.profiles USING btree (school_id, microsoft_email);
CREATE UNIQUE INDEX profiles_school_username_uq ON public.profiles USING btree (school_id, lower(username)) WHERE (school_id IS NOT NULL);
CREATE INDEX rollover_batches_school_years_idx ON public.rollover_batches USING btree (school_id, source_academic_year_id, target_academic_year_id);
CREATE INDEX rollover_batches_source_year_fk_idx ON public.rollover_batches USING btree (source_academic_year_id, school_id);
CREATE INDEX rollover_batches_target_year_fk_idx ON public.rollover_batches USING btree (target_academic_year_id, school_id);
CREATE INDEX rollover_items_batch_school_idx ON public.rollover_items USING btree (batch_id, school_id);
CREATE INDEX rollover_items_opening_balance_fk_idx ON public.rollover_items USING btree (opening_balance_id, school_id, student_id);
CREATE INDEX rollover_items_school_idx ON public.rollover_items USING btree (school_id);
CREATE INDEX rollover_items_source_class_fk_idx ON public.rollover_items USING btree (source_class_id, school_id);
CREATE INDEX rollover_items_source_enrollment_fk_idx ON public.rollover_items USING btree (source_enrollment_id, school_id, student_id);
CREATE INDEX rollover_items_student_fk_idx ON public.rollover_items USING btree (student_id, school_id);
CREATE INDEX rollover_items_target_class_fk_idx ON public.rollover_items USING btree (target_class_id, school_id);
CREATE INDEX rollover_items_target_enrollment_fk_idx ON public.rollover_items USING btree (target_enrollment_id, school_id, student_id);
CREATE INDEX salary_assignments_payee_dates_idx ON public.salary_assignments USING btree (school_id, payee_type, payee_id, starts_on, ends_on);
CREATE UNIQUE INDEX schools_code_lower_uq ON public.schools USING btree (lower(TRIM(BOTH FROM code)));
CREATE INDEX schools_license_code_idx ON public.schools USING btree (license_code_id);
CREATE INDEX staff_school_idx ON public.staff USING btree (school_id);
CREATE INDEX staff_payments_school_staff_idx ON public.staff_payments USING btree (school_id, staff_id);
CREATE INDEX staff_payments_staff_idx ON public.staff_payments USING btree (staff_id);
CREATE INDEX student_behavior_school_idx ON public.student_behavior USING btree (school_id);
CREATE INDEX student_behavior_student_school_idx ON public.student_behavior USING btree (student_id, school_id);
CREATE INDEX discount_awards_assessment_school_student_idx ON public.student_discount_awards USING btree (fee_assessment_id, school_id, student_id);
CREATE INDEX discount_awards_rule_school_idx ON public.student_discount_awards USING btree (discount_rule_id, school_id);
CREATE INDEX discount_awards_school_idx ON public.student_discount_awards USING btree (school_id);
CREATE UNIQUE INDEX enrollments_id_school_student_uq ON public.student_enrollments USING btree (id, school_id, student_id);
CREATE INDEX student_enrollments_academic_year_idx ON public.student_enrollments USING btree (academic_year_id);
CREATE INDEX student_enrollments_class_idx ON public.student_enrollments USING btree (class_id);
CREATE INDEX student_enrollments_promoted_from_idx ON public.student_enrollments USING btree (promoted_from_enrollment_id);
CREATE INDEX student_enrollments_school_year_idx ON public.student_enrollments USING btree (school_id, academic_year_id);
CREATE INDEX student_enrollments_source_student_idx ON public.student_enrollments USING btree (source_student_id);
CREATE INDEX student_enrollments_student_idx ON public.student_enrollments USING btree (student_id);
CREATE UNIQUE INDEX student_fee_assessments_period_unique ON public.student_fee_assessments USING btree (student_id, school_id, COALESCE((academic_year_id)::text, ('label:'::text || academic_year_label)), term);
CREATE INDEX student_fee_assessments_school_student_idx ON public.student_fee_assessments USING btree (school_id, student_id);
CREATE INDEX student_fee_assessments_year_id_idx ON public.student_fee_assessments USING btree (academic_year_id);
CREATE INDEX student_fee_assessments_year_school_idx ON public.student_fee_assessments USING btree (academic_year_id, school_id);
CREATE INDEX student_fees_academic_year_idx ON public.student_fees USING btree (academic_year_id);
CREATE INDEX student_fees_school_idx ON public.student_fees USING btree (school_id);
CREATE INDEX student_fees_school_year_idx ON public.student_fees USING btree (school_id, academic_year_id);
CREATE INDEX student_fees_student_school_idx ON public.student_fees USING btree (student_id, school_id);
CREATE UNIQUE INDEX opening_balances_id_school_student_uq ON public.student_opening_balances USING btree (id, school_id, student_id);
CREATE INDEX opening_balances_rollover_batch_idx ON public.student_opening_balances USING btree (rollover_batch_id);
CREATE INDEX opening_balances_rollover_batch_school_fk_idx ON public.student_opening_balances USING btree (rollover_batch_id, school_id);
CREATE INDEX opening_balances_school_year_idx ON public.student_opening_balances USING btree (school_id, academic_year_id);
CREATE INDEX opening_balances_source_assessment_idx ON public.student_opening_balances USING btree (source_fee_assessment_id);
CREATE INDEX opening_balances_source_assessment_school_student_fk_idx ON public.student_opening_balances USING btree (source_fee_assessment_id, school_id, student_id);
CREATE INDEX opening_balances_source_year_idx ON public.student_opening_balances USING btree (source_academic_year_id);
CREATE INDEX opening_balances_source_year_school_fk_idx ON public.student_opening_balances USING btree (source_academic_year_id, school_id);
CREATE INDEX opening_balances_student_idx ON public.student_opening_balances USING btree (student_id);
CREATE INDEX opening_balances_target_year_school_fk_idx ON public.student_opening_balances USING btree (academic_year_id, school_id);
CREATE INDEX opening_balances_year_idx ON public.student_opening_balances USING btree (academic_year_id);
CREATE INDEX student_parents_school_idx ON public.student_parents USING btree (school_id);
CREATE INDEX student_parents_student_school_idx ON public.student_parents USING btree (student_id, school_id);
CREATE INDEX student_results_academic_year_idx ON public.student_results USING btree (academic_year_id);
CREATE INDEX student_results_school_student_idx ON public.student_results USING btree (school_id, student_id);
CREATE INDEX student_results_school_year_idx ON public.student_results USING btree (school_id, academic_year_id);
CREATE INDEX student_results_student_school_idx ON public.student_results USING btree (student_id, school_id);
CREATE INDEX student_results_subject_idx ON public.student_results USING btree (subject_id);
CREATE INDEX students_current_academic_year_idx ON public.students USING btree (current_academic_year_id);
CREATE UNIQUE INDEX students_dup_uq ON public.students USING btree (school_id, lower(name), phone);
CREATE INDEX students_school_idx ON public.students USING btree (school_id);
CREATE UNIQUE INDEX subjects_name_uq ON public.subjects USING btree (school_id, lower(name));
CREATE UNIQUE INDEX teachers_dup_uq ON public.teachers USING btree (school_id, lower(name), phone);
CREATE INDEX teachers_school_idx ON public.teachers USING btree (school_id);
CREATE INDEX user_deletion_audit_school_idx ON public.user_deletion_audit USING btree (school_id);
CREATE INDEX whatsapp_notifications_school_idx ON public.whatsapp_notifications USING btree (school_id);
CREATE INDEX whatsapp_notifications_student_school_idx ON public.whatsapp_notifications USING btree (student_id, school_id);

-- Foreign keys after unique constraints and supporting indexes.
ALTER TABLE public.academic_years ADD CONSTRAINT academic_years_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.attendance ADD CONSTRAINT attendance_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.attendance ADD CONSTRAINT attendance_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.backup_registry ADD CONSTRAINT backup_registry_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE;
ALTER TABLE public.backup_registry ADD CONSTRAINT backup_registry_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE;
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE;
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE SET NULL;
ALTER TABLE public.classes ADD CONSTRAINT classes_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE SET NULL;
ALTER TABLE public.classes ADD CONSTRAINT classes_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.discount_rules ADD CONSTRAINT discount_rules_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.expenses ADD CONSTRAINT expenses_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_academic_year_school_fk FOREIGN KEY (academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.fee_schedules ADD CONSTRAINT fee_schedules_year_school_fk FOREIGN KEY (academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_assessment_fk FOREIGN KEY (fee_assessment_id, school_id, student_id) REFERENCES student_fee_assessments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_source_adjustment_id_fkey FOREIGN KEY (source_adjustment_id) REFERENCES financial_adjustments(id) ON DELETE RESTRICT;
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_student_fk FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.financial_adjustments ADD CONSTRAINT financial_adjustments_year_fk FOREIGN KEY (academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.grades ADD CONSTRAINT grades_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);
ALTER TABLE public.grades ADD CONSTRAINT grades_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.grades ADD CONSTRAINT grades_subject_id_school_id_fkey FOREIGN KEY (subject_id, school_id) REFERENCES subjects(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.license_codes ADD CONSTRAINT license_codes_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE SET NULL;
ALTER TABLE public.license_codes ADD CONSTRAINT license_codes_used_school_id_fkey FOREIGN KEY (used_school_id) REFERENCES schools(id) ON DELETE SET NULL;

ALTER TABLE public.onedrive_access_audit ADD CONSTRAINT onedrive_access_audit_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_assessment_fk FOREIGN KEY (fee_assessment_id, school_id, student_id) REFERENCES student_fee_assessments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_opening_fk FOREIGN KEY (opening_balance_id, school_id, student_id) REFERENCES student_opening_balances(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_payment_fk FOREIGN KEY (payment_id, school_id, student_id) REFERENCES payments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.payment_allocations ADD CONSTRAINT payment_allocations_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.payments ADD CONSTRAINT payments_academic_year_school_fk FOREIGN KEY (academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.payments ADD CONSTRAINT payments_fee_assessment_school_student_fk FOREIGN KEY (fee_assessment_id, school_id, student_id) REFERENCES student_fee_assessments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.payments ADD CONSTRAINT payments_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.payroll_periods ADD CONSTRAINT payroll_periods_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.payroll_transactions ADD CONSTRAINT payroll_transactions_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_batches_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_source_year_fk FOREIGN KEY (source_academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_batches ADD CONSTRAINT rollover_target_year_fk FOREIGN KEY (target_academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_batch_fk FOREIGN KEY (batch_id, school_id) REFERENCES rollover_batches(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_opening_balance_fk FOREIGN KEY (opening_balance_id, school_id, student_id) REFERENCES student_opening_balances(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_source_class_fk FOREIGN KEY (source_class_id, school_id) REFERENCES classes(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_source_enrollment_fk FOREIGN KEY (source_enrollment_id, school_id, student_id) REFERENCES student_enrollments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_student_fk FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_target_class_fk FOREIGN KEY (target_class_id, school_id) REFERENCES classes(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.rollover_items ADD CONSTRAINT rollover_items_target_enrollment_fk FOREIGN KEY (target_enrollment_id, school_id, student_id) REFERENCES student_enrollments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.salary_assignments ADD CONSTRAINT salary_assignments_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.school_branding ADD CONSTRAINT school_branding_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.schools ADD CONSTRAINT schools_license_code_id_fkey FOREIGN KEY (license_code_id) REFERENCES license_codes(id) ON DELETE SET NULL;
ALTER TABLE public.staff ADD CONSTRAINT staff_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.staff_payments ADD CONSTRAINT staff_payments_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.staff_payments ADD CONSTRAINT staff_payments_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE;
ALTER TABLE public.student_behavior ADD CONSTRAINT student_behavior_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.student_discount_awards ADD CONSTRAINT discount_awards_rule_school_fk FOREIGN KEY (discount_rule_id, school_id) REFERENCES discount_rules(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.student_discount_awards ADD CONSTRAINT discount_awards_student_assessment_fk FOREIGN KEY (fee_assessment_id, school_id, student_id) REFERENCES student_fee_assessments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.student_discount_awards ADD CONSTRAINT student_discount_awards_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE;
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE SET NULL;
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_promoted_from_enrollment_id_fkey FOREIGN KEY (promoted_from_enrollment_id) REFERENCES student_enrollments(id) ON DELETE SET NULL;
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_source_student_id_fkey FOREIGN KEY (source_student_id) REFERENCES students(id) ON DELETE SET NULL;
ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE;
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE RESTRICT;
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_student_school_fk FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.student_fee_assessments ADD CONSTRAINT student_fee_assessments_year_school_fk FOREIGN KEY (academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.student_fees ADD CONSTRAINT student_fees_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);
ALTER TABLE public.student_fees ADD CONSTRAINT student_fees_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.student_opening_balances ADD CONSTRAINT opening_balances_rollover_batch_school_fk FOREIGN KEY (rollover_batch_id, school_id) REFERENCES rollover_batches(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.student_opening_balances ADD CONSTRAINT opening_balances_source_assessment_school_student_fk FOREIGN KEY (source_fee_assessment_id, school_id, student_id) REFERENCES student_fee_assessments(id, school_id, student_id) ON DELETE RESTRICT;
ALTER TABLE public.student_opening_balances ADD CONSTRAINT opening_balances_source_year_school_fk FOREIGN KEY (source_academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.student_opening_balances ADD CONSTRAINT opening_balances_target_year_school_fk FOREIGN KEY (academic_year_id, school_id) REFERENCES academic_years(id, school_id) ON DELETE RESTRICT;
ALTER TABLE public.student_opening_balances ADD CONSTRAINT student_opening_balances_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.student_opening_balances ADD CONSTRAINT student_opening_balances_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE;
ALTER TABLE public.student_parents ADD CONSTRAINT student_parents_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.student_parents ADD CONSTRAINT student_parents_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.student_results ADD CONSTRAINT student_results_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);
ALTER TABLE public.student_results ADD CONSTRAINT student_results_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.student_results ADD CONSTRAINT student_results_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE CASCADE;
ALTER TABLE public.student_results ADD CONSTRAINT student_results_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE SET NULL;
ALTER TABLE public.students ADD CONSTRAINT students_current_academic_year_id_fkey FOREIGN KEY (current_academic_year_id) REFERENCES academic_years(id);
ALTER TABLE public.students ADD CONSTRAINT students_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.subjects ADD CONSTRAINT subjects_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.teachers ADD CONSTRAINT teachers_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.user_deletion_audit ADD CONSTRAINT user_deletion_audit_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.whatsapp_notifications ADD CONSTRAINT whatsapp_notifications_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE public.whatsapp_notifications ADD CONSTRAINT whatsapp_notifications_student_id_school_id_fkey FOREIGN KEY (student_id, school_id) REFERENCES students(id, school_id) ON DELETE SET NULL;

-- Views.

CREATE OR REPLACE VIEW public.student_finance WITH (security_invoker=true) AS  SELECT f.student_id,
    f.school_id,
    f.total_fee,
    COALESCE(sum(p.amount), 0::numeric)::numeric(14,2) AS paid
   FROM student_fees f
     LEFT JOIN payments p ON p.student_id = f.student_id
  GROUP BY f.student_id, f.school_id, f.total_fee;;

CREATE OR REPLACE VIEW public.student_financial_summary WITH (security_invoker=true) AS  SELECT s.id AS student_id,
    s.school_id,
    s.name,
    s.class_name,
    s.phone,
    COALESCE(f.total_fee, 0::numeric) AS total_fee,
    COALESCE(f.discount, 0::numeric) AS discount,
    COALESCE(( SELECT sum(p.amount) AS sum
           FROM payments p
          WHERE p.student_id = s.id AND p.school_id = s.school_id), 0::numeric) AS paid
   FROM students s
     LEFT JOIN student_fees f ON f.student_id = s.id AND f.school_id = s.school_id;;

CREATE OR REPLACE VIEW public.student_result_summary WITH (security_invoker=true) AS  SELECT r.school_id,
    r.student_id,
    s.name,
    round(sum(r.score) / NULLIF(sum(r.max_score), 0::numeric) * 100::numeric, 2) AS percentage,
    count(*) AS exams
   FROM student_results r
     JOIN students s ON s.id = r.student_id AND s.school_id = r.school_id
  GROUP BY r.school_id, r.student_id, s.name;;
