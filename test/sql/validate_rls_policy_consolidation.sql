-- Disposable CI only. Verify equivalent RLS policies are consolidated without broadening access.
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_policies
 WHERE schemaname='public' AND tablename='payroll_periods';
 IF n<>1 OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public'
   AND tablename='payroll_periods' AND policyname='lamin_payroll_periods_write' AND cmd='ALL') THEN
   RAISE EXCEPTION 'payroll_periods policy consolidation failed';
 END IF;

 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename='staff';
 IF n<>4 OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='staff' AND policyname='staff_select' AND cmd='SELECT')
   OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='staff' AND policyname='staff_insert' AND cmd='INSERT')
   OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='staff' AND policyname='staff_update' AND cmd='UPDATE')
   OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='staff' AND policyname='staff_delete' AND cmd='DELETE') THEN
   RAISE EXCEPTION 'staff policy consolidation failed';
 END IF;

 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename='teachers';
 IF n<>4 OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='teachers' AND policyname='teachers_select' AND cmd='SELECT')
   OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='teachers' AND policyname='teachers_insert' AND cmd='INSERT' AND with_check LIKE '%owner%')
   OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='teachers' AND policyname='teachers_update' AND cmd='UPDATE')
   OR NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='teachers' AND policyname='teachers_delete' AND cmd='DELETE') THEN
   RAISE EXCEPTION 'teachers policy consolidation failed';
 END IF;

 IF to_regclass('public.audit_log_school_idx') IS NOT NULL
   OR to_regclass('public.audit_log_school_created_idx') IS NULL THEN
   RAISE EXCEPTION 'duplicate audit index was not consolidated safely';
 END IF;
 IF to_regclass('public.student_extra_charges_academic_year_idx') IS NULL
   OR to_regclass('public.student_extra_charges_school_idx') IS NULL
   OR to_regclass('public.student_extra_charges_student_idx') IS NULL
   OR to_regclass('public.student_payment_installments_school_idx') IS NULL
   OR to_regclass('public.student_payment_plans_academic_year_idx') IS NULL
   OR to_regclass('public.student_payment_plans_school_idx') IS NULL
   OR to_regclass('public.student_payment_plans_student_idx') IS NULL
   OR to_regclass('public.teacher_academic_year_records_academic_year_idx') IS NULL
   OR to_regclass('public.teacher_academic_year_records_teacher_idx') IS NULL THEN
   RAISE EXCEPTION 'one or more foreign-key supporting indexes are missing';
 END IF;

 IF EXISTS (
   SELECT 1 FROM pg_policies WHERE schemaname='public'
   AND tablename IN ('payroll_periods','staff','teachers')
   GROUP BY tablename,cmd HAVING count(*)>1
 ) THEN RAISE EXCEPTION 'overlapping permissive policies remain on consolidated tables'; END IF;
END
$$;

INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-000000000004') ON CONFLICT DO NOTHING;
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('00000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','testaccountanta','accountant',true,false)
ON CONFLICT(user_id) DO UPDATE SET role=EXCLUDED.role,active=true;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
INSERT INTO public.teachers(name,subject,phone) VALUES('Admin RLS Gate','Math','09100000031');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',false);
DO $$
BEGIN
 PERFORM count(*) FROM public.staff;
 BEGIN
   INSERT INTO public.teachers(name,subject,phone) VALUES('Accountant Must Not Insert','Math','09100000034');
   RAISE EXCEPTION 'accountant unexpectedly inserted a teacher';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   INSERT INTO public.staff(name) VALUES('Accountant Must Not Insert Staff');
   RAISE EXCEPTION 'accountant unexpectedly inserted staff';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$$;
RESET ROLE;
