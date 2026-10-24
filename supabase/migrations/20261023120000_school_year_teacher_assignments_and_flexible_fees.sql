-- Additive school-year teacher assignments and flexible fee components.
-- This migration is intentionally forward-only and does not modify existing rows.
-- Existing aggregate fee assessments and payments remain compatible.
begin;

create table if not exists public.teacher_year_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  subject_id uuid references public.subjects(id) on delete set null,
  class_id uuid references public.classes(id) on delete set null,
  subject_label text not null default '',
  assignment_status text not null default 'active'
    check (assignment_status in ('active','inactive','transferred')),
  note text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (school_id, teacher_id, academic_year_id, subject_label, class_id)
);

create index if not exists teacher_year_assignments_year_idx
  on public.teacher_year_assignments(school_id, academic_year_id, assignment_status);

create table if not exists public.student_fee_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  fee_assessment_id uuid not null references public.student_fee_assessments(id) on delete cascade,
  item_type text not null check (item_type in ('tuition','transport','extra_lessons','activity','damage','other')),
  description text not null,
  amount numeric(12,2) not null check (amount >= 0),
  is_optional boolean not null default false,
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

create index if not exists student_fee_items_assessment_idx
  on public.student_fee_items(school_id, fee_assessment_id, item_type);

create table if not exists public.student_fee_installments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  fee_assessment_id uuid not null references public.student_fee_assessments(id) on delete cascade,
  installment_number integer not null check (installment_number > 0),
  title text not null default '',
  amount numeric(12,2) not null check (amount > 0),
  due_date date not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  unique (fee_assessment_id, installment_number)
);

create index if not exists student_fee_installments_due_idx
  on public.student_fee_installments(school_id, due_date, fee_assessment_id);

create table if not exists public.student_fee_adjustments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete restrict,
  academic_year_id uuid references public.academic_years(id) on delete restrict,
  fee_assessment_id uuid references public.student_fee_assessments(id) on delete restrict,
  adjustment_type text not null check (adjustment_type in ('damage','fine','credit','other')),
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','approved','cancelled')),
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id) on delete set null,
  cancellation_reason text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

create index if not exists student_fee_adjustments_student_idx
  on public.student_fee_adjustments(school_id, student_id, academic_year_id, status);

alter table public.teacher_year_assignments enable row level security;
alter table public.student_fee_items enable row level security;
alter table public.student_fee_installments enable row level security;
alter table public.student_fee_adjustments enable row level security;

drop policy if exists teacher_year_assignments_school_select on public.teacher_year_assignments;
create policy teacher_year_assignments_school_select on public.teacher_year_assignments
  for select to authenticated
  using (school_id = (select private.my_school()));

drop policy if exists teacher_year_assignments_school_write on public.teacher_year_assignments;
create policy teacher_year_assignments_school_write on public.teacher_year_assignments
  for all to authenticated
  using (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin'))
  with check (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin'));

drop policy if exists student_fee_items_school_select on public.student_fee_items;
create policy student_fee_items_school_select on public.student_fee_items
  for select to authenticated
  using (school_id = (select private.my_school()));

drop policy if exists student_fee_items_finance_write on public.student_fee_items;
create policy student_fee_items_finance_write on public.student_fee_items
  for all to authenticated
  using (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'))
  with check (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));

drop policy if exists student_fee_installments_school_select on public.student_fee_installments;
create policy student_fee_installments_school_select on public.student_fee_installments
  for select to authenticated
  using (school_id = (select private.my_school()));

drop policy if exists student_fee_installments_finance_write on public.student_fee_installments;
create policy student_fee_installments_finance_write on public.student_fee_installments
  for all to authenticated
  using (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'))
  with check (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));

drop policy if exists student_fee_adjustments_school_select on public.student_fee_adjustments;
create policy student_fee_adjustments_school_select on public.student_fee_adjustments
  for select to authenticated
  using (school_id = (select private.my_school()));

drop policy if exists student_fee_adjustments_finance_write on public.student_fee_adjustments;
create policy student_fee_adjustments_finance_write on public.student_fee_adjustments
  for all to authenticated
  using (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'))
  with check (school_id = (select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));

grant select, insert, update, delete on public.teacher_year_assignments to authenticated;
grant select, insert, update, delete on public.student_fee_items to authenticated;
grant select, insert, update, delete on public.student_fee_installments to authenticated;
grant select, insert, update, delete on public.student_fee_adjustments to authenticated;

commit;
