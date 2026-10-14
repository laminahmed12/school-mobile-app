# Lamīn database recovery — execution checkpoint
Date: 2026-10-14
Repository: `laminahmed12/school-mobile-app`
Dedicated recovery branch: `fix/lamin-db-recovery-20261014`
Base used: `fix/lamin-postgres-integration-20261014`
Production ref remains unchanged: `main = 807da91475cc0f53827acb9940c62ca61c8f64d1`

## Executive status

**NOT ACCEPTED — source recovery and clean-chain migration tests remain blocked.** This checkpoint preserves the safety boundary. It does not label a guessed schema, archive, or latest-state snapshot as the historical baseline.

## Actions completed in this pass

1. Created the independent branch `fix/lamin-db-recovery-20261014` from the existing PostgreSQL recovery work branch, not from a new project and not by writing to `main`.
2. Inspected the available V3 source archive `school_management_full_stack_v3(1).zip`:
   - SHA-256 `12f3d7b99c409b24680e353a7498639c640ed692311167d8ff5cd48a6865aafb`
   - ZIP integrity test passed; 100 entries.
   - Contains Flutter and a NestJS/Prisma backend; the Prisma schema has 14 models.
   - Does not contain `supabase/migrations/20260924214051_001_core_tables.sql`, `test/sql/supabase_test_bootstrap.sql`, or a Supabase migration chain. Its schema is not interchangeable with the existing live Supabase model.
3. Inspected the earlier `school_management_full_stack(1).zip`:
   - SHA-256 `2ae2c45a649eb0908d30de052e96f3dc6099a56b26d39c98c1a996c95f1a33cb`
   - ZIP integrity test passed; 48 entries.
   - Also contains a Prisma/NestJS implementation, not the missing Supabase SQL.
4. Inspected `lamin-release-apk.zip`:
   - SHA-256 `a698671821b260b767fc680eeee78b8e1b10bc09cc3cee6a430fa12f233f1b92`
   - ZIP integrity test passed; contains only `app-release.apk`. It is not a source backup.
5. Rechecked the migration map and CI gate on the recovery branch. The map still has 93 unresolved rows; the two exact required source files are absent. The workflow explicitly fails closed instead of executing an incomplete chain.
6. Rechecked the production project only through read-only metadata/catalog queries:
   - 40 `public` base tables, 3 `public` views, 99 `public` RLS policies, 39 `public` functions and 7 `private` functions.
   - The Supabase migration ledger has 74 records and includes `20260924214051 / 001_core_tables`.
   - The read-only Storage catalog queries returned no visible buckets or objects.
   - These are current-state observations only; they do not recover the original baseline SQL. No application rows were queried or changed.
7. Exact GitHub code searches for the two missing filenames returned no results. Prior branch/path history, PR, release, and sampled Actions artifact checks remain documented in the existing recovery reports. GitHub connector access does not prove that every unreachable Git object or remote/local reflog has been inspected.

## Required files and test gates

| Requirement | Result |
|---|---|
| Original core migration recovered | No |
| Original test bootstrap recovered | No |
| Migration map resolved with source evidence | No — 93 unresolved |
| Full chain applied to an empty isolated PostgreSQL database | Not run |
| RLS/tenant isolation and role integration verified end-to-end | Not run |
| Backup/restore tested against a clean rebuilt schema | Not run |
| Flutter analysis/tests | Prior run remains evidence: analyze clean, 10 tests passed; not rerun in this container |
| Final APK built | No |

The last recorded PostgreSQL workflow run `38528466520` reached the unresolved-mapping gate and failed there. The database service became ready, SQL parsing and 35 source regression guards passed, but that was **not** a successful migration-chain test.

## Why no replacement SQL was fabricated

The current live schema includes later financial, discount, payroll, backup, audit, and academic-rollover additions. Existing repository migrations use `ALTER TABLE` and foreign-key references that presuppose base objects. A bootstrap copied from the latest live schema could conflict with these migrations or conceal historical drift. A Prisma schema from another implementation would be an unsupported substitution. Neither qualifies as a proven replacement for the missing historical baseline.

## Safe next technical action

Establish a schema-only, provenance-tracked reference from the authoritative current Supabase catalogs (tables/columns, PK/FK/check/unique constraints, indexes, enums, views, function definitions, triggers, RLS policies, grants, and required extension/role assumptions). Keep it clearly labeled as a **current-state reference**, not a historical migration. Review that snapshot against each available migration and the 74 ledger entries. Only after a reviewer-approved baseline reconciliation should a separate test-only bootstrap be authored, followed by full-chain testing in disposable PostgreSQL. Do not run migrations against production or the existing empty Lamin-Test project as an experiment.

## Integrity and release boundary

- No production writes or migrations.
- No deletion/re-numbering of migration files.
- No mapping status was changed to make CI pass.
- No merge to `main`.
- No final APK build.
- Do not claim the root cause is fixed until the source, map, clean-chain execution, security, backup/restore, and CI acceptance gates all pass.
