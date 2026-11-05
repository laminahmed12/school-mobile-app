-- Archive-only lifecycle for students, teachers and staff.
-- Soft archive preserves foreign keys and all financial/academic history.
BEGIN;

ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS archive_note text;

ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS archive_note text;

ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archive_reason text;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS archive_note text;

CREATE INDEX IF NOT EXISTS students_active_by_school ON public.students (school_id, name) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS teachers_active_by_school ON public.teachers (school_id, name) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS staff_active_by_school ON public.staff (school_id, name) WHERE archived_at IS NULL;

-- Prevent permanent deletion by authenticated clients; service-role maintenance remains possible.
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
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
  sid uuid := private.my_school();
  uid uuid := auth.uid();
  target_school uuid;
BEGIN
  IF uid IS NULL OR sid IS NULL OR private.my_role() NOT IN ('admin','owner') THEN
    RAISE EXCEPTION 'not authorized' USING ERRCODE = '42501';
  END IF;
  IF p_kind NOT IN ('student','teacher','staff') THEN
    RAISE EXCEPTION 'invalid person kind' USING ERRCODE = '22023';
  END IF;
  IF p_reason NOT IN ('left_school','transferred','inactive','other') THEN
    RAISE EXCEPTION 'invalid archive reason' USING ERRCODE = '22023';
  END IF;
  CASE p_kind
    WHEN 'student' THEN
      UPDATE public.students SET archived_at = now(), archived_by = uid,
        archive_reason = p_reason, archive_note = NULLIF(left(trim(p_note), 1000), '')
        WHERE id = p_id AND school_id = sid AND archived_at IS NULL;
    WHEN 'teacher' THEN
      UPDATE public.teachers SET archived_at = now(), archived_by = uid,
        archive_reason = p_reason, archive_note = NULLIF(left(trim(p_note), 1000), '')
        WHERE id = p_id AND school_id = sid AND archived_at IS NULL;
    WHEN 'staff' THEN
      UPDATE public.staff SET archived_at = now(), archived_by = uid,
        archive_reason = p_reason, archive_note = NULLIF(left(trim(p_note), 1000), '')
        WHERE id = p_id AND school_id = sid AND archived_at IS NULL;
  END CASE;
  IF NOT FOUND THEN RAISE EXCEPTION 'record not found or already archived' USING ERRCODE = 'P0002'; END IF;
END
$fn$;

CREATE OR REPLACE FUNCTION public.restore_person(p_kind text, p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE sid uuid := private.my_school(); uid uuid := auth.uid();
BEGIN
  IF uid IS NULL OR sid IS NULL OR private.my_role() NOT IN ('admin','owner') THEN
    RAISE EXCEPTION 'not authorized' USING ERRCODE = '42501';
  END IF;
  CASE p_kind
    WHEN 'student' THEN UPDATE public.students SET archived_at=NULL, archived_by=NULL, archive_reason=NULL, archive_note=NULL WHERE id=p_id AND school_id=sid AND archived_at IS NOT NULL;
    WHEN 'teacher' THEN UPDATE public.teachers SET archived_at=NULL, archived_by=NULL, archive_reason=NULL, archive_note=NULL WHERE id=p_id AND school_id=sid AND archived_at IS NOT NULL;
    WHEN 'staff' THEN UPDATE public.staff SET archived_at=NULL, archived_by=NULL, archive_reason=NULL, archive_note=NULL WHERE id=p_id AND school_id=sid AND archived_at IS NOT NULL;
    ELSE RAISE EXCEPTION 'invalid person kind' USING ERRCODE = '22023';
  END CASE;
  IF NOT FOUND THEN RAISE EXCEPTION 'archived record not found' USING ERRCODE = 'P0002'; END IF;
END
$fn$;

CREATE OR REPLACE FUNCTION public.list_archive(p_query text DEFAULT '')
RETURNS TABLE(kind text, id uuid, name text, details text, archived_at timestamptz, archive_reason text, archive_note text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE sid uuid := private.my_school(); uid uuid := auth.uid(); q text := '%' || trim(coalesce(p_query,'')) || '%';
BEGIN
  IF uid IS NULL OR sid IS NULL OR private.my_role() NOT IN ('admin','owner') THEN
    RAISE EXCEPTION 'not authorized' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT 'student'::text, s.id, s.name, coalesce(s.class_name,''), s.archived_at, s.archive_reason, s.archive_note
      FROM public.students s WHERE s.school_id=sid AND s.archived_at IS NOT NULL AND s.name ILIKE q
    UNION ALL
    SELECT 'teacher'::text, t.id, t.name, coalesce(t.subject,''), t.archived_at, t.archive_reason, t.archive_note
      FROM public.teachers t WHERE t.school_id=sid AND t.archived_at IS NOT NULL AND t.name ILIKE q
    UNION ALL
    SELECT 'staff'::text, st.id, st.name, coalesce(st.role,''), st.archived_at, st.archive_reason, st.archive_note
      FROM public.staff st WHERE st.school_id=sid AND st.archived_at IS NOT NULL AND st.name ILIKE q
    ORDER BY 5 DESC;
END
$fn$;

REVOKE ALL ON FUNCTION public.archive_person(text,uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.restore_person(text,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_archive(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.archive_person(text,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_person(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_archive(text) TO authenticated;

COMMIT;
