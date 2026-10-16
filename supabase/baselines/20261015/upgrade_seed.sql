-- Synthetic pre-upgrade data for the isolated upgrade-path test only.
INSERT INTO auth.users(id) VALUES ('90000000-0000-4000-8000-000000000001');
INSERT INTO public.schools(id,code,name,licensed)
VALUES ('90000000-0000-4000-8000-000000000001','upgschool','Preserved Upgrade School',true);
INSERT INTO public.profiles(user_id,school_id,username,role,active,must_change_password)
VALUES ('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','upgadmin','admin',true,false);
INSERT INTO public.students(id,school_id,name,class_name,phone)
VALUES ('90000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001','Preserved Upgrade Student','Grade 9','09100000009');
