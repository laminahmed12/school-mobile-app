-- Production-compatible archive lifecycle for students, teachers, staff and school accounts.
-- Soft archive preserves records, relationships, audit history and financial data.
BEGIN;

ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archive_note text;

ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archive_note text;

ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archive_note text;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS archive_note text;

CREATE INDEX IF NOT EXISTS students_active_by_school ON public.students (school_id, name) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS teachers_active_by_school ON public.teachers (school_id, name) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS staff_active_by_school ON public.staff (school_id, name) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS profiles_active_by_school ON public.profiles (school_id, username) WHERE archived_at IS NULL;

DROP POLICY IF EXISTS students_delete ON public.students;
DROP POLICY IF EXISTS teachers_delete ON public.teachers;
DROP POLICY IF EXISTS teachers_owner_delete ON public.teachers;
DROP POLICY IF EXISTS staff_write ON public.staff;
DROP POLICY IF EXISTS staff_insert ON public.staff;
DROP POLICY IF EXISTS staff_update ON public.staff;
DROP POLICY IF EXISTS staff_delete ON public.staff;

CREATE POLICY staff_insert ON public.staff FOR INSERT TO authenticated
  WITH CHECK (school_id = private.my_school() AND private.my_role() = ANY (ARRAY['admin','owner']));
CREATE POLICY staff_update ON public.staff FOR UPDATE TO authenticated
  USING (school_id = private.my_school() AND private.my_role() = ANY (ARRAY['admin','owner']))
  WITH CHECK (school_id = private.my_school() AND private.my_role() = ANY (ARRAY['admin','owner']));
REVOKE DELETE ON public.students, public.teachers, public.staff FROM authenticated, anon;

