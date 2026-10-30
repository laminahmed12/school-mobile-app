-- Disposable CI only. A payment against an older fee assessment must retain that year's ID.
BEGIN;
INSERT INTO public.academic_years(id,school_id,name,starts_on,ends_on,active,is_closed)
VALUES ('30000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001',
        '2025-2026','2025-09-01','2026-06-30',false,true);
INSERT INTO public.student_fee_assessments(id,school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,manual_discount)
VALUES ('40000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003',
        '2025-2026','Term Historical',100,0,0);
INSERT INTO public.student_fee_assessments(id,school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,manual_discount)
VALUES ('40000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001',NULL,
        'Legacy','Term Legacy',50,0,0);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE v_payment_id uuid; v_retry_id uuid; v_year_id uuid; v_allocation numeric;
 v_legacy_payment_id uuid; v_legacy_year_id uuid;
BEGIN
 v_payment_id:=public.record_student_payment(
   '20000000-0000-4000-8000-000000000001',25,'historical year acceptance','Term 1',
   '40000000-0000-4000-8000-000000000003','historical-year-payment-ci-20261031');
 v_retry_id:=public.record_student_payment(
   '20000000-0000-4000-8000-000000000001',25,'historical year acceptance','Term 1',
   '40000000-0000-4000-8000-000000000003','historical-year-payment-ci-20261031');
 IF v_payment_id IS DISTINCT FROM v_retry_id THEN RAISE EXCEPTION 'payment retry did not return the original receipt'; END IF;
 SELECT academic_year_id INTO v_year_id FROM public.payments WHERE id=v_payment_id;
 IF v_year_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000003'::uuid THEN
   RAISE EXCEPTION 'historical payment assigned to wrong academic year: %',v_year_id;
 END IF;
 SELECT coalesce(sum(pa.amount),0) INTO v_allocation FROM public.payment_allocations pa
 WHERE pa.payment_id=v_payment_id AND fee_assessment_id='40000000-0000-4000-8000-000000000003' AND reversed_at IS NULL;
 IF v_allocation<>25 THEN RAISE EXCEPTION 'expected 25 allocated to historical assessment, got %',v_allocation; END IF;
 v_legacy_payment_id:=public.record_student_payment(
   '20000000-0000-4000-8000-000000000001',10,'legacy assessment fallback','Term Legacy',
   '40000000-0000-4000-8000-000000000004','legacy-assessment-year-ci-20261031');
 SELECT academic_year_id INTO v_legacy_year_id FROM public.payments WHERE id=v_legacy_payment_id;
 IF v_legacy_year_id IS DISTINCT FROM '30000000-0000-4000-8000-000000000001'::uuid THEN
   RAISE EXCEPTION 'legacy fee payment did not fall back to active year: %',v_legacy_year_id;
 END IF;
END
$$;
ROLLBACK;
