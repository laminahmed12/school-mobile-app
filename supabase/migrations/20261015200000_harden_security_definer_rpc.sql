-- Harden the 13 public SECURITY DEFINER RPCs without breaking Flutter RPC names.
-- Implementation functions are moved into the non-API private schema. Public
-- wrappers are SECURITY INVOKER and preserve signatures/defaults for existing clients.
-- Apply to Lamin-Test first; production deployment requires the full acceptance gate.

BEGIN;

-- Move the privileged implementations. Existing dependencies follow the function OIDs.
ALTER FUNCTION public.bootstrap_owner_school(text,text) SET SCHEMA private;
ALTER FUNCTION public.create_next_academic_year(text,date,date,boolean,boolean) SET SCHEMA private;
ALTER FUNCTION public.delete_school_user(uuid) SET SCHEMA private;
ALTER FUNCTION public.execute_academic_rollover(uuid) SET SCHEMA private;
ALTER FUNCTION public.export_backup(uuid) SET SCHEMA private;
ALTER FUNCTION public.grant_onedrive_access(uuid,text) SET SCHEMA private;
ALTER FUNCTION public.license_trial_status(uuid) SET SCHEMA private;
ALTER FUNCTION public.owner_stats() SET SCHEMA private;
ALTER FUNCTION public.prepare_academic_rollover(uuid,uuid) SET SCHEMA private;
ALTER FUNCTION public.record_student_payment(uuid,numeric,text,text,uuid,text) SET SCHEMA private;
ALTER FUNCTION public.restore_backup(jsonb) SET SCHEMA private;
ALTER FUNCTION public.revoke_onedrive_access(uuid,text) SET SCHEMA private;
ALTER FUNCTION public.update_school_settings(text,text,text) SET SCHEMA private;

-- Remove search_path dependence from the three implementations that previously
-- included public in search_path. Every table reference is schema-qualified.
CREATE OR REPLACE FUNCTION private.delete_school_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid := private.my_school();
  urec record;
BEGIN
  IF sid IS NULL OR private.my_role() NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'غير مصرح';
  END IF;

  SELECT p.user_id, p.username, p.role
    INTO urec
    FROM public.profiles AS p
   WHERE p.user_id = p_user_id AND p.school_id = sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم غير موجود'; END IF;
  IF urec.role NOT IN ('accountant','supervisor') THEN
    RAISE EXCEPTION 'لا يمكن حذف هذا النوع من الحسابات';
  END IF;

  UPDATE public.profiles
     SET active = false,
         onedrive_access_granted = false,
         onedrive_permission_id = NULL,
         onedrive_revoked_at = now()
   WHERE user_id = p_user_id AND school_id = sid;

  INSERT INTO public.user_deletion_audit(school_id,target_user_id,target_username,target_role)
  VALUES (sid,urec.user_id,urec.username,urec.role);

  INSERT INTO public.onedrive_access_audit(school_id,target_user_id,target_username,action)
  VALUES (sid,urec.user_id,urec.username,'auto_revoke');
END;
$function$;

