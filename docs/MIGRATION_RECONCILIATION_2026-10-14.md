# Lamin migration reconciliation — 2026-10-14

Status: **BLOCKED — do not apply migrations to production or claim a clean-chain pass.**

## Read-only inventory

- Production Supabase project: `stbrhcgzfxvpayfnnqfl` (read-only inspection only).
- Production migration history entries: 74.
- SQL migration files present on the release-readiness branch: 25.
- Exact version-and-name matches between production history and repository: 0.
- Production history entries without an exact version-and-name match: 74.
- Repository-only migration files not mapped to a production history entry: 19.
- Six filenames have a similar normalized name, but their timestamps/versions differ; these remain unresolved until source-level equivalence is proved.

## Consequences

1. The repository does not contain the recorded bootstrap migration `20260924214051_001_core_tables.sql`.
2. The repository migration filenames and the production history are materially out of sync. Similar names are not sufficient evidence that SQL contents and application order match.
3. The existing `Lamin-Test` Supabase project is `ACTIVE_HEALTHY`, but its public schema has no tables and its migration history is empty. It has not been modified.
4. The temporary PostgreSQL CI job may validate SQL syntax and finance regression fixtures, but those checks are not execution of the complete Supabase migration chain.
5. No production migration was applied. No database rows were written.

## Required before full-chain testing

- Recover or authoritatively reconstruct the missing historical migration source from a trusted schema/source record.
- Review every row in `supabase/migration_history_map.csv`; resolve renamed files, unapplied candidates, and missing production migrations without guessing.
- Provide a disposable Supabase-compatible bootstrap for `auth`, roles, and `private` helper functions.
- Only then enable clean-schema execution in CI. Never use `Lamin-Test` or production to trial a partial/guessed chain.

The CSV is intentionally fail-closed: only exact version-and-name matches are marked `mapped`; every uncertain or repository-only migration remains `unresolved` until reviewed.
