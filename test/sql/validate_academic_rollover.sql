-- Academic rollover functional regression test.
-- Uses only synthetic rows and rolls back the complete test transaction.
BEGIN;
INSERT INTO auth.users(id) VALUES ('9aaaaaaa-0000-4000-8000-000000000001');
INSERT INTO public.schools(id,code,name,licensed)
VALUES ('9bbbbbbb-0000-4000-8000-000000000001','rollci1016','Rollover CI School',true);
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('9aaaaaaa-0000-4000-8000-000000000001','9bbbbbbb-0000-4000-8000-000000000001','rolloverciadmin','admin',true,false);
INSERT INTO public.academic_years(id,school_id,name,starts_on,ends_on,active,is_closed)
VALUES
('9ccccccc-0000-4000-8000-000000000001','9bbbbbbb-0000-4000-8000-000000000001','Rollover Source 2025','2025-09-01','2026-06-30',true,false),
('9ccccccc-0000-4000-8000-000000000002','9bbbbbbb-0000-4000-8000-000000000001','Rollover Target 2026','2026-09-01','2027-06-30',false,false);
INSERT INTO public.classes(id,school_id,name,section,academic_year_id,grade_order)
VALUES
('9ddddddd-0000-4000-8000-000000000001','9bbbbbbb-0000-4000-8000-000000000001','Grade 1','A','9ccccccc-0000-4000-8000-000000000001',1),
('9ddddddd-0000-4000-8000-000000000002','9bbbbbbb-0000-4000-8000-000000000001','Grade 2','A','9ccccccc-0000-4000-8000-000000000002',2);
INSERT INTO public.students(id,school_id,name,class_name,phone,current_academic_year_id)
VALUES ('9eeeeeee-0000-4000-8000-000000000001','9bbbbbbb-0000-4000-8000-000000000001','Rollover CI Student','Grade 1','09100000881','9ccccccc-0000-4000-8000-000000000001');
INSERT INTO public.student_enrollments(id,school_id,student_id,academic_year_id,class_id,status,source_student_id,result_status)
VALUES ('9f111111-0000-4000-8000-000000000001','9bbbbbbb-0000-4000-8000-000000000001','9eeeeeee-0000-4000-8000-000000000001','9ccccccc-0000-4000-8000-000000000001','9ddddddd-0000-4000-8000-000000000001','active','9eeeeeee-0000-4000-8000-000000000001','passed');
INSERT INTO public.student_fee_assessments(id,school_id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,manual_discount)
VALUES ('9f222222-0000-4000-8000-000000000001','9bbbbbbb-0000-4000-8000-000000000001','9eeeeeee-0000-4000-8000-000000000001','9ccccccc-0000-4000-8000-000000000001','Rollover Source 2025','Term 1',100,0,0);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','9aaaaaaa-0000-4000-8000-000000000001',true);
DO $rollover$
DECLARE p uuid; b uuid; v_balance numeric; n integer; result jsonb;
BEGIN
 p:=public.record_student_payment('9eeeeeee-0000-4000-8000-000000000001',60,'rollover test','Term 1','9f222222-0000-4000-8000-000000000001','rollover-ci-idem-1016');
 SELECT COALESCE(sum(pa.amount),0) INTO v_balance FROM public.payment_allocations pa WHERE pa.payment_id=p AND pa.reversed_at IS NULL;
 IF v_balance<>60 THEN RAISE EXCEPTION 'source allocation expected 60, got %',v_balance; END IF;
 b:=public.prepare_academic_rollover('9ccccccc-0000-4000-8000-000000000001','9ccccccc-0000-4000-8000-000000000002');
 SELECT source_balance INTO v_balance FROM public.rollover_items WHERE batch_id=b AND student_id='9eeeeeee-0000-4000-8000-000000000001';
 IF v_balance<>40 THEN RAISE EXCEPTION 'opening balance preview expected 40, got %',v_balance; END IF;
 UPDATE public.rollover_items SET reviewed=true,reviewed_by=auth.uid(),reviewed_at=now(),target_class_id='9ddddddd-0000-4000-8000-000000000002' WHERE batch_id=b;
 result:=public.execute_academic_rollover(b);
 IF coalesce((result->>'ok')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'rollover did not return ok: %',result; END IF;
 SELECT count(*) INTO n FROM public.student_enrollments WHERE student_id='9eeeeeee-0000-4000-8000-000000000001' AND academic_year_id='9ccccccc-0000-4000-8000-000000000002' AND class_id='9ddddddd-0000-4000-8000-000000000002';
 IF n<>1 THEN RAISE EXCEPTION 'expected one target enrollment, got %',n; END IF;
 SELECT amount INTO v_balance FROM public.student_opening_balances WHERE student_id='9eeeeeee-0000-4000-8000-000000000001' AND academic_year_id='9ccccccc-0000-4000-8000-000000000002';
 IF v_balance<>40 THEN RAISE EXCEPTION 'target opening balance expected 40, got %',v_balance; END IF;
 SELECT count(*) INTO n FROM public.academic_years WHERE id='9ccccccc-0000-4000-8000-000000000001' AND is_closed=true AND active=false;
 IF n<>1 THEN RAISE EXCEPTION 'source year not closed'; END IF;
 SELECT count(*) INTO n FROM public.academic_years WHERE id='9ccccccc-0000-4000-8000-000000000002' AND is_closed=false AND active=true;
 IF n<>1 THEN RAISE EXCEPTION 'target year not activated'; END IF;
 result:=public.execute_academic_rollover(b);
 IF coalesce((result->>'already_completed')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'repeat rollover is not idempotent: %',result; END IF;
END
$rollover$;
ROLLBACK;
