-- Preserve the academic year of the selected fee assessment when recording a payment.
-- The previous routine always stamped the currently active year, even for historical fee items.
CREATE OR REPLACE FUNCTION public.record_student_payment(
 p_student_id uuid,p_amount numeric,p_note text DEFAULT '',p_term text DEFAULT 'غير محدد',
 p_fee_assessment_id uuid DEFAULT NULL,p_idempotency_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_school uuid:=private.my_school();
 v_role text:=private.my_role();
 v_year uuid;
 v_payment uuid;
 v_term text:=coalesce(nullif(btrim(p_term),''),'غير محدد');
 v_remaining numeric(12,2):=round(coalesce(p_amount,0),2);
 r record;
 v_take numeric(12,2);
BEGIN
 IF auth.uid() IS NULL OR v_school IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول إلى المدرسة أولاً'; END IF;
 IF v_role NOT IN ('owner','admin','accountant') THEN RAISE EXCEPTION 'ليست لديك صلاحية تسجيل الدفعات'; END IF;
 IF p_amount IS NULL OR p_amount<=0 OR p_amount>100000000 THEN RAISE EXCEPTION 'قيمة الدفعة غير صحيحة'; END IF;
 IF length(coalesce(p_note,''))>200 THEN RAISE EXCEPTION 'الملاحظة طويلة أكثر من اللازم'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.students s WHERE s.id=p_student_id AND s.school_id=v_school) THEN
   RAISE EXCEPTION 'الطالب غير موجود ضمن المدرسة الحالية';
 END IF;

 IF p_idempotency_key IS NOT NULL THEN
   SELECT p.id INTO v_payment FROM public.payments p
   WHERE p.school_id=v_school AND p.idempotency_key=p_idempotency_key;
   IF v_payment IS NOT NULL THEN RETURN v_payment; END IF;
 END IF;

 IF p_fee_assessment_id IS NOT NULL THEN
   SELECT sfa.academic_year_id,sfa.term INTO v_year,v_term
   FROM public.student_fee_assessments sfa
   WHERE sfa.id=p_fee_assessment_id AND sfa.school_id=v_school AND sfa.student_id=p_student_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'بند الرسوم المحدد لا يخص هذا الطالب'; END IF;
 ELSE
   SELECT ay.id INTO v_year FROM public.academic_years ay
   WHERE ay.school_id=v_school AND ay.active=true AND coalesce(ay.is_closed,false)=false
   ORDER BY ay.starts_on DESC NULLS LAST,ay.created_at DESC LIMIT 1;
 END IF;

 INSERT INTO public.payments(school_id,student_id,academic_year_id,fee_assessment_id,term,payment_date,amount,note,created_by,idempotency_key)
 VALUES(v_school,p_student_id,v_year,p_fee_assessment_id,v_term,current_date,round(p_amount,2),btrim(coalesce(p_note,'')),auth.uid(),p_idempotency_key)
 RETURNING id INTO v_payment;

 -- Settle carried opening balances first, preserving each balance's target year.
 FOR r IN
   SELECT ob.id,greatest(ob.amount-coalesce((SELECT sum(pa.amount) FROM public.payment_allocations pa
     WHERE pa.opening_balance_id=ob.id AND pa.reversed_at IS NULL),0),0) AS outstanding
   FROM public.student_opening_balances ob
   WHERE ob.school_id=v_school AND ob.student_id=p_student_id
   ORDER BY ob.created_at,ob.id
 LOOP
   EXIT WHEN v_remaining<=0;
   IF r.outstanding<=0 THEN CONTINUE; END IF;
   v_take:=least(v_remaining,r.outstanding);
   INSERT INTO public.payment_allocations(school_id,student_id,payment_id,opening_balance_id,amount,created_by)
   VALUES(v_school,p_student_id,v_payment,r.id,v_take,auth.uid());
   v_remaining:=v_remaining-v_take;
 END LOOP;

 -- Allocate remaining payment to this student's assessments. Legacy unallocated payments
 -- are included in the outstanding calculation to prevent double charging.
 FOR r IN
   SELECT sfa.id,
     greatest(sfa.total_fee-sfa.discount
       -coalesce((SELECT sum(pa.amount) FROM public.payment_allocations pa WHERE pa.fee_assessment_id=sfa.id AND pa.reversed_at IS NULL),0)
       -coalesce((SELECT sum(oldp.amount) FROM public.payments oldp WHERE oldp.fee_assessment_id=sfa.id AND oldp.id<>v_payment
          AND NOT EXISTS(SELECT 1 FROM public.payment_allocations olda WHERE olda.payment_id=oldp.id AND olda.reversed_at IS NULL)),0),0) AS outstanding
   FROM public.student_fee_assessments sfa
   WHERE sfa.school_id=v_school AND sfa.student_id=p_student_id
   ORDER BY (sfa.id=p_fee_assessment_id) DESC,sfa.due_date ASC NULLS LAST,sfa.created_at,sfa.id
 LOOP
   EXIT WHEN v_remaining<=0;
   IF r.outstanding<=0 THEN CONTINUE; END IF;
   v_take:=least(v_remaining,r.outstanding);
   INSERT INTO public.payment_allocations(school_id,student_id,payment_id,fee_assessment_id,amount,created_by)
   VALUES(v_school,p_student_id,v_payment,r.id,v_take,auth.uid());
   v_remaining:=v_remaining-v_take;
 END LOOP;

 RETURN v_payment;
END
$function$;
