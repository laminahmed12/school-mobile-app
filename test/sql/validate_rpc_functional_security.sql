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
  BEGIN
    PERFORM public.bootstrap_owner_school('adminboot1016','Admin Must Not Bootstrap');
    RAISE EXCEPTION 'non-owner bootstrap unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='non-owner bootstrap unexpectedly succeeded' THEN RAISE; END IF;
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

-- Owner bootstrap must create a school without violating global-owner scope.
BEGIN;
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-000000000004');
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('00000000-0000-4000-8000-000000000004',NULL,'testglobalowner','owner',true,false);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
DO $owner_bootstrap$
DECLARE sid uuid;
BEGIN
  sid:=public.bootstrap_owner_school('ownerrpc1016','Owner RPC Test School');
  IF sid IS NULL OR NOT EXISTS(SELECT 1 FROM public.schools WHERE id=sid AND code='ownerrpc1016') THEN
    RAISE EXCEPTION 'owner bootstrap did not create and return the school';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE user_id=auth.uid() AND role='owner' AND school_id IS NULL) THEN
    RAISE EXCEPTION 'owner bootstrap violated global owner scope';
  END IF;
  BEGIN
    PERFORM public.bootstrap_owner_school('invalid-code','Invalid Code School');
    RAISE EXCEPTION 'invalid school code unexpectedly accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='invalid school code unexpectedly accepted' THEN RAISE; END IF;
  END;
END
$owner_bootstrap$;
ROLLBACK;

-- Confirm the failed cross-tenant write left no row behind.
DO $
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.students
  WHERE id='20000000-0000-4000-8000-000000000099';
  IF n<>0 THEN RAISE EXCEPTION 'cross-tenant test row unexpectedly persisted'; END IF;
END
$;
