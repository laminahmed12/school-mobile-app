-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
create unique index if not exists classes_id_school_uq on public.classes(id,school_id);
create unique index if not exists enrollments_id_school_student_uq on public.student_enrollments(id,school_id,student_id);

create table if not exists public.financial_adjustments (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null, academic_year_id uuid not null, fee_assessment_id uuid,
 adjustment_type text not null check(adjustment_type in ('waiver','charge','refund','reversal','correction','other')),
 amount numeric(12,2) not null check(amount>0), reason text not null check(length(trim(reason)) between 1 and 500),
 status text not null default 'pending' check(status in ('pending','approved','rejected','reversed')),
 source_adjustment_id uuid references public.financial_adjustments(id) on delete restrict,
 created_at timestamptz not null default now(), created_by uuid default auth.uid(),
 updated_at timestamptz not null default now(), updated_by uuid, approved_at timestamptz, approved_by uuid,
 foreign key(student_id,school_id) references public.students(id,school_id) on delete restrict,
 foreign key(academic_year_id,school_id) references public.academic_years(id,school_id) on delete restrict,
 foreign key(fee_assessment_id,school_id,student_id) references public.student_fee_assessments(id,school_id,student_id) on delete restrict
);
create table if not exists public.rollover_batches (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 source_academic_year_id uuid not null, target_academic_year_id uuid not null,
 status text not null default 'draft' check(status in ('draft','reviewed','approved','running','completed','failed','cancelled')),
 preview jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), created_by uuid default auth.uid(),
 updated_at timestamptz not null default now(), updated_by uuid, approved_at timestamptz, approved_by uuid, completed_at timestamptz, error_summary text,
 foreign key(source_academic_year_id,school_id) references public.academic_years(id,school_id) on delete restrict,
 foreign key(target_academic_year_id,school_id) references public.academic_years(id,school_id) on delete restrict,
 check(source_academic_year_id<>target_academic_year_id), unique(id,school_id)
);
create table if not exists public.rollover_items (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 batch_id uuid not null, student_id uuid not null, source_enrollment_id uuid, target_enrollment_id uuid,
 decision text not null check(decision in ('promote','repeat','graduate','transfer','exclude')),
 source_class_id uuid, target_class_id uuid, source_balance numeric(12,2) not null default 0 check(source_balance>=0),
 opening_balance_id uuid, created_at timestamptz not null default now(), created_by uuid default auth.uid(),
 foreign key(batch_id,school_id) references public.rollover_batches(id,school_id) on delete restrict,
 foreign key(student_id,school_id) references public.students(id,school_id) on delete restrict,
 foreign key(source_enrollment_id,school_id,student_id) references public.student_enrollments(id,school_id,student_id) on delete restrict,
 foreign key(target_enrollment_id,school_id,student_id) references public.student_enrollments(id,school_id,student_id) on delete restrict,
 foreign key(source_class_id,school_id) references public.classes(id,school_id) on delete restrict,
 foreign key(target_class_id,school_id) references public.classes(id,school_id) on delete restrict,
 foreign key(opening_balance_id,school_id,student_id) references public.student_opening_balances(id,school_id,student_id) on delete restrict,
 unique(batch_id,student_id)
);
create table if not exists public.payroll_periods (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 name text not null, starts_on date not null, ends_on date not null, status text not null default 'open' check(status in ('open','closed')),
 created_at timestamptz not null default now(), created_by uuid default auth.uid(), closed_at timestamptz, closed_by uuid,
 check(ends_on>=starts_on), unique(school_id,name)
);
create table if not exists public.salary_assignments (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 payee_type text not null check(payee_type in ('teacher','staff')), payee_id uuid not null,
 amount numeric(12,2) not null check(amount>=0), currency text not null default 'LYD', starts_on date not null, ends_on date,
 note text not null default '', created_at timestamptz not null default now(), created_by uuid default auth.uid(),
 check(ends_on is null or ends_on>=starts_on)
);

