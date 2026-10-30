-- Student contact phone is optional. Keep non-empty values constrained to 8-15 digits.
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_phone_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_phone_check
  CHECK (phone = ''::text OR phone ~ '^[0-9]{8,15}$'::text);
