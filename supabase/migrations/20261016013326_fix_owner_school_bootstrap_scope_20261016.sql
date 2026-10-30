-- Lamīn: keep global owner profiles outside school scope during school bootstrap.
-- The profiles_owner_scope constraint requires role='owner' iff school_id IS NULL.
-- Apply to Lamin-Test first; do not deploy to production until acceptance passes.
BEGIN;

CREATE OR REPLACE FUNCTION private.bootstrap_owner_school(p_code text, p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_school uuid;
  v_code text := lower(btrim(coalesce(p_code, '')));
  v_name text := btrim(coalesce(p_name, ''));
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT p.role INTO v_role
  FROM public.profiles AS p
  WHERE p.user_id = v_user AND p.active = true;

  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'owner_only';
  END IF;

  -- Match the actual schools_code_check constraint exactly.
  IF v_code !~ '^[a-z0-9]{3,20}$' THEN
    RAISE EXCEPTION 'invalid_school_code';
  END IF;

  IF length(v_name) < 3 OR length(v_name) > 80 THEN
    RAISE EXCEPTION 'invalid_school_name';
  END IF;

  INSERT INTO public.schools(code, name, currency, country_code, licensed, trial_started_at)
  VALUES (v_code, v_name, 'LYD', '218', false, now())
  RETURNING id INTO v_school;

  -- Owner profiles are global and must keep school_id NULL. The created school
  -- is returned to the caller; never violate profiles_owner_scope by assigning it.
  RETURN v_school;
END;
$function$;

COMMIT;
