-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Existing assessment.discount remains the user-facing total; manual_discount is the baseline excluding approved award records.
create or replace function public.lamin_capture_manual_discount()
returns trigger language plpgsql set search_path=''
as $function$
declare v_awards numeric(12,2):=0;
begin
 if current_setting('lamin.sync_award_discount',true)='on' then
  if TG_OP='UPDATE' then NEW.manual_discount:=OLD.manual_discount; end if;
 elsif TG_OP='INSERT' then NEW.manual_discount:=coalesce(NEW.discount,0);
 elsif NEW.discount is distinct from OLD.discount then
  select coalesce(sum(a.amount),0) into v_awards from public.student_discount_awards a
   where a.fee_assessment_id=NEW.id and a.school_id=NEW.school_id and a.status='approved';
  NEW.manual_discount:=greatest(coalesce(NEW.discount,0)-v_awards,0);
 else NEW.manual_discount:=OLD.manual_discount;
 end if;
 return NEW;
end
$function$;
