-- Disposable CI only. Verify exposed privileged user RPCs use an empty search_path.
DO $$
DECLARE bad integer;
BEGIN
  SELECT count(*) INTO bad FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN ('delete_school_user','grant_onedrive_access','revoke_onedrive_access')
    AND (NOT p.prosecdef OR NOT ('search_path=""'=ANY(coalesce(p.proconfig,ARRAY[]::text[])))
      OR NOT has_function_privilege('authenticated',p.oid,'EXECUTE')
      OR has_function_privilege('anon',p.oid,'EXECUTE'));
  IF bad<>0 THEN RAISE EXCEPTION 'User-management RPC hardening failed: % unsafe entry points',bad; END IF;
END
$$;
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-000000000055') ON CONFLICT DO NOTHING;
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('00000000-0000-4000-8000-000000000055','10000000-0000-4000-8000-000000000001',
        'useradminrpctest','accountant',true,false)
ON CONFLICT(user_id) DO UPDATE SET role='accountant',active=true;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000055',false);
DO $$
BEGIN
  BEGIN PERFORM public.delete_school_user('00000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'accountant unexpectedly deleted a school user';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='accountant unexpectedly deleted a school user' THEN RAISE; END IF; END;
  BEGIN PERFORM public.grant_onedrive_access('00000000-0000-4000-8000-000000000001','test-permission');
    RAISE EXCEPTION 'accountant unexpectedly granted OneDrive access';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='accountant unexpectedly granted OneDrive access' THEN RAISE; END IF; END;
  BEGIN PERFORM public.revoke_onedrive_access('00000000-0000-4000-8000-000000000001','revoke');
    RAISE EXCEPTION 'accountant unexpectedly revoked OneDrive access';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='accountant unexpectedly revoked OneDrive access' THEN RAISE; END IF; END;
END
$$;
RESET ROLE;
