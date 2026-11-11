-- Disposable CI only: production-compatible offline student creation is retry-safe.
DO $$
DECLARE overload_count integer;
BEGIN
  IF NOT has_function_privilege('authenticated',
    'public.create_student_with_fee_idempotent(text,text,text,numeric,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated role cannot call offline student idempotency RPC';
  END IF;
  IF has_function_privilege('anon',
    'public.create_student_with_fee_idempotent(text,text,text,numeric,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'anon role must not call offline student idempotency RPC';
  END IF;
  SELECT count(*) INTO overload_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='create_student_with_fee_idempotent';
  IF overload_count <> 1 THEN
    RAISE EXCEPTION 'student idempotency RPC must have exactly one overload; found %', overload_count;
  END IF;
  IF (SELECT prosecdef FROM pg_proc
      WHERE oid='public.create_student_with_fee_idempotent(text,text,text,numeric,text,text)'::regprocedure) THEN
    RAISE EXCEPTION 'student idempotency RPC must remain SECURITY INVOKER';
  END IF;
  IF NOT has_table_privilege('authenticated','public.client_operations','INSERT')
     OR NOT has_table_privilege('authenticated','public.client_operations','SELECT') THEN
    RAISE EXCEPTION 'authenticated client_operations access required by the invoker RPC is missing';
  END IF;
END
$$;

INSERT INTO auth.users(id)
VALUES ('00000000-0000-4000-8000-000000000066')
ON CONFLICT DO NOTHING;
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('00000000-0000-4000-8000-000000000066',
        '10000000-0000-4000-8000-000000000001',
        'offlineidempotencyci','admin',true,false)
ON CONFLICT(user_id) DO UPDATE SET role='admin',active=true,must_change_password=false;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000066',false);
DO $$
DECLARE first_id uuid; second_id uuid; total integer;
BEGIN
  first_id := public.create_student_with_fee_idempotent(
    'طالب اختبار المزامنة','الصف الأول','0910000000',0,'الفصل الأول',
    'offline-create-ci-0001');
  second_id := public.create_student_with_fee_idempotent(
    'اسم مختلف لا يجب أن ينشئ سجلاً ثانياً','الصف الأول','0910000000',0,'الفصل الأول',
    'offline-create-ci-0001');
  IF first_id IS DISTINCT FROM second_id THEN
    RAISE EXCEPTION 'replayed offline create returned a different student id';
  END IF;
  SELECT count(*) INTO total FROM public.students WHERE id=first_id;
  IF total <> 1 THEN RAISE EXCEPTION 'offline create replay did not remain exactly-once'; END IF;
  IF (SELECT class_name FROM public.students WHERE id=first_id) <> 'الصف الأول' THEN
    RAISE EXCEPTION 'student class was not stored in class_name';
  END IF;
  IF (SELECT phone FROM public.students WHERE id=first_id) <> '0910000000' THEN
    RAISE EXCEPTION 'student phone was not stored correctly';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.client_operations
    WHERE school_id='10000000-0000-4000-8000-000000000001'
      AND operation_id='offline-create-ci-0001'
      AND kind='create_student' AND result_id=first_id
  ) THEN
    RAISE EXCEPTION 'idempotency receipt was not recorded in the production ledger';
  END IF;
END
$$;
RESET ROLE;
