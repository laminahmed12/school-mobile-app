-- Assert that selective post-baseline changes preserve pre-existing synthetic rows.
DO $upgrade$
DECLARE n integer; body text;
BEGIN
  SELECT count(*) INTO n FROM public.schools WHERE id='90000000-0000-4000-8000-000000000001' AND code='upgschool';
  IF n<>1 THEN RAISE EXCEPTION 'upgrade lost or changed pre-existing school row'; END IF;
  SELECT count(*) INTO n FROM public.students WHERE id='90000000-0000-4000-8000-000000000002' AND name='Preserved Upgrade Student';
  IF n<>1 THEN RAISE EXCEPTION 'upgrade lost or changed pre-existing student row'; END IF;
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND policyname IN ('teachers_owner_insert','teachers_owner_update','teachers_owner_delete');
  IF n<>3 THEN RAISE EXCEPTION 'expected three owner teacher policies after upgrade, got %',n; END IF;
  body:=pg_get_functiondef('public.prepare_academic_rollover(uuid,uuid)'::regprocedure);
  IF position('payment_allocations' in body)=0 THEN RAISE EXCEPTION 'allocation-ledger rollover formula missing after upgrade'; END IF;
  body:=pg_get_functiondef('public.lamin_guard_rollover_year_state()'::regprocedure);
  IF position('balance_formula_version' in body)=0 THEN RAISE EXCEPTION 'rollover preview-version guard missing after upgrade'; END IF;
  body:=lower(pg_get_functiondef('public.execute_academic_rollover(uuid)'::regprocedure));
  IF position('id<>b.target_academic_year_id' in body)>0 THEN RAISE EXCEPTION 'unsafe all-other-years closing behavior remains'; END IF;
  body:=lower(pg_get_functiondef('public.create_next_academic_year(text,date,date,boolean,boolean)'::regprocedure));
  IF position('insert into public.student_enrollments' in body)>0 THEN RAISE EXCEPTION 'legacy pre-review bulk enrollment remains'; END IF;
END
$upgrade$;
