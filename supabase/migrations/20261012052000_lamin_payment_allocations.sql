-- Applied to Supabase project stbrhcgzfxvpayfnnqfl on 2026-10-12 (UTC+02:00).
-- Payment allocations preserve the source payment and constrain total active allocations to payment amount.
create unique index if not exists payments_id_school_student_uq on public.payments(id,school_id,student_id);
create unique index if not exists opening_balances_id_school_student_uq on public.student_opening_balances(id,school_id,student_id);
create table if not exists public.payment_allocations (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null, payment_id uuid not null, fee_assessment_id uuid, opening_balance_id uuid,
 amount numeric(12,2) not null check(amount>0), allocated_at timestamptz not null default now(),
 created_at timestamptz not null default now(), created_by uuid default auth.uid(),
 reversed_at timestamptz, reversed_by uuid, reversal_reason text,
 constraint payment_allocations_payment_fk foreign key(payment_id,school_id,student_id)
  references public.payments(id,school_id,student_id) on delete restrict,
 constraint payment_allocations_assessment_fk foreign key(fee_assessment_id,school_id,student_id)
  references public.student_fee_assessments(id,school_id,student_id) on delete restrict,
 constraint payment_allocations_opening_fk foreign key(opening_balance_id,school_id,student_id)
  references public.student_opening_balances(id,school_id,student_id) on delete restrict,
 constraint payment_allocations_one_target_ck check((fee_assessment_id is not null)::int+(opening_balance_id is not null)::int=1)
);
create unique index if not exists payment_allocations_payment_assessment_uq on public.payment_allocations(payment_id,fee_assessment_id)
 where fee_assessment_id is not null and reversed_at is null;
create unique index if not exists payment_allocations_payment_opening_uq on public.payment_allocations(payment_id,opening_balance_id)
 where opening_balance_id is not null and reversed_at is null;
create index if not exists payment_allocations_school_student_idx on public.payment_allocations(school_id,student_id);
create index if not exists payment_allocations_assessment_fk_idx on public.payment_allocations(fee_assessment_id,school_id,student_id);
create index if not exists payment_allocations_opening_fk_idx on public.payment_allocations(opening_balance_id,school_id,student_id);
alter table public.payment_allocations enable row level security;
create policy lamin_payment_allocations_select on public.payment_allocations for select to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant'));
create policy lamin_payment_allocations_insert on public.payment_allocations for insert to authenticated
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin','accountant') and (created_by is null or created_by=(select auth.uid())));
create policy lamin_payment_allocations_update on public.payment_allocations for update to authenticated
 using(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'))
 with check(school_id=(select private.my_school()) and (select private.my_role()) in ('owner','admin'));
create or replace function public.lamin_validate_payment_allocation()
returns trigger language plpgsql set search_path=''
as $function$
declare v_payment_amount numeric(12,2); v_allocated numeric(12,2);
begin
 if NEW.reversed_at is not null then return NEW; end if;
 select p.amount into v_payment_amount from public.payments p
  where p.id=NEW.payment_id and p.school_id=NEW.school_id and p.student_id=NEW.student_id for update;
 if v_payment_amount is null then raise exception 'الدفعة غير موجودة ضمن حساب الطالب والمدرسة'; end if;
 select coalesce(sum(a.amount),0) into v_allocated from public.payment_allocations a
  where a.payment_id=NEW.payment_id and a.reversed_at is null and a.id<>NEW.id;
 if v_allocated+NEW.amount>v_payment_amount then raise exception 'مجموع تخصيصات الدفعة يتجاوز مبلغ الدفعة'; end if;
 return NEW;
end $function$;
revoke all on function public.lamin_validate_payment_allocation() from public,anon,authenticated;
create trigger lamin_validate_payment_allocation before insert or update on public.payment_allocations
 for each row execute function public.lamin_validate_payment_allocation();
create trigger lamin_audit_row after insert or update or delete on public.payment_allocations
 for each row execute function public.lamin_write_audit_event();

-- Backup wrappers keep the existing v2 JSON format and add payment allocations.
alter function public.export_backup(uuid) rename to export_backup_core_v2;
create or replace function public.export_backup(p_school uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_payload jsonb;
begin
 v_payload:=public.export_backup_core_v2(p_school);
 return v_payload || jsonb_build_object('payment_allocations',
  (select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb) from public.payment_allocations a where a.school_id=(v_payload->>'school_filter')::uuid));
end $function$;
alter function public.restore_backup(jsonb) rename to restore_backup_core_v2;
create or replace function public.restore_backup(p_backup jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_school uuid; v_count bigint:=0; v_result jsonb;
begin
 v_result:=public.restore_backup_core_v2(p_backup);
 v_school:=private.my_school();
 if jsonb_typeof(p_backup->'payment_allocations')='array' then
  insert into public.payment_allocations select incoming.* from jsonb_populate_recordset(null::public.payment_allocations,p_backup->'payment_allocations') incoming
  where incoming.school_id=v_school on conflict do nothing;
  get diagnostics v_count=row_count;
 end if;
 return jsonb_set(v_result,'{restored}',coalesce(v_result->'restored','{}'::jsonb)||jsonb_build_object('payment_allocations',v_count),true);
end $function$;
