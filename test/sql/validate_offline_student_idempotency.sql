-- Disposable CI only: offline student creation is replay-safe and tenant-scoped.
DO $$
BEGIN
  IF NOT has_function_privilege('authenticated',
    'public.create_student_with_fee_idempotent(text,text,text,text,numeric,text)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated role cannot call offline student idempotency RPC';
  END IF;
  IF has_function_privilege('anon',
    'public.create_student_with_fee_idempotent(text,text,text,text,numeric,text)','EXECUTE') THEN
    RAISE EXCEPTION 'anon role must not call offline student idempotency RPC';
  END IF;
  IF has_table_privilege('authenticated','public.lamin_offline_operation_receipts','SELECT')
     OR has_table_privilege('authenticated','public.lamin_offline_operation_receipts','INSERT') THEN
    RAISE EXCEPTION 'offline operation receipt table must not be directly accessible';
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
    'offline-create-ci-001','طالب اختبار المزامنة','الصف الأول','0910000000',0,'الفصل الأول');
  second_id := public.create_student_with_fee_idempotent(
    'offline-create-ci-001','اسم مختلف لا يجب أن ينشئ سجلاً ثانياً','الصف الأول','0910000000',0,'الفصل الأول');
  IF first_id IS DISTINCT FROM second_id THEN
    RAISE EXCEPTION 'replayed offline create returned a different student id';
  END IF;
  SELECT count(*) INTO total FROM public.students WHERE id=first_id;
  IF total <> 1 THEN RAISE EXCEPTION 'offline create replay did not remain exactly-once'; END IF;
END
$$;
RESET ROLE;
