-- Disposable CI only. Authenticated users cannot bypass the atomic payment ledger RPC.
DO $$
BEGIN
 IF has_table_privilege('authenticated','public.payments','INSERT')
 OR has_table_privilege('authenticated','public.payments','UPDATE')
 OR has_table_privilege('authenticated','public.payments','DELETE') THEN
   RAISE EXCEPTION 'authenticated role still has direct payment write privileges';
 END IF;
 IF NOT has_function_privilege('authenticated',
   'public.record_student_payment(uuid,numeric,text,text,uuid,text)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated role lost the payment ledger RPC';
 END IF;
END
$$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$
DECLARE v_payment uuid; v_count integer;
BEGIN
 BEGIN
   INSERT INTO public.payments(school_id,student_id,academic_year_id,fee_assessment_id,term,payment_date,amount,note)
   VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',
     '30000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001',
     'Term 1',current_date,5,'direct insert must fail');
   RAISE EXCEPTION 'direct payment insert unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   UPDATE public.payments SET amount=amount+1
   WHERE student_id='20000000-0000-4000-8000-000000000001';
   RAISE EXCEPTION 'direct payment update unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   DELETE FROM public.payments
   WHERE student_id='20000000-0000-4000-8000-000000000001';
   RAISE EXCEPTION 'direct payment delete unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 v_payment:=public.record_student_payment(
   '20000000-0000-4000-8000-000000000001',5,'ledger RPC acceptance','Term 1',
   '40000000-0000-4000-8000-000000000001','ledger-write-guard-ci-20261031');
 SELECT count(*) INTO v_count FROM public.payments WHERE id=v_payment;
 IF v_count<>1 THEN RAISE EXCEPTION 'ledger RPC failed to create exactly one receipt'; END IF;
END
$$;
RESET ROLE;
