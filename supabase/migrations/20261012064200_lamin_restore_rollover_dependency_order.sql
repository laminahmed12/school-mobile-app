-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Preload academic years and rollover batches before restoring opening balances that reference them.
create or replace function public.restore_backup(p_backup jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_school uuid; v_count bigint:=0; v_result jsonb;
begin
 v_school:=private.my_school();
 if private.my_role()<>'admin' or v_school is null then raise exception 'يُسمح لمدير المدرسة فقط باستعادة النسخة'; end if;
 if p_backup is null or jsonb_typeof(p_backup)<>'object' or p_backup->>'format'<>'lamin-school-backup-v2'
   or p_backup->>'school_filter' is distinct from v_school::text then raise exception 'النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم'; end if;
 if jsonb_typeof(p_backup->'academic_years')='array' then
  insert into public.academic_years select incoming.* from jsonb_populate_recordset(null::public.academic_years,p_backup->'academic_years') incoming
   where incoming.school_id=v_school on conflict do nothing;
 end if;
 if jsonb_typeof(p_backup->'rollover_batches')='array' then
  insert into public.rollover_batches select incoming.* from jsonb_populate_recordset(null::public.rollover_batches,p_backup->'rollover_batches') incoming
   where incoming.school_id=v_school on conflict do nothing;
 end if;
 v_result:=public.restore_backup_core_v4(p_backup);
 if jsonb_typeof(p_backup->'audit_log')='array' and p_backup->>'audit_log_school_id'=v_school::text then
  insert into public.audit_log(school_id,user_id,username,action,entity,entity_id,details,created_at)
  select x.school_id,x.user_id,x.username,x.action,x.entity,x.entity_id,coalesce(x.details,'{}'::jsonb)||jsonb_build_object('restored_from_audit_id',x.id),x.created_at
  from jsonb_to_recordset(p_backup->'audit_log') as x(id bigint,school_id uuid,user_id uuid,username text,action text,entity text,entity_id text,details jsonb,created_at timestamptz)
  where x.school_id=v_school and not exists(select 1 from public.audit_log a where a.school_id=v_school and a.details->>'restored_from_audit_id'=x.id::text);
  get diagnostics v_count=row_count;
 end if;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb)||jsonb_build_object('audit_log',v_count),true);
end $function$;
revoke all on function public.restore_backup(jsonb) from public,anon;
grant execute on function public.restore_backup(jsonb) to authenticated;
