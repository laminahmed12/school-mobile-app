-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- The audit table predates this feature and uses entity/details/user_id columns.
alter table public.student_discount_awards add column if not exists created_by uuid default auth.uid();

create or replace function public.lamin_write_audit_event()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_old jsonb; v_new jsonb; v_row jsonb; v_school uuid; v_id text;
begin
 if TG_OP='DELETE' then v_old:=to_jsonb(OLD); v_row:=v_old; else v_new:=to_jsonb(NEW); v_row:=v_new; end if;
 v_school:=nullif(v_row->>'school_id','')::uuid;
 v_id:=coalesce(v_row->>'id',v_row->>'school_id','unknown');
 insert into public.audit_log(school_id,user_id,username,action,entity,entity_id,details,created_at)
 values(v_school,auth.uid(),null,TG_OP,TG_TABLE_NAME,v_id,jsonb_build_object('old',v_old,'new',v_new),now());
 if TG_OP='DELETE' then return OLD; else return NEW; end if;
end $function$;
revoke all on function public.lamin_write_audit_event() from public,anon,authenticated;

create or replace function public.lamin_set_updated_at()
returns trigger language plpgsql set search_path=''
as $function$
begin NEW.updated_at:=now(); if NEW.updated_by is null then NEW.updated_by:=auth.uid(); end if; return NEW; end
$function$;
revoke all on function public.lamin_set_updated_at() from public,anon;

drop policy if exists lamin_audit_log_read on public.audit_log;
drop policy if exists lamin_fee_schedules_read on public.fee_schedules;
drop policy if exists lamin_fee_schedules_write on public.fee_schedules;
create policy lamin_fee_schedules_select on public.fee_schedules for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_fee_schedules_insert on public.fee_schedules for insert to authenticated with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_fee_schedules_update on public.fee_schedules for update to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_fee_schedules_delete on public.fee_schedules for delete to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));

drop policy if exists lamin_discount_rules_read on public.discount_rules;
drop policy if exists lamin_discount_rules_write on public.discount_rules;
create policy lamin_discount_rules_select on public.discount_rules for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_discount_rules_insert on public.discount_rules for insert to authenticated with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_discount_rules_update on public.discount_rules for update to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
create policy lamin_discount_rules_delete on public.discount_rules for delete to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));

create index if not exists fee_schedules_school_idx on public.fee_schedules(school_id);
create index if not exists fee_schedules_year_school_idx on public.fee_schedules(academic_year_id,school_id);
create index if not exists discount_rules_school_idx on public.discount_rules(school_id);
create index if not exists discount_awards_assessment_school_student_idx on public.student_discount_awards(fee_assessment_id,school_id,student_id);
create index if not exists discount_awards_rule_school_idx on public.student_discount_awards(discount_rule_id,school_id);
create index if not exists discount_awards_school_idx on public.student_discount_awards(school_id);
create index if not exists opening_balances_year_idx on public.student_opening_balances(academic_year_id);
create index if not exists opening_balances_source_year_idx on public.student_opening_balances(source_academic_year_id);
create index if not exists opening_balances_source_assessment_idx on public.student_opening_balances(source_fee_assessment_id);
create index if not exists payments_assessment_school_student_idx on public.payments(fee_assessment_id,school_id,student_id);

do $$
declare t text;
begin
 foreach t in array array['payments','student_opening_balances','fee_schedules','discount_rules','student_discount_awards'] loop
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name=t and column_name='updated_at') then
   execute format('drop trigger if exists lamin_updated_at on public.%I',t);
   execute format('create trigger lamin_updated_at before update on public.%I for each row execute function public.lamin_set_updated_at()',t);
  end if;
 end loop;
end $$;
