-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
create index if not exists student_fee_assessments_year_school_idx on public.student_fee_assessments(academic_year_id,school_id);
create index if not exists onedrive_access_audit_school_idx on public.onedrive_access_audit(school_id);
drop policy if exists payroll_transactions_insert on public.payroll_transactions;
create policy payroll_transactions_insert on public.payroll_transactions for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('admin','owner','accountant') and created_by=(select auth.uid()));
drop policy if exists student_fee_assessments_insert on public.student_fee_assessments;
create policy student_fee_assessments_insert on public.student_fee_assessments for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('admin','owner','accountant') and (created_by is null or created_by=(select auth.uid())));
