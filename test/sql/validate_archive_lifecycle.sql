-- Disposable PostgreSQL CI only. Exercises archive/restore lifecycle and authorization.
-- Never run this fixture against Lamin-Test or production.
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-4000-8000-000000000101'),
 ('00000000-0000-4000-8000-000000000102'),
 ('00000000-0000-4000-8000-000000000103')
ON CONFLICT DO NOTHING;

INSERT INTO public.schools(id,code,name,licensed,active)
VALUES
 ('10000000-0000-4000-8000-000000000101','archschool1','Archive Test School One',true,true),
 ('10000000-0000-4000-8000-000000000102','archschool2','Archive Test School Two',true,true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES
 ('00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000101','archiveadmin1','admin',true,false),
 ('00000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000102','archiveadmin2','admin',true,false),
 ('00000000-0000-4000-8000-000000000103','10000000-0000-4000-8000-000000000101','archiveaccountant','accountant',true,false)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.students(id,school_id,name,class_name,phone)
VALUES ('20000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000101','Archive Student','Grade 4','')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.teachers(id,school_id,name,subject,phone,salary)
VALUES ('20000000-0000-4000-8000-000000000102','10000000-0000-4000-8000-000000000101','Archive Teacher','Math','',0)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.staff(id,school_id,name,role,phone,salary,active)
VALUES ('20000000-0000-4000-8000-000000000103','10000000-0000-4000-8000-000000000101','Archive Staff','Clerk','',0,true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.students(id,school_id,name,class_name,phone)
VALUES ('20000000-0000-4000-8000-000000000104','10000000-0000-4000-8000-000000000102','Other School Student','Grade 2','')
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
 IF has_table_privilege('authenticated','public.students','DELETE')
 OR has_table_privilege('authenticated','public.teachers','DELETE')
 OR has_table_privilege('authenticated','public.staff','DELETE') THEN
   RAISE EXCEPTION 'authenticated retains direct DELETE table privilege';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
   AND tablename IN ('students','teachers','staff') AND cmd='DELETE') THEN
   RAISE EXCEPTION 'a direct DELETE RLS policy remains on an archive-only table';
 END IF;
 IF has_function_privilege('anon','public.archive_person(text,uuid,text,text)','EXECUTE')
 OR has_function_privilege('anon','public.restore_person(text,uuid)','EXECUTE')
 OR has_function_privilege('anon','public.list_archive(text)','EXECUTE')
 OR has_function_privilege('public','public.archive_person(text,uuid,text,text)','EXECUTE')
 OR has_function_privilege('public','public.restore_person(text,uuid)','EXECUTE')
 OR has_function_privilege('public','public.list_archive(text)','EXECUTE') THEN
   RAISE EXCEPTION 'archive RPC is executable by anon or PUBLIC';
 END IF;
 IF NOT has_function_privilege('authenticated','public.archive_person(text,uuid,text,text)','EXECUTE')
 OR NOT has_function_privilege('authenticated','public.restore_person(text,uuid)','EXECUTE')
 OR NOT has_function_privilege('authenticated','public.list_archive(text)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated is missing archive RPC execute grants';
 END IF;
END $$;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',false);

-- Admin can create an archive entry for each supported entity type.
SELECT public.archive_person('student','20000000-0000-4000-8000-000000000101','left_school','student archive test');
SELECT public.archive_person('teacher','20000000-0000-4000-8000-000000000102','transferred','teacher archive test');
SELECT public.archive_person('staff','20000000-0000-4000-8000-000000000103','inactive','staff archive test');

DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.list_archive('');
 IF n <> 3 THEN RAISE EXCEPTION 'archive listing expected 3 own-school records, got %',n; END IF;
 IF (SELECT count(*) FROM public.list_archive('Archive')) <> 3 THEN
   RAISE EXCEPTION 'archive search did not return all matching people';
 END IF;
 BEGIN
   PERFORM public.archive_person('student','20000000-0000-4000-8000-000000000104','other','cross tenant');
   RAISE EXCEPTION 'cross-school archive unexpectedly succeeded';
 EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL;
 END;
 BEGIN
   PERFORM public.archive_person('student','20000000-0000-4000-8000-000000000101','invalid','bad reason');
   RAISE EXCEPTION 'invalid archive reason unexpectedly succeeded';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
END $$;

-- Restore each record and ensure archive metadata is cleared.
SELECT public.restore_person('student','20000000-0000-4000-8000-000000000101');
SELECT public.restore_person('teacher','20000000-0000-4000-8000-000000000102');
SELECT public.restore_person('staff','20000000-0000-4000-8000-000000000103');
DO $$
BEGIN
 IF (SELECT count(*) FROM public.list_archive('')) <> 0 THEN
   RAISE EXCEPTION 'restored records still appear in archive';
 END IF;
 IF EXISTS (SELECT 1 FROM public.students WHERE id='20000000-0000-4000-8000-000000000101' AND archived_at IS NOT NULL)
 OR EXISTS (SELECT 1 FROM public.teachers WHERE id='20000000-0000-4000-8000-000000000102' AND archived_at IS NOT NULL)
 OR EXISTS (SELECT 1 FROM public.staff WHERE id='20000000-0000-4000-8000-000000000103' AND archived_at IS NOT NULL) THEN
   RAISE EXCEPTION 'restore did not clear archive metadata';
 END IF;
 -- Staff INSERT/UPDATE policy replacement must preserve authorized admin writes.
 INSERT INTO public.staff(school_id,name) VALUES ('10000000-0000-4000-8000-000000000101','Policy write check');
 UPDATE public.staff SET name='Policy update check' WHERE name='Policy write check';
END $$;

-- A user from another school cannot list this school's archive or archive its people.
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',false);
DO $$
BEGIN
 IF (SELECT count(*) FROM public.list_archive('')) <> 0 THEN
   RAISE EXCEPTION 'archive listing leaked records across schools';
 END IF;
 BEGIN
   PERFORM public.archive_person('student','20000000-0000-4000-8000-000000000101','other','cross tenant');
   RAISE EXCEPTION 'second-school admin archived a foreign-school student';
 EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL;
 END;
END $$;

-- Accountant is authenticated but is not authorized to archive or restore.
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000103',false);
DO $$
BEGIN
 BEGIN
   PERFORM public.archive_person('student','20000000-0000-4000-8000-000000000101','other','role gate');
   RAISE EXCEPTION 'accountant unexpectedly archived a student';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   PERFORM public.restore_person('student','20000000-0000-4000-8000-000000000101');
   RAISE EXCEPTION 'accountant unexpectedly restored a student';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   PERFORM public.list_archive('');
   RAISE EXCEPTION 'accountant unexpectedly listed archive';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
RESET ROLE;

-- Ensure all three rows still exist: lifecycle is soft-archive, never hard-delete.
DO $$
BEGIN
 IF (SELECT count(*) FROM public.students WHERE id='20000000-0000-4000-8000-000000000101') <> 1
 OR (SELECT count(*) FROM public.teachers WHERE id='20000000-0000-4000-8000-000000000102') <> 1
 OR (SELECT count(*) FROM public.staff WHERE id='20000000-0000-4000-8000-000000000103') <> 1 THEN
   RAISE EXCEPTION 'archive/restore removed an underlying person record';
 END IF;
END $$;
