-- Allow student records without a parent WhatsApp number.
-- A non-empty phone must still contain 8-15 digits.
BEGIN;

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_phone_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_phone_check
  CHECK (phone = '' OR phone ~ '^[0-9]{8,15}$');

COMMIT;
