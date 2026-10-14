-- Allow school owners as well as admins to maintain teacher records.
-- Existing school-scoped SELECT policy remains unchanged.
drop policy if exists teachers_owner_insert on public.teachers;
create policy teachers_owner_insert on public.teachers
  for insert to authenticated
  with check (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

drop policy if exists teachers_owner_update on public.teachers;
create policy teachers_owner_update on public.teachers
  for update to authenticated
  using (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  )
  with check (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );

drop policy if exists teachers_owner_delete on public.teachers;
create policy teachers_owner_delete on public.teachers
  for delete to authenticated
  using (
    school_id = (select private.my_school())
    and (select private.my_role()) = 'owner'
  );
