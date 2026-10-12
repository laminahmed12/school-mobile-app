-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Reviewed rollover wizard is the only exposed path for bulk promotion and debt carry.
revoke all on function public.carry_forward_open_balances(uuid,uuid) from public,anon,authenticated;
revoke all on function public.promote_passed_students(uuid,uuid) from public,anon,authenticated;
revoke all on function public.set_student_promotion(uuid,uuid,text) from public,anon,authenticated;

-- Creating a target year must not close or migrate the source year before review.
create or replace function public.create_next_academic_year(
 p_name text,p_starts_on date default null,p_ends_on date default null,
 p_migrate_students boolean default true,p_migrate_staff boolean default true
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare sid uuid:=private.my_school(); v_role text:=private.my_role(); v_id uuid;
begin
 if sid is null or v_role not in ('owner','admin') then raise exception 'غير مصرح'; end if;
 if length(btrim(coalesce(p_name,'')))<3 or length(btrim(p_name))>60 then raise exception 'اسم السنة الدراسية غير صالح'; end if;
 if p_starts_on is not null and p_ends_on is not null and p_ends_on<p_starts_on then raise exception 'تاريخ نهاية السنة يسبق بدايتها'; end if;
 if exists(select 1 from public.academic_years where school_id=sid and lower(name)=lower(btrim(p_name))) then raise exception 'اسم السنة الدراسية موجود مسبقاً'; end if;
 insert into public.academic_years(school_id,name,starts_on,ends_on,active,is_closed)
 values(sid,btrim(p_name),p_starts_on,p_ends_on,false,false) returning id into v_id;
 return v_id;
end $function$;
revoke all on function public.create_next_academic_year(text,date,date,boolean,boolean) from public,anon;
grant execute on function public.create_next_academic_year(text,date,date,boolean,boolean) to authenticated;
