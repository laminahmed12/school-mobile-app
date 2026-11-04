-- 20261104000000_archive_only_no_hard_delete.sql
-- الأرشفة والاستعادة فقط للطلاب والمعلمين والموظفين: إزالة الحذف النهائي عبر الواجهة.
--   * آمن للتكرار (drop if exists ثم create).
--   * لا يحذف ولا يعدّل أي بيانات.
--   * لا يمس دوال archive_person و restore_person و list_archive الموجودة (سليمة ومختبرة).
--   * حذف المدرسة بالكامل (service role / postgres) يعمل كما كان، لأنه يتجاوز RLS.
-- السبب: حذف طالب يمسح بالتتابع (CASCADE) مدفوعاته ودرجاته وحضوره ورسومه، وكان مسموحاً للمدير.

drop policy if exists students_delete on public.students;
drop policy if exists teachers_delete on public.teachers;
drop policy if exists teachers_owner_delete on public.teachers;

-- staff_write كانت ALL (تشمل الحذف): نستبدلها بسياستي إدراج وتعديل بنفس الشروط
drop policy if exists staff_write on public.staff;
drop policy if exists staff_insert on public.staff;
drop policy if exists staff_update on public.staff;

create policy staff_insert on public.staff for insert to authenticated
  with check (school_id = private.my_school() and private.my_role() = any (array['admin','owner']));

create policy staff_update on public.staff for update to authenticated
  using (school_id = private.my_school() and private.my_role() = any (array['admin','owner']))
  with check (school_id = private.my_school() and private.my_role() = any (array['admin','owner']));

revoke delete on public.students, public.teachers, public.staff from authenticated, anon;