alter table public.financial_adjustments enable row level security;
create policy lamin_financial_adjustments_select on public.financial_adjustments for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_financial_adjustments_insert on public.financial_adjustments for insert to authenticated with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_financial_adjustments_update on public.financial_adjustments for update to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
alter table public.rollover_batches enable row level security;
create policy lamin_rollover_batches_select on public.rollover_batches for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
create policy lamin_rollover_batches_insert on public.rollover_batches for insert to authenticated with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_rollover_batches_update on public.rollover_batches for update to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
alter table public.rollover_items enable row level security;
create policy lamin_rollover_items_select on public.rollover_items for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
create policy lamin_rollover_items_insert on public.rollover_items for insert to authenticated with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_rollover_items_update on public.rollover_items for update to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
alter table public.payroll_periods enable row level security;
create policy lamin_payroll_periods_select on public.payroll_periods for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_payroll_periods_write on public.payroll_periods for all to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
alter table public.salary_assignments enable row level security;
create policy lamin_salary_assignments_select on public.salary_assignments for select to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_salary_assignments_insert on public.salary_assignments for insert to authenticated with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_salary_assignments_update on public.salary_assignments for update to authenticated using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin')) with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));

create index if not exists financial_adjustments_school_student_year_idx on public.financial_adjustments(school_id,student_id,academic_year_id);
create index if not exists financial_adjustments_assessment_fk_idx on public.financial_adjustments(fee_assessment_id,school_id,student_id);
create index if not exists rollover_batches_school_years_idx on public.rollover_batches(school_id,source_academic_year_id,target_academic_year_id);
create index if not exists rollover_items_batch_school_idx on public.rollover_items(batch_id,school_id);
create index if not exists payroll_periods_school_dates_idx on public.payroll_periods(school_id,starts_on,ends_on);
create index if not exists salary_assignments_payee_dates_idx on public.salary_assignments(school_id,payee_type,payee_id,starts_on,ends_on);
create trigger lamin_audit_row after insert or update or delete on public.financial_adjustments for each row execute function public.lamin_write_audit_event();
create trigger lamin_audit_row after insert or update or delete on public.rollover_batches for each row execute function public.lamin_write_audit_event();
create trigger lamin_audit_row after insert or update or delete on public.rollover_items for each row execute function public.lamin_write_audit_event();
create trigger lamin_updated_at before update on public.financial_adjustments for each row execute function public.lamin_set_updated_at();
create trigger lamin_updated_at before update on public.rollover_batches for each row execute function public.lamin_set_updated_at();

-- Backup RPC wrappers append these tables to the existing version-2 envelope.
alter function public.export_backup(uuid) rename to export_backup_core_v3;
create or replace function public.export_backup(p_school uuid default null) returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_payload jsonb; v_school uuid;
begin
 v_payload:=public.export_backup_core_v3(p_school); v_school:=(v_payload->>'school_filter')::uuid;
 return v_payload || jsonb_build_object(
 'financial_adjustments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.financial_adjustments t where t.school_id=v_school),
 'rollover_batches',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.rollover_batches t where t.school_id=v_school),
 'rollover_items',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.rollover_items t where t.school_id=v_school),
 'payroll_periods',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.payroll_periods t where t.school_id=v_school),
 'salary_assignments',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.salary_assignments t where t.school_id=v_school));
end $function$;
alter function public.restore_backup(jsonb) rename to restore_backup_core_v3;
create or replace function public.restore_backup(p_backup jsonb) returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_school uuid; v_table text; v_count bigint; v_result jsonb; v_extra jsonb:='{}'::jsonb;
begin
 v_result:=public.restore_backup_core_v3(p_backup); v_school:=private.my_school();
 foreach v_table in array array['financial_adjustments','payroll_periods','salary_assignments','rollover_batches','rollover_items'] loop
  if jsonb_typeof(p_backup->v_table) is distinct from 'array' then continue; end if;
  execute format('insert into public.%I select incoming.* from jsonb_populate_recordset(null::public.%I,$1) incoming where incoming.school_id=$2 on conflict do nothing',v_table,v_table) using p_backup->v_table,v_school;
  get diagnostics v_count=row_count; v_extra:=v_extra||jsonb_build_object(v_table,v_count);
 end loop;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb)||v_extra,true);
end $function$;
