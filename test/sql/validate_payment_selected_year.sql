-- Disposable CI only. A payment against an older fee assessment must retain that year's ID.
BEGIN;
INSERT INTO public.academic_years(id,school_id,name,starts_on,ends_on,active,is_closed)
VALUES ('30000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001',
        '2025-2026','2025-09-01','2026-06-30',false,true);
INSERT INTO public.student_fee_assessments(id,school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,manual_discount)
VALUES ('40000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003',
        '2025-2026','Term Historical',100,0,0);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE payment_id uuid; retry_id uuid; year_id uuid; allocation numeric;
BEGIN
 payment_id:=public.record_student_payment(
   '20000000-0000-4000-8000-000000000001',25,'historical year acceptance','Term 1',
   '40000000-0000-4000-8000-000000000003','historical-year-payment-ci-20261031');
 retry_id:=public.record_student_payment(
   '20000000-0000-4000-8000-000000000001',25,'historical year acceptance','Term 1',
   '40000000-0000-4000-8000-000000000003','historical-year-payment-ci-20261031');
 IF payment_id IS DISTINCT FROM retry_id THEN RAISE EXCEPTION 'payment retry did not return the original receipt'; END IF;
 SELECT academic_year_id INTO year_id FROM public.payments WHERE id=payment_id;
 IF year_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000003'::uuid THEN
   RAISE EXCEPTION 'historical payment assigned to wrong academic year: %',year_id;
 END IF;
 SELECT coalesce(sum(amount),0) INTO allocation FROM public.payment_allocations
 WHERE payment_id=payment_id AND fee_assessment_id='40000000-0000-4000-8000-000000000003' AND reversed_at IS NULL;
 IF allocation<>25 THEN RAISE EXCEPTION 'expected 25 allocated to historical assessment, got %',allocation; END IF;
END
$$;
ROLLBACK;
