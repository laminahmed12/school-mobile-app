-- Commercial release hardening: pin privileged user-management RPCs to an empty search_path.
-- Preserve the existing authenticated entry points and their in-function role/tenant checks.
BEGIN;
CREATE OR REPLACE FUNCTION public.delete_school_user(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE sid uuid := private.my_school(); urec record;
BEGIN
  IF sid IS NULL OR private.my_role() NOT IN ('owner','admin') THEN RAISE EXCEPTION 'غير مصرح'; END IF;
  SELECT p.user_id,p.username,p.role INTO urec FROM public.profiles AS p WHERE p.user_id=p_user_id AND p.school_id=sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم غير موجود'; END IF;
  IF urec.role NOT IN ('accountant','supervisor') THEN RAISE EXCEPTION 'لا يمكن حذف هذا النوع من الحسابات'; END IF;
  UPDATE public.profiles SET active=false,onedrive_access_granted=false,onedrive_permission_id=NULL,onedrive_revoked_at=now()
   WHERE user_id=p_user_id AND school_id=sid;
  INSERT INTO public.user_deletion_audit(school_id,target_user_id,target_username,target_role)
  VALUES(sid,urec.user_id,urec.username,urec.role);
  INSERT INTO public.onedrive_access_audit(school_id,target_user_id,target_username,action)
  VALUES(sid,urec.user_id,urec.username,'auto_revoke');
END;
$function$;
CREATE OR REPLACE FUNCTION public.grant_onedrive_access(p_user_id uuid,p_permission_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE sid uuid := private.my_school(); u record;
BEGIN
  IF sid IS NULL OR private.my_role() NOT IN ('owner','admin') THEN RAISE EXCEPTION 'غير مصرح'; END IF;
  SELECT p.user_id,p.username,p.role,p.active INTO u FROM public.profiles AS p
   WHERE p.user_id=p_user_id AND p.school_id=sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم غير موجود'; END IF;
  IF u.role NOT IN ('accountant','supervisor') THEN RAISE EXCEPTION 'صلاحية OneDrive مخصصة للمحاسب والمشرف'; END IF;
  IF NOT u.active THEN RAISE EXCEPTION 'الحساب موقوف'; END IF;
  UPDATE public.profiles SET onedrive_access_granted=true,onedrive_permission_id=nullif(trim(p_permission_id),''),
    onedrive_granted_at=now(),onedrive_revoked_at=NULL WHERE user_id=p_user_id AND school_id=sid;
  INSERT INTO public.onedrive_access_audit(school_id,target_user_id,target_username,action,permission_id)
  VALUES(sid,u.user_id,u.username,'grant',nullif(trim(p_permission_id),''));
END;
$function$;
CREATE OR REPLACE FUNCTION public.revoke_onedrive_access(p_user_id uuid,p_action text DEFAULT 'revoke')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE sid uuid := private.my_school(); u record; act text;
BEGIN
  IF sid IS NULL OR private.my_role() NOT IN ('owner','admin') THEN RAISE EXCEPTION 'غير مصرح'; END IF;
  SELECT p.user_id,p.username,p.role,p.onedrive_permission_id INTO u FROM public.profiles AS p
   WHERE p.user_id=p_user_id AND p.school_id=sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم غير موجود'; END IF;
  act := CASE WHEN p_action='auto_revoke' THEN 'auto_revoke' ELSE 'revoke' END;
  UPDATE public.profiles SET onedrive_access_granted=false,onedrive_permission_id=NULL,onedrive_revoked_at=now()
   WHERE user_id=p_user_id AND school_id=sid;
  INSERT INTO public.onedrive_access_audit(school_id,target_user_id,target_username,action,permission_id)
  VALUES(sid,u.user_id,u.username,act,u.onedrive_permission_id);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.delete_school_user(uuid) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.grant_onedrive_access(uuid,text) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.revoke_onedrive_access(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.delete_school_user(uuid) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.grant_onedrive_access(uuid,text) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.revoke_onedrive_access(uuid,text) TO authenticated,service_role;
COMMIT;
