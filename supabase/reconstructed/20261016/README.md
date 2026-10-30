# Lamīn reconstructed database bridge — 2026-10-16

This is a documented replacement path for development and clean-install tests. It does not claim to recover the original SQL from 2026-09-24.

## Canonical source stages
Use the existing catalog-derived stages under `supabase/baselines/20261015/` in this order: `0001_tables_sequences.sql`, stages `0002` through `0009` for routines, `0010_defaults_constraints_indexes_views.sql`, `0011_security_policies_triggers_grants.sql`, then `0012_repo_drift_reconciliation.sql`.

## Safety rules
- Test only against a fresh, disposable PostgreSQL database.
- Run the existing fingerprint and acceptance suite after applying the stages.
- Do not put the baseline snapshots into `supabase/migrations/`: they are not incremental migrations.
- Do not apply the baseline to production, repair production migration history, or claim these files are the original historical sources.
- Keep the original missing-source status visible in the migration-history map.