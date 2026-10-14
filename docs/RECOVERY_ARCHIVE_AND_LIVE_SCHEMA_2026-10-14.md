# Lamīn — Archive and Live Schema Recovery Follow-up
**Date:** 2026-10-14  
**Branch:** `fix/lamin-postgres-integration-20261014`  
**Scope:** Read-only source-recovery investigation. No production writes, no migration execution, no merge to `main`, and no APK build.

## Findings

### 1. The available V3 archive is not a recovery source for the missing Supabase SQL files
The Library archive `school_management_full_stack_v3(1).zip` was materialized and inspected as a ZIP:
- SHA-256: `12f3d7b99c409b24680e353a7498639c640ed692311167d8ff5cd48a6865aafb`
- 100 entries; ZIP integrity test passed.
- Contains a Flutter mobile app, a NestJS backend, and `backend/prisma/schema.prisma`.
- Does not contain a `supabase/` directory, Supabase migration SQL, or `test/sql/supabase_test_bootstrap.sql`.

Its Prisma schema defines 14 models (including `School`, `Student`, `StudentInvoice`, `Attendance`, and `GradeEntry`). The current Supabase project has a materially different schema and financial model; the archive is therefore a separate implementation/scaffold, not evidence of the exact historical migration source. Do not transplant its Prisma schema into the existing project.

The older `school_management_full_stack(1).zip` is also a separate, smaller implementation. Its ZIP integrity test passed; it likewise contains no Supabase migration chain or test bootstrap.

### 2. Live Supabase schema metadata was inspected read-only
Project `School-Management` (`stbrhcgzfxvpayfnnqfl`) returned:
- 40 base tables in `public`
- 3 views in `public`
- 99 RLS policies in `public`
- 39 functions in `public` and 7 in `private`

The 40 public tables include the core school/student tables plus the financial and rollover model: `schools`, `students`, `teachers`, `academic_years`, `student_fee_assessments`, `student_opening_balances`, `payments`, `payment_allocations`, `discount_rules`, `student_discount_awards`, `payroll_periods`, `payroll_transactions`, `rollover_batches`, and `rollover_items`, among others. Only catalog metadata was queried; no application rows were read.

The production migration history reports 74 versions and includes version `20260924214051` named `001_core_tables`. This establishes that the migration is recorded as applied, not that its original SQL body can be recovered from the migration history table.

A read-only query against `storage.buckets` returned no rows, and a read-only query against `storage.objects` returned no rows. This found no visible Storage bucket/object backup candidate through those queries; it does not prove no external backup exists or that the connected role can see every storage object.

### 3. Existing migration files confirm the missing base source is a real blocker
For example, `20261012045500_lamin_finance_foundation.sql` adds columns to existing tables and creates finance tables with foreign keys to `public.schools` and `public.academic_years`. It assumes the core schema already exists; it cannot safely substitute for `001_core_tables.sql`.

The test bootstrap is also absent. The latest PostgreSQL workflow failed at the explicit unresolved-mapping gate (93 unresolved rows); the full migration chain was not executed. SQL parsing and regression guards do not constitute a clean-database migration pass.

### 4. Recovery search status
- Exact-name GitHub code searches for both missing files returned no results.
- Previously checked branches/path history, PRs, release listings, and sampled Actions artifacts yielded no source copy.
- The GitHub connector does not expose a reliable way to inspect all unreachable Git objects/reflogs. No claim is made that every unreachable object was inspected.
- No original file has been reconstructed or fabricated.

## Decision
**Do not synthesize or apply a replacement migration from live schema metadata.** The live schema can support a separately labelled schema-only forensic snapshot if a supported export route is established, but such a snapshot is not the original migration and must not be marked as a recovered historical source.

Keep the PostgreSQL migration gate closed until the exact source/bootstrap files or a verifiable source-equivalent artifact are recovered and the 93-entry map is resolved with evidence. Keep `main` unchanged, make no production writes, and do not build the final APK.