CREATE OR REPLACE FUNCTION private.grant_onedrive_access(p_user_id uuid, p_permission_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid := private.my_school();
  u record;
BEGIN
  IF sid IS NULL OR private.my_role() NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'غير مصرح';
  END IF;

  SELECT p.user_id,p.username,p.role,p.active
    INTO u
    FROM public.profiles AS p
   WHERE p.user_id = p_user_id AND p.school_id = sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم غير موجود'; END IF;
  IF u.role NOT IN ('accountant','supervisor') THEN
    RAISE EXCEPTION 'صلاحية OneDrive مخصصة للمحاسب والمشرف';
  END IF;
  IF NOT u.active THEN RAISE EXCEPTION 'الحساب موقوف'; END IF;

  UPDATE public.profiles
     SET onedrive_access_granted = true,
         onedrive_permission_id = nullif(trim(p_permission_id),''),
         onedrive_granted_at = now(),
         onedrive_revoked_at = NULL
   WHERE user_id = p_user_id AND school_id = sid;

  INSERT INTO public.onedrive_access_audit(school_id,target_user_id,target_username,action,permission_id)
  VALUES (sid,u.user_id,u.username,'grant',nullif(trim(p_permission_id),''));
END;
$function$;

CREATE OR REPLACE FUNCTION private.revoke_onedrive_access(p_user_id uuid, p_action text DEFAULT 'revoke')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  sid uuid := private.my_school();
  u record;
  act text;
BEGIN
  IF sid IS NULL OR private.my_role() NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'غير مصرح';
  END IF;

  SELECT p.user_id,p.username,p.role,p.onedrive_permission_id
    INTO u
    FROM public.profiles AS p
   WHERE p.user_id = p_user_id AND p.school_id = sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم غير موجود'; END IF;

  act := CASE WHEN p_action = 'auto_revoke' THEN 'auto_revoke' ELSE 'revoke' END;

  UPDATE public.profiles
     SET onedrive_access_granted = false,
         onedrive_permission_id = NULL,
         onedrive_revoked_at = now()
   WHERE user_id = p_user_id AND school_id = sid;

  INSERT INTO public.onedrive_access_audit(school_id,target_user_id,target_username,action,permission_id)
  VALUES (sid,u.user_id,u.username,act,u.onedrive_permission_id);
END;
$function$;

-- The private implementations may be invoked by authenticated callers through
-- these wrappers, but the private schema must not be added to PostgREST exposed schemas.
-- Keep the existing execution grants for wrapper delegation; remove PUBLIC/anon access.
REVOKE ALL ON FUNCTION private.bootstrap_owner_school(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.create_next_academic_year(text,date,date,boolean,boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.delete_school_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.execute_academic_rollover(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.export_backup(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.grant_onedrive_access(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.license_trial_status(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.owner_stats() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.prepare_academic_rollover(uuid,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.record_student_payment(uuid,numeric,text,text,uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.restore_backup(jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.revoke_onedrive_access(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.update_school_settings(text,text,text) FROM PUBLIC, anon;

-- Preserve authenticated/service_role delegation required by SECURITY INVOKER wrappers.
GRANT EXECUTE ON FUNCTION private.bootstrap_owner_school(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.create_next_academic_year(text,date,date,boolean,boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.delete_school_user(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.execute_academic_rollover(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.export_backup(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.grant_onedrive_access(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.license_trial_status(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.owner_stats() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.prepare_academic_rollover(uuid,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.record_student_payment(uuid,numeric,text,text,uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.restore_backup(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.revoke_onedrive_access(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.update_school_settings(text,text,text) TO authenticated, service_role;

-- Public RPC wrappers: no elevated privileges, empty search_path, unchanged signatures.
CREATE FUNCTION public.bootstrap_owner_school(p_code text, p_name text)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.bootstrap_owner_school(p_code,p_name) $function$;

CREATE FUNCTION public.create_next_academic_year(
  p_name text, p_starts_on date DEFAULT NULL, p_ends_on date DEFAULT NULL,
  p_migrate_students boolean DEFAULT true, p_migrate_staff boolean DEFAULT true
)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.create_next_academic_year(p_name,p_starts_on,p_ends_on,p_migrate_students,p_migrate_staff) $function$;

CREATE FUNCTION public.delete_school_user(p_user_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.delete_school_user(p_user_id) $function$;

CREATE FUNCTION public.execute_academic_rollover(p_batch_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.execute_academic_rollover(p_batch_id) $function$;

CREATE FUNCTION public.export_backup(p_school uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.export_backup(p_school) $function$;

CREATE FUNCTION public.grant_onedrive_access(p_user_id uuid, p_permission_id text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.grant_onedrive_access(p_user_id,p_permission_id) $function$;

CREATE FUNCTION public.license_trial_status(p_school uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.license_trial_status(p_school) $function$;

CREATE FUNCTION public.owner_stats()
RETURNS TABLE(sid uuid, n_students bigint, n_users bigint)
LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT * FROM private.owner_stats() $function$;

CREATE FUNCTION public.prepare_academic_rollover(p_source_year uuid, p_target_year uuid)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.prepare_academic_rollover(p_source_year,p_target_year) $function$;

CREATE FUNCTION public.record_student_payment(
  p_student_id uuid, p_amount numeric, p_note text DEFAULT '',
  p_term text DEFAULT 'غير محدد', p_fee_assessment_id uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.record_student_payment(p_student_id,p_amount,p_note,p_term,p_fee_assessment_id,p_idempotency_key) $function$;

CREATE FUNCTION public.restore_backup(p_backup jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.restore_backup(p_backup) $function$;

CREATE FUNCTION public.revoke_onedrive_access(p_user_id uuid, p_action text DEFAULT 'revoke')
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.revoke_onedrive_access(p_user_id,p_action) $function$;

CREATE FUNCTION public.update_school_settings(p_name text, p_currency text, p_country_code text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$ SELECT private.update_school_settings(p_name,p_currency,p_country_code) $function$;

-- SECURITY INVOKER wrappers execute as the caller, so PostgreSQL requires schema USAGE
-- for authenticated callers to resolve private.* dependencies. Keep private out of the
-- PostgREST exposed-schema list; this grant alone does not expose private RPCs over HTTP.
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

-- No anonymous/public RPC execution. Signed-in app and trusted service role retain access.
REVOKE ALL ON FUNCTION public.bootstrap_owner_school(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_next_academic_year(text,date,date,boolean,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.delete_school_user(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.execute_academic_rollover(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.export_backup(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.grant_onedrive_access(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.license_trial_status(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.owner_stats() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prepare_academic_rollover(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_student_payment(uuid,numeric,text,text,uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.restore_backup(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.revoke_onedrive_access(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_school_settings(text,text,text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.bootstrap_owner_school(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_next_academic_year(text,date,date,boolean,boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_school_user(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.execute_academic_rollover(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.export_backup(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.grant_onedrive_access(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.license_trial_status(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.owner_stats() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.prepare_academic_rollover(uuid,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_student_payment(uuid,numeric,text,text,uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.restore_backup(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.revoke_onedrive_access(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_school_settings(text,text,text) TO authenticated, service_role;

COMMIT;
