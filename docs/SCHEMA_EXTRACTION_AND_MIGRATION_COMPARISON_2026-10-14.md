# Lamīn — Schema extraction and migration comparison

**Capture time:** 2026-10-14 16:53 UTC  
**Supabase project ref:** `stbrhcgzfxvpayfnnqfl`  
**Git branch:** `fix/lamin-db-recovery-root-cause-20261014`  
**Branch head before this report:** `d53ec1e0665103dc17cc6f53f1fcd0519291ec6b`

## Executed read-only extraction

The authorized Supabase connector successfully returned metadata from the live PostgreSQL 17.6 database. The committed file `docs/reference_schema_catalog_2026-10-14.json` captures the current public/private table catalog (40 tables), including columns, defaults, check metadata, primary keys, foreign-key relationships, and RLS-enabled flags. Table row counts were removed before committing. No application records or secrets were exported.

Additional read-only catalog queries succeeded for:
- 99 RLS policies in `public/private`
- 183 indexes
- 68 triggers
- 3 public views
- 46 routine signatures across `public/private`
- 74 production migration history entries

The live catalog can also return individual function definitions through `pg_get_functiondef`; however, a combined bulk export/write attempt was blocked by security checks. Therefore, **a complete routine-body dump is not claimed or committed in this report**. Function body extraction needs to be completed in smaller reviewed batches or through a trusted schema-only dump tool.

## Migration-history comparison

Supabase's recorded history contains 74 versions, including:
- `20260924214051` — `001_core_tables`
- `20260924214123` — `002_rls_policies_rpcs`

The checked-in `supabase/migration_history_map.csv` has 93 rows (74 production-history entries plus 19 repository-only candidates); all remain `unresolved`. Several files have similar names but different versions. Similar names do not prove historical equivalence.

Still missing from the source repository:
- `supabase/migrations/20260924214051_001_core_tables.sql`
- `test/sql/supabase_test_bootstrap.sql`

No replacement migration was fabricated from the live schema. The production catalog represents current state only and cannot establish the exact contents or order of each historical migration.

## Security observations

The Supabase Security Advisor reported:
- **3 tables with RLS enabled but no policies:** `public.license_codes`, `public.login_attempts`, and `public.owner_gate_attempts`.
- **13 SECURITY DEFINER functions callable by authenticated users**, including sensitive operations such as bootstrap, backup/restore, OneDrive access, and school settings. Each function needs a deliberate authorization review; this is not proof every finding is exploitable.
- **Leaked-password protection disabled** in Supabase Auth.

These are findings for review only. No production ACL, RLS, function, Auth, or schema changes were applied.

## What remains incomplete

1. Full function bodies are not included in the committed snapshot.
2. Complete grants, role memberships, object ownership, and effective ACLs have not yet been exported.
3. No isolated empty PostgreSQL/Supabase database replay was executed; this environment has no local `psql`, `postgres`, Docker, or Flutter CLI.
4. Historical chain replay remains blocked by the missing original files and unresolved migration map.
5. Backup/restore and school-isolation tests have not been passed by this work.

## Acceptance decision

**NOT ACCEPTED.** A sanitized current-state schema reference is now committed, but it is not a substitute for historical migration sources and does not prove a clean-database migration pass. No production writes, merges to `main`, or releases were performed.
