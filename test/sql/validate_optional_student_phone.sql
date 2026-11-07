-- Disposable CI only. Requires the baseline school fixture and optional-phone migration.
BEGIN;
INSERT INTO public.students(id,school_id,name,class_name,phone)
VALUES (
  '20000000-0000-4000-8000-000000000099',
  '10000000-0000-4000-8000-000000000001',
  'Release Gate Optional Phone',
  'Grade 1',
  ''
);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.students
    WHERE id='20000000-0000-4000-8000-000000000099'
      AND phone=''
  ) THEN
    RAISE EXCEPTION 'student with optional blank phone was not persisted';
  END IF;
END
$$;
ROLLBACK;
