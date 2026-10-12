-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Additive/non-destructive finance foundation. Existing school/student/payment/license rows are preserved.
alter table public.student_opening_balances
  add column if not exists source_academic_year_id uuid,
  add column if not exists source_fee_assessment_id uuid,
  add column if not exists created_by uuid default auth.uid(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid;
alter table public.student_opening_balances add constraint student_opening_balances_source_year_fk
  foreign key (source_academic_year_id) references public.academic_years(id) on delete restrict;
alter table public.student_opening_balances add constraint student_opening_balances_source_assessment_fk
  foreign key (source_fee_assessment_id) references public.student_fee_assessments(id) on delete restrict;
alter table public.payments
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid,
  add column if not exists idempotency_key text;
create unique index if not exists payments_school_idempotency_key_uq on public.payments(school_id,idempotency_key) where idempotency_key is not null;

create table if not exists public.fee_schedules (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid not null, grade_order integer not null check (grade_order>=0),
  term text not null check (length(trim(term)) between 1 and 80), amount numeric(12,2) not null check (amount>=0),
  due_date date, active boolean not null default true, note text not null default '',
  created_at timestamptz not null default now(), created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(), updated_by uuid,
  constraint fee_schedules_year_school_fk foreign key (academic_year_id,school_id)
    references public.academic_years(id,school_id) on delete restrict,
  constraint fee_schedules_school_year_grade_term_uq unique(school_id,academic_year_id,grade_order,term),
  constraint fee_schedules_id_school_uq unique(id,school_id)
);
create table if not exists public.discount_rules (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null check(length(trim(name)) between 1 and 120),
  rule_type text not null check(rule_type in ('sibling','category','scholarship','manual','other')),
  value_type text not null check(value_type in ('fixed','percent')), value numeric(12,2) not null check(value>=0),
  max_amount numeric(12,2), stacking_policy text not null default 'max_only' check(stacking_policy in ('stack','max_only')),
  cap_amount numeric(12,2), conditions jsonb not null default '{}'::jsonb, active boolean not null default true,
  starts_on date, ends_on date, created_at timestamptz not null default now(), created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(), updated_by uuid,
  constraint discount_rules_percent_ck check(value_type<>'percent' or value<=100),
  constraint discount_rules_max_ck check(max_amount is null or max_amount>=0),
  constraint discount_rules_cap_ck check(cap_amount is null or cap_amount>=0),
  constraint discount_rules_dates_ck check(ends_on is null or starts_on is null or ends_on>=starts_on),
  constraint discount_rules_id_school_uq unique(id,school_id)
);
create table if not exists public.student_discount_awards (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null, fee_assessment_id uuid not null, discount_rule_id uuid,
  rule_snapshot jsonb not null default '{}'::jsonb, amount numeric(12,2) not null check(amount>=0),
  reason text not null check(length(trim(reason)) between 1 and 500),
  status text not null default 'pending' check(status in ('pending','approved','rejected','reversed')),
  requested_by uuid default auth.uid(), created_by uuid default auth.uid(), created_at timestamptz not null default now(),
  updated_by uuid, updated_at timestamptz not null default now(), approved_by uuid, approved_at timestamptz,
  reversed_by uuid, reversed_at timestamptz,
  constraint discount_awards_student_assessment_fk foreign key(fee_assessment_id,school_id,student_id)
    references public.student_fee_assessments(id,school_id,student_id) on delete restrict,
  constraint discount_awards_rule_school_fk foreign key(discount_rule_id,school_id)
    references public.discount_rules(id,school_id) on delete restrict
);

alter table public.fee_schedules enable row level security;
create policy lamin_fee_schedules_select on public.fee_schedules for select to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_fee_schedules_insert on public.fee_schedules for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_fee_schedules_update on public.fee_schedules for update to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'))
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_fee_schedules_delete on public.fee_schedules for delete to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));

alter table public.discount_rules enable row level security;
create policy lamin_discount_rules_select on public.discount_rules for select to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_discount_rules_insert on public.discount_rules for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_discount_rules_update on public.discount_rules for update to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'))
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
create policy lamin_discount_rules_delete on public.discount_rules for delete to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));

alter table public.student_discount_awards enable row level security;
create policy lamin_discount_awards_read on public.student_discount_awards for select to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_discount_awards_insert on public.student_discount_awards for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant') and (requested_by is null or requested_by=(select auth.uid())));
create policy lamin_discount_awards_update on public.student_discount_awards for update to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'))
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));

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
do $$
declare t text;
begin
 foreach t in array array['payments','student_opening_balances','fee_schedules','discount_rules','student_discount_awards'] loop
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name=t and column_name='updated_at') then
   execute format('drop trigger if exists lamin_updated_at on public.%I',t);
   execute format('create trigger lamin_updated_at before update on public.%I for each row execute function public.lamin_set_updated_at()',t);
  end if;
 end loop;
 foreach t in array array['payments','student_fee_assessments','student_opening_balances','fee_schedules','discount_rules','student_discount_awards'] loop
  execute format('drop trigger if exists lamin_audit_row on public.%I',t);
  execute format('create trigger lamin_audit_row after insert or update or delete on public.%I for each row execute function public.lamin_write_audit_event()',t);
 end loop;
end $$;
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
