-- Lamīn staging security correction — 2026-10-16.
-- Client roles use only the 13 public RPC wrappers. Internal private implementations
-- are not client entry points. Apply to Lamin-Test first; do not deploy to production
-- until API and functional acceptance tests pass.

BEGIN;

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'bootstrap_owner_school','create_next_academic_year','delete_school_user',
      'execute_academic_rollover','export_backup','grant_onedrive_access',
      'license_trial_status','owner_stats','prepare_academic_rollover',
      'record_student_payment','restore_backup','revoke_onedrive_access',
      'update_school_settings'
    )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', r.signature);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', r.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', r.signature);
  END LOOP;

  FOR r IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='private' AND p.proname IN (
      'bootstrap_owner_school','create_next_academic_year','delete_school_user',
      'execute_academic_rollover','export_backup','grant_onedrive_access',
      'license_trial_status','owner_stats','prepare_academic_rollover',
      'record_student_payment','restore_backup','revoke_onedrive_access',
      'update_school_settings'
    )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.signature);
  END LOOP;
END
$$;

REVOKE USAGE ON SCHEMA private FROM anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

COMMIT;
