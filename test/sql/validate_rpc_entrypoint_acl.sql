-- Lamīn RPC entrypoint ACL regression test.
-- Runs only against disposable CI PostgreSQL after the security migration.
DO $$
DECLARE
  v_private_count integer;
  v_public_count integer;
  v_bad_private integer;
  v_bad_public integer;
  v_private_usage boolean;
BEGIN
  SELECT count(*), count(*) FILTER (
    WHERE NOT p.prosecdef
       OR NOT ('search_path=""' = ANY(coalesce(p.proconfig, ARRAY[]::text[])))
       OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
       OR has_function_privilege('anon', p.oid, 'EXECUTE')
  )
  INTO v_private_count, v_bad_private
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='private'
    AND p.proname IN (
      'bootstrap_owner_school','create_next_academic_year','delete_school_user',
      'execute_academic_rollover','export_backup','grant_onedrive_access',
      'license_trial_status','owner_stats','prepare_academic_rollover',
      'record_student_payment','restore_backup','revoke_onedrive_access',
      'update_school_settings'
    );

  SELECT count(*), count(*) FILTER (
    WHERE NOT p.prosecdef
       OR NOT ('search_path=""' = ANY(coalesce(p.proconfig, ARRAY[]::text[])))
       OR NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
       OR has_function_privilege('anon', p.oid, 'EXECUTE')
  )
  INTO v_public_count, v_bad_public
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname IN (
      'bootstrap_owner_school','create_next_academic_year','delete_school_user',
      'execute_academic_rollover','export_backup','grant_onedrive_access',
      'license_trial_status','owner_stats','prepare_academic_rollover',
      'record_student_payment','restore_backup','revoke_onedrive_access',
      'update_school_settings'
    );

  v_private_usage := has_schema_privilege('authenticated','private','USAGE')
                     OR has_schema_privilege('anon','private','USAGE');

  IF v_private_count <> 13 OR v_bad_private <> 0 THEN
    RAISE EXCEPTION 'Private RPC ACL failed: count %, unsafe grants %', v_private_count, v_bad_private;
  END IF;
  IF v_public_count <> 13 OR v_bad_public <> 0 THEN
    RAISE EXCEPTION 'Public RPC wrapper ACL failed: count %, unsafe wrappers %', v_public_count, v_bad_public;
  END IF;
  IF v_private_usage THEN
    RAISE EXCEPTION 'Client roles unexpectedly have USAGE on private schema';
  END IF;
END
$$;
