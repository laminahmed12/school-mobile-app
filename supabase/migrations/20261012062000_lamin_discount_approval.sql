-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
alter table public.student_fee_assessments add column if not exists manual_discount numeric(12,2) not null default 0;
update public.student_fee_assessments set manual_discount=discount where manual_discount=0 and discount>0;
create or replace function public.lamin_capture_manual_discount()
returns trigger language plpgsql set search_path=''
as $function$
begin
 if current_setting('lamin.sync_award_discount',true)='on' then
  if TG_OP='UPDATE' then NEW.manual_discount:=OLD.manual_discount; end if;
 else NEW.manual_discount:=coalesce(NEW.discount,0); end if;
 return NEW;
end $function$;
revoke all on function public.lamin_capture_manual_discount() from public,anon,authenticated;
create trigger lamin_capture_manual_discount before insert or update of discount on public.student_fee_assessments for each row execute function public.lamin_capture_manual_discount();

create or replace function public.lamin_validate_discount_award()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_fee numeric(12,2); v_manual numeric(12,2); v_existing numeric(12,2); v_rule record; v_existing_rule numeric(12,2);
begin
 if TG_OP='INSERT' and NEW.status<>'pending' then raise exception 'يجب إنشاء الخصم بحالة انتظار الاعتماد'; end if;
 if TG_OP='UPDATE' and NEW.status is distinct from OLD.status and NEW.status in ('approved','rejected','reversed') and private.my_role() not in ('owner','admin') then raise exception 'اعتماد الخصومات متاح للمدير فقط'; end if;
 if NEW.status='approved' then
  select sfa.total_fee,sfa.manual_discount into v_fee,v_manual from public.student_fee_assessments sfa where sfa.id=NEW.fee_assessment_id and sfa.school_id=NEW.school_id and sfa.student_id=NEW.student_id;
  if not found then raise exception 'استحقاق الرسوم غير موجود'; end if;
  select dr.* into v_rule from public.discount_rules dr where dr.id=NEW.discount_rule_id and dr.school_id=NEW.school_id;
  if NEW.discount_rule_id is not null and not found then raise exception 'قاعدة الخصم لا تخص المدرسة الحالية'; end if;
  if NEW.discount_rule_id is not null and v_rule.max_amount is not null and NEW.amount>v_rule.max_amount then raise exception 'قيمة الخصم تتجاوز الحد المسموح للقاعدة'; end if;
  select coalesce(sum(a.amount),0) into v_existing from public.student_discount_awards a where a.fee_assessment_id=NEW.fee_assessment_id and a.school_id=NEW.school_id and a.status='approved' and a.id<>NEW.id;
  if coalesce(v_rule.stacking_policy,'max_only')='max_only' and v_existing>0 then raise exception 'قاعدة الخصم لا تسمح بدمج أكثر من خصم على الاستحقاق'; end if;
  if v_manual+v_existing+NEW.amount>v_fee then raise exception 'إجمالي الخصومات يتجاوز رسوم الطالب'; end if;
  if NEW.discount_rule_id is not null and v_rule.cap_amount is not null then
   select coalesce(sum(a.amount),0) into v_existing_rule from public.student_discount_awards a where a.fee_assessment_id=NEW.fee_assessment_id and a.school_id=NEW.school_id and a.discount_rule_id=NEW.discount_rule_id and a.status='approved' and a.id<>NEW.id;
   if v_existing_rule+NEW.amount>v_rule.cap_amount then raise exception 'إجمالي الخصم يتجاوز سقف القاعدة'; end if;
  end if;
  if TG_OP='INSERT' or OLD.status is distinct from NEW.status then NEW.approved_by:=auth.uid(); NEW.approved_at:=now(); end if;
 elsif NEW.status='reversed' and (TG_OP='INSERT' or OLD.status is distinct from NEW.status) then NEW.reversed_by:=auth.uid(); NEW.reversed_at:=now();
 end if;
 return NEW;
end $function$;
revoke all on function public.lamin_validate_discount_award() from public,anon,authenticated;
create trigger lamin_validate_discount_award before insert or update on public.student_discount_awards for each row execute function public.lamin_validate_discount_award();

create or replace function public.lamin_sync_award_discount()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_assessment uuid; v_school uuid; v_student uuid; v_fee numeric(12,2); v_manual numeric(12,2); v_awards numeric(12,2);
begin
 if TG_OP='DELETE' then v_assessment:=OLD.fee_assessment_id; v_school:=OLD.school_id; v_student:=OLD.student_id;
 else v_assessment:=NEW.fee_assessment_id; v_school:=NEW.school_id; v_student:=NEW.student_id; end if;
 select sfa.total_fee,sfa.manual_discount into v_fee,v_manual from public.student_fee_assessments sfa where sfa.id=v_assessment and sfa.school_id=v_school and sfa.student_id=v_student;
 if not found then if TG_OP='DELETE' then return OLD; else return NEW; end if; end if;
 select coalesce(sum(a.amount),0) into v_awards from public.student_discount_awards a where a.fee_assessment_id=v_assessment and a.school_id=v_school and a.status='approved';
 perform set_config('lamin.sync_award_discount','on',true);
 update public.student_fee_assessments set discount=least(v_fee,v_manual+v_awards) where id=v_assessment and school_id=v_school and student_id=v_student;
 perform set_config('lamin.sync_award_discount','off',true);
 if TG_OP='DELETE' then return OLD; else return NEW; end if;
end $function$;
revoke all on function public.lamin_sync_award_discount() from public,anon,authenticated;
create trigger lamin_sync_award_discount after insert or update or delete on public.student_discount_awards for each row execute function public.lamin_sync_award_discount();

drop policy if exists lamin_discount_awards_insert on public.student_discount_awards;
create policy lamin_discount_awards_insert on public.student_discount_awards for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant')
 and status='pending' and (requested_by is null or requested_by=(select auth.uid()))
 and (created_by is null or created_by=(select auth.uid())));
