-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Keep internal backup implementation functions inaccessible through the exposed API.
revoke all on function public.export_backup(uuid) from public, anon;
revoke all on function public.restore_backup(jsonb) from public, anon;
grant execute on function public.export_backup(uuid) to authenticated;
grant execute on function public.restore_backup(jsonb) to authenticated;
revoke all on function public.export_backup_core_v2(uuid) from public, anon, authenticated;
revoke all on function public.export_backup_core_v3(uuid) from public, anon, authenticated;
revoke all on function public.export_backup_core_v4(uuid) from public, anon, authenticated;
revoke all on function public.restore_backup_core_v2(jsonb) from public, anon, authenticated;
revoke all on function public.restore_backup_core_v3(jsonb) from public, anon, authenticated;
revoke all on function public.restore_backup_core_v4(jsonb) from public, anon, authenticated;

-- Preserve audit history in exports; re-import audit entries idempotently using source id in details.
alter function public.export_backup(uuid) rename to export_backup_core_v5;
create or replace function public.export_backup(p_school uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_payload jsonb; v_school uuid;
begin
 v_payload:=public.export_backup_core_v5(p_school); v_school:=(v_payload->>'school_filter')::uuid;
 return v_payload || jsonb_build_object(
  'audit_log',(select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at),'[]'::jsonb) from public.audit_log a where a.school_id=v_school),
  'audit_log_school_id',v_school);
end $function$;
revoke all on function public.export_backup_core_v5(uuid) from public,anon,authenticated;

alter function public.restore_backup(jsonb) rename to restore_backup_core_v5;
create or replace function public.restore_backup(p_backup jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_school uuid; v_count bigint:=0; v_result jsonb;
begin
 v_result:=public.restore_backup_core_v5(p_backup); v_school:=private.my_school();
 if jsonb_typeof(p_backup->'audit_log')='array' and p_backup->>'audit_log_school_id'=v_school::text then
  insert into public.audit_log(school_id,user_id,username,action,entity,entity_id,details,created_at)
  select x.school_id,x.user_id,x.username,x.action,x.entity,x.entity_id,
    coalesce(x.details,'{}'::jsonb)||jsonb_build_object('restored_from_audit_id',x.id),x.created_at
  from jsonb_to_recordset(p_backup->'audit_log') as x(
    id bigint,school_id uuid,user_id uuid,username text,action text,entity text,entity_id text,details jsonb,created_at timestamptz)
  where x.school_id=v_school and not exists(select 1 from public.audit_log a
    where a.school_id=v_school and a.details->>'restored_from_audit_id'=x.id::text);
  get diagnostics v_count=row_count;
 end if;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb)||jsonb_build_object('audit_log',v_count),true);
end $function$;
revoke all on function public.export_backup(uuid) from public,anon;
revoke all on function public.restore_backup(jsonb) from public,anon;
grant execute on function public.export_backup(uuid) to authenticated;
grant execute on function public.restore_backup(jsonb) to authenticated;
revoke all on function public.restore_backup_core_v5(jsonb) from public,anon,authenticated;
