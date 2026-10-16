-- Negative authorization regression tests for hardened Lamīn RPCs.
-- Disposable CI only; requires validate_baseline.sql fixtures and RPC hardening migrations.
DO $$
DECLARE
  v_count integer;
BEGIN
  IF has_schema_privilege('authenticated','private','USAGE') THEN
    RAISE EXCEPTION 'authenticated unexpectedly has private schema USAGE';
  END IF;
  IF has_schema_privilege('anon','private','USAGE') THEN
    RAISE EXCEPTION 'anon unexpectedly has private schema USAGE';
  END IF;
  IF has_function_privilege('anon','public.export_backup(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'anon unexpectedly can execute public export_backup';
  END IF;
  IF has_function_privilege('anon','public.restore_backup(jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'anon unexpectedly can execute public restore_backup';
  END IF;
END
$$;

-- School A must not be able to write a row into School B.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$
BEGIN
  BEGIN
    INSERT INTO public.students(id,school_id,name,class_name,phone)
    VALUES ('20000000-0000-4000-8000-000000000099',
            '10000000-0000-4000-8000-000000000002',
            'Cross Tenant Write Must Fail','Grade 1','09199999999');
    RAISE EXCEPTION 'cross-tenant student insert unexpectedly succeeded';
  EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN NULL;
  END;
END
$$;

-- A non-admin role must not be able to restore, even a backup for its own school.
RESET ROLE;
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-000000000003');
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('00000000-0000-4000-8000-000000000003',
        '10000000-0000-4000-8000-000000000001',
        'testaccountant','accountant',true,false);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
DO $$
BEGIN
  BEGIN
    PERFORM public.restore_backup(jsonb_build_object(
      'format','lamin-school-backup-v2',
      'school_filter','10000000-0000-4000-8000-000000000001',
      'schools','[]'::jsonb));
    RAISE EXCEPTION 'accountant restore unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='accountant restore unexpectedly succeeded' THEN RAISE; END IF;
  END;
END
$$;

-- School A's admin must not restore a backup whose declared school is School B.
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$
BEGIN
  BEGIN
    PERFORM public.restore_backup(jsonb_build_object(
      'format','lamin-school-backup-v2',
      'school_filter','10000000-0000-4000-8000-000000000002',
      'schools','[]'::jsonb));
    RAISE EXCEPTION 'cross-tenant restore unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='cross-tenant restore unexpectedly succeeded' THEN RAISE; END IF;
  END;
END
$$;
RESET ROLE;

-- Confirm the failed cross-tenant write left no row behind.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.students
  WHERE id='20000000-0000-4000-8000-000000000099';
  IF n<>0 THEN RAISE EXCEPTION 'cross-tenant test row unexpectedly persisted'; END IF;
END
$$;