CREATE OR REPLACE FUNCTION public.archive_person(
  p_kind text, p_id uuid, p_reason text DEFAULT 'other', p_note text DEFAULT ''
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
  sid uuid := private.my_school();
  v_role text := private.my_role();
  v_name text;
  v_username text;
  v_note text := left(coalesce(p_note,''),500);
BEGIN
  IF auth.uid() IS NULL OR sid IS NULL OR v_role NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'الأرشفة متاحة لمدير المدرسة فقط' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR p_reason NOT IN ('transferred','expelled','deceased','resigned','terminated','other') THEN
    RAISE EXCEPTION 'سبب الأرشفة غير صالح' USING ERRCODE = '22023';
  END IF;
  IF p_kind = 'student' AND p_reason IN ('resigned','terminated') THEN
    RAISE EXCEPTION 'السبب لا يناسب الطالب' USING ERRCODE = '22023';
  END IF;
  IF p_kind IN ('teacher','staff','user') AND p_reason = 'expelled' THEN
    RAISE EXCEPTION 'السبب لا يناسب هذه الفئة' USING ERRCODE = '22023';
  END IF;

  SELECT username INTO v_username FROM public.profiles WHERE user_id = auth.uid();

  IF p_kind = 'student' THEN
    UPDATE public.students
      SET archived_at=now(), archive_reason=p_reason, archive_note=v_note,
          archived_by=auth.uid(), active=false,
          status=CASE p_reason WHEN 'transferred' THEN 'transferred'
            WHEN 'expelled' THEN 'expelled' WHEN 'deceased' THEN 'deceased'
            ELSE 'withdrawn' END
      WHERE id=p_id AND school_id=sid AND archived_at IS NULL
      RETURNING name INTO v_name;
  ELSIF p_kind = 'teacher' THEN
    UPDATE public.teachers
      SET archived_at=now(), archive_reason=p_reason, archive_note=v_note,
          archived_by=auth.uid(), active=false
      WHERE id=p_id AND school_id=sid AND archived_at IS NULL
      RETURNING name INTO v_name;
  ELSIF p_kind = 'staff' THEN
    UPDATE public.staff
      SET archived_at=now(), archive_reason=p_reason, archive_note=v_note,
          archived_by=auth.uid(), active=false
      WHERE id=p_id AND school_id=sid AND archived_at IS NULL
      RETURNING name INTO v_name;
  ELSIF p_kind = 'user' THEN
    UPDATE public.profiles
      SET archived_at=now(), archive_reason=p_reason, archive_note=v_note,
          archived_by=auth.uid(), active=false
      WHERE user_id=p_id AND school_id=sid
        AND role IN ('accountant','supervisor') AND archived_at IS NULL
      RETURNING username INTO v_name;
  ELSE
    RAISE EXCEPTION 'نوع غير معروف' USING ERRCODE = '22023';
  END IF;

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'السجل غير موجود أو مؤرشف مسبقاً أو غير قابل للأرشفة' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.audit_log(school_id,user_id,username,action,entity,entity_id,details)
  VALUES (sid,auth.uid(),v_username,'archive',p_kind,p_id::text,
    jsonb_build_object('name',v_name,'reason',p_reason,'note',v_note));

  RETURN jsonb_build_object('ok',true,'kind',p_kind,'name',v_name,'message','تمت الأرشفة');
END
$fn$;

CREATE OR REPLACE FUNCTION public.restore_person(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
  sid uuid := private.my_school();
  v_role text := private.my_role();
  v_name text;
  v_username text;
BEGIN
  IF auth.uid() IS NULL OR sid IS NULL OR v_role NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'الإرجاع متاح لمدير المدرسة فقط' USING ERRCODE = '42501';
  END IF;
  SELECT username INTO v_username FROM public.profiles WHERE user_id=auth.uid();

  IF p_kind = 'student' THEN
    UPDATE public.students SET archived_at=NULL,archive_reason=NULL,archive_note=NULL,
      archived_by=NULL,active=true,status='active'
      WHERE id=p_id AND school_id=sid AND archived_at IS NOT NULL RETURNING name INTO v_name;
  ELSIF p_kind = 'teacher' THEN
    UPDATE public.teachers SET archived_at=NULL,archive_reason=NULL,archive_note=NULL,
      archived_by=NULL,active=true
      WHERE id=p_id AND school_id=sid AND archived_at IS NOT NULL RETURNING name INTO v_name;
  ELSIF p_kind = 'staff' THEN
    UPDATE public.staff SET archived_at=NULL,archive_reason=NULL,archive_note=NULL,
      archived_by=NULL,active=true
      WHERE id=p_id AND school_id=sid AND archived_at IS NOT NULL RETURNING name INTO v_name;
  ELSIF p_kind = 'user' THEN
    UPDATE public.profiles SET archived_at=NULL,archive_reason=NULL,archive_note=NULL,
      archived_by=NULL,active=true
      WHERE user_id=p_id AND school_id=sid AND archived_at IS NOT NULL RETURNING username INTO v_name;
  ELSE
    RAISE EXCEPTION 'نوع غير معروف' USING ERRCODE = '22023';
  END IF;

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'السجل غير موجود أو غير مؤرشف' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.audit_log(school_id,user_id,username,action,entity,entity_id,details)
  VALUES (sid,auth.uid(),v_username,'restore',p_kind,p_id::text,jsonb_build_object('name',v_name));

  RETURN jsonb_build_object('ok',true,'kind',p_kind,'name',v_name,'message','تم الإرجاع من الأرشيف');
END
$fn$;

CREATE OR REPLACE FUNCTION public.list_archive(p_kind text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
  sid uuid := private.my_school();
  v_role text := private.my_role();
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR sid IS NULL OR v_role NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'الأرشيف متاح لمدير المدرسة فقط' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.archived_at DESC),'[]'::jsonb)
  INTO v_result
  FROM (
    SELECT 'student'::text AS kind,s.id::text AS id,s.name,s.class_name AS detail,
      s.archive_reason AS reason,s.archive_note AS note,s.archived_at,
      (SELECT username FROM public.profiles p WHERE p.user_id=s.archived_by) AS archived_by_name
    FROM public.students s WHERE s.school_id=sid AND s.archived_at IS NOT NULL
    UNION ALL
    SELECT 'teacher',t.id::text,t.name,t.subject,t.archive_reason,t.archive_note,t.archived_at,
      (SELECT username FROM public.profiles p WHERE p.user_id=t.archived_by)
    FROM public.teachers t WHERE t.school_id=sid AND t.archived_at IS NOT NULL
    UNION ALL
    SELECT 'staff',f.id::text,f.name,f.role,f.archive_reason,f.archive_note,f.archived_at,
      (SELECT username FROM public.profiles p WHERE p.user_id=f.archived_by)
    FROM public.staff f WHERE f.school_id=sid AND f.archived_at IS NOT NULL
    UNION ALL
    SELECT 'user',u.user_id::text,u.username,u.role,u.archive_reason,u.archive_note,u.archived_at,
      (SELECT username FROM public.profiles p WHERE p.user_id=u.archived_by)
    FROM public.profiles u WHERE u.school_id=sid AND u.archived_at IS NOT NULL
  ) r
  WHERE p_kind IS NULL OR r.kind=p_kind;

  RETURN v_result;
END
$fn$;

REVOKE ALL ON FUNCTION public.archive_person(text,uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.restore_person(text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.list_archive(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.archive_person(text,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_person(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_archive(text) TO authenticated;

COMMIT;
