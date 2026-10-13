-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
create or replace function public.lamin_guard_rollover_year_state()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if TG_OP='INSERT' or NEW.status='running' then
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.source_academic_year_id and ay.school_id=NEW.school_id and ay.active=true and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة المصدر يجب أن تكون السنة النشطة غير المغلقة';
  end if;
  if not exists(select 1 from public.academic_years ay where ay.id=NEW.target_academic_year_id and ay.school_id=NEW.school_id and ay.active=false and coalesce(ay.is_closed,false)=false) then
   raise exception 'السنة الهدف يجب أن تكون سنة غير نشطة وغير مغلقة';
  end if;
 end if;
 return NEW;
end $function$;
revoke all on function public.lamin_guard_rollover_year_state() from public,anon,authenticated;
drop trigger if exists lamin_guard_rollover_year_state on public.rollover_batches;
create trigger lamin_guard_rollover_year_state before insert or update of status on public.rollover_batches for each row execute function public.lamin_guard_rollover_year_state();
