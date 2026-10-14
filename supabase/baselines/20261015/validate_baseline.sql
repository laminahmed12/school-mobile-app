-- Isolated baseline acceptance tests. Run only in the ephemeral CI database.
DO $counts$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='public' AND c.relkind='r';
  IF n <> 40 THEN RAISE EXCEPTION 'expected 40 application tables, got %', n; END IF;
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public';
  IF n <> 99 THEN RAISE EXCEPTION 'expected 99 RLS policies, got %', n; END IF;
  SELECT count(*) INTO n FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='public' AND NOT t.tgisinternal;
  IF n <> 32 THEN RAISE EXCEPTION 'expected 32 user triggers, got %', n; END IF;
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace WHERE s.nspname IN ('public','private') AND p.prokind='f';
  IF n <> 46 THEN RAISE EXCEPTION 'expected 46 application routines, got %', n; END IF;
  SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='public' AND c.relkind='r' AND c.relrowsecurity;
  IF n <> 40 THEN RAISE EXCEPTION 'expected RLS on all 40 application tables, got %', n; END IF;
END
$counts$;

INSERT INTO auth.users(id) VALUES
 ('00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000002');
INSERT INTO public.schools(id,code,name,licensed) VALUES
 ('10000000-0000-4000-8000-000000000001','lamtesta','Lamīn Test School A',true),
 ('10000000-0000-4000-8000-000000000002','lamtestb','Lamīn Test School B',true);
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password) VALUES
 ('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','testadmina','admin',true,false),
 ('00000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','testadminb','admin',true,false);
INSERT INTO public.academic_years(id,school_id,name,starts_on,ends_on,active,is_closed) VALUES
 ('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','2026-2027','2026-09-01','2027-06-30',true,false),
 ('30000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','2026-2027','2026-09-01','2027-06-30',true,false);
INSERT INTO public.students(id,school_id,name,class_name,phone,current_academic_year_id) VALUES
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Test Student A','Grade 1','09100000001','30000000-0000-4000-8000-000000000001'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Test Student B','Grade 1','09100000002','30000000-0000-4000-8000-000000000002');
INSERT INTO public.student_fee_assessments(id,school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,manual_discount)
VALUES
 ('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','2026-2027','Term 1',100,0,0),
 ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','2026-2027','Term 1',100,0,0);

-- Tenant isolation for school A.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $tenant_a$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.students;
  IF n <> 1 THEN RAISE EXCEPTION 'school A sees % students, expected 1', n; END IF;
  SELECT count(*) INTO n FROM public.students WHERE school_id='10000000-0000-4000-8000-000000000002';
  IF n <> 0 THEN RAISE EXCEPTION 'school A can see school B students'; END IF;
END
$tenant_a$;

-- Finance path: record one payment, verify idempotency and allocation.
DO $finance$
DECLARE p1 uuid; p2 uuid; n integer; allocated numeric;
BEGIN
  p1 := public.record_student_payment('20000000-0000-4000-8000-000000000001',30,'baseline acceptance','Term 1','40000000-0000-4000-8000-000000000001','baseline-idempotency-a');
  p2 := public.record_student_payment('20000000-0000-4000-8000-000000000001',30,'baseline acceptance','Term 1','40000000-0000-4000-8000-000000000001','baseline-idempotency-a');
  IF p1 IS DISTINCT FROM p2 THEN RAISE EXCEPTION 'payment idempotency did not return same payment'; END IF;
  SELECT count(*) INTO n FROM public.payments WHERE id=p1;
  IF n <> 1 THEN RAISE EXCEPTION 'expected exactly one payment, got %',n; END IF;
  SELECT COALESCE(sum(amount),0) INTO allocated FROM public.payment_allocations WHERE payment_id=p1 AND reversed_at IS NULL;
  IF allocated <> 30 THEN RAISE EXCEPTION 'expected 30 allocated, got %',allocated; END IF;
  BEGIN
    PERFORM public.record_student_payment('20000000-0000-4000-8000-000000000002',10,'cross-tenant attempt','Term 1',NULL,'cross-tenant-a');
    RAISE EXCEPTION 'cross-tenant payment unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='cross-tenant payment unexpectedly succeeded' THEN RAISE; END IF;
  END;
END
$finance$;

-- Backup/restore path uses only synthetic fixtures created in this ephemeral database.
DO $backup$
DECLARE payload jsonb; restored jsonb;
BEGIN
  payload := public.export_backup(NULL);
  IF payload->>'format' <> 'lamin-school-backup-v2' THEN RAISE EXCEPTION 'unexpected backup format'; END IF;
  IF jsonb_typeof(payload->'payment_allocations') <> 'array' THEN RAISE EXCEPTION 'backup omits payment_allocations'; END IF;
  IF jsonb_typeof(payload->'student_fee_assessments') <> 'array' THEN RAISE EXCEPTION 'backup omits student_fee_assessments'; END IF;
  restored := public.restore_backup(payload);
  IF jsonb_typeof(restored) <> 'object' THEN RAISE EXCEPTION 'restore did not return structured result'; END IF;
END
$backup$;
RESET ROLE;

-- Tenant isolation for school B.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $tenant_b$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.students;
  IF n <> 1 THEN RAISE EXCEPTION 'school B sees % students, expected 1', n; END IF;
  SELECT count(*) INTO n FROM public.students WHERE school_id='10000000-0000-4000-8000-000000000001';
  IF n <> 0 THEN RAISE EXCEPTION 'school B can see school A students'; END IF;
END
$tenant_b$;
RESET ROLE;
