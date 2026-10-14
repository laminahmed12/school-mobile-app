# Lamīn schema extraction — artifact index and final status

**Captured:** 2026-10-14 UTC  
**Project:** `stbrhcgzfxvpayfnnqfl`  
**Working branch:** `fix/lamin-db-recovery-root-cause-20261014`

## Saved sanitized references

- `docs/reference_schema_catalog_2026-10-14.json` — 40 tables from the `public` and `private` schemas, columns/defaults/checks/PK/FK metadata and RLS flags. Row-count fields were stripped.
- `docs/reference_rls_policies_2026-10-14.json` — 99 RLS policy definitions.
- `docs/reference_schema_indexes_2026-10-14.json` — 183 index definitions.
- `docs/reference_schema_triggers_2026-10-14.json` — 68 trigger definitions.
- `docs/reference_routine_signatures_2026-10-14.json` — 46 routine signatures and security types; 34 are reported as SECURITY DEFINER by information_schema.
- `docs/reference_table_grants_summary_2026-10-14.json` — grouped visible table-grant summary.
- `docs/SCHEMA_EXTRACTION_AND_MIGRATION_COMPARISON_2026-10-14.md` — migration blockers, security observations and acceptance decision.

## Data handling

No student, parent, staff, or school application rows were queried or exported. No credentials or API secrets were requested. The table catalog's row counts were intentionally removed. The artifacts are definitions/metadata, not application data.

## Remaining extraction gaps

- View-definition export was blocked at the write/security-check stage and is not claimed as saved.
- A bulk write of function bodies was blocked by safety checks. Individual function definitions are queryable, but the complete reviewed body set is not committed; the signature catalog is the saved artifact.
- Table grants are summarized, not a complete export of function EXECUTE grants, role memberships, object ownership, and effective privileges.
- Migration map remains unresolved (74 production-history entries + 19 repository-only candidates). The original base migration and SQL test bootstrap remain missing.
- No isolated clean-database replay or end-to-end backup/restore test has been performed.

## Decision

**NOT ACCEPTED for merge/release.** Current live-schema references have been preserved on this branch. They do not reconstruct historical migrations and do not justify replacing the missing base migration with a generated schema snapshot. No production DDL, migration, grant, RLS change, merge to `main`, or release was performed.
