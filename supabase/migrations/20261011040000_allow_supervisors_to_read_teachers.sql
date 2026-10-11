DROP POLICY IF EXISTS teachers_select ON public.teachers;
CREATE POLICY teachers_select
ON public.teachers
FOR SELECT
TO authenticated
USING (
  school_id = (SELECT private.my_school())
  AND (SELECT private.my_role()) = ANY (ARRAY['admin','owner','accountant','supervisor']::text[])
);