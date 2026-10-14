# Lamīn baseline reconstruction experiment — execution report

**Date:** 2026-10-14  
**Experiment branch:** `experiment/lamin-db-baseline-reconstruction-20261014`  
**Experiment base SHA:** `ae8936c06b6308ab8bbb93975fab2f2439efd8e3`  
**Checkpoint branch:** `checkpoint/lamin-source-checkpoint-20261014` (same base SHA)  
**Decision:** **BLOCKED — no speculative SQL created**

## 1. Stability references

Named source checkpoints were created without moving or rewriting existing refs:

- `checkpoint/lamin-last-verified-flutter-20261014` → `807da91475cc0f53827acb9940c62ca61c8f64d1`. This commit has a successful GitHub Actions run `38530600766` (analysis, tests and Android candidate build all reported success). This validates that CI run's app checks only; it does not validate database migration replay or authorize a release.
- `checkpoint/lamin-source-checkpoint-20261014` → `ae8936c06b6308ab8bbb93975fab2f2439efd8e3`. A source/documentation checkpoint; it is **not** a fully tested release.
- `checkpoint/lamin-db-root-gate-20261014` → `5dab15059a680db013f650049d2e64e1bf415c6e`. Preserves the latest root-cause DB-gate commit, whose clean-rebuild and upgrade workflows failed closed.

The existing `main`, Flutter repair, and DB repair refs were not reset, force-pushed, or rewritten.

## 2. Source recovery attempted

The repository migration directory on the experiment base contains 25 SQL files, beginning in October 2026. It does not contain either required file:

- `supabase/migrations/20260924214051_001_core_tables.sql`
- `test/sql/supabase_test_bootstrap.sql`

The GitHub path-history query for the missing core migration returned an empty commit list. Earlier recovery work also found no exact-path history, trusted release/source artifact, or PR copy for these files. The recorded Supabase migration history includes version `20260924214051`, but its recorded version/name does not include the SQL body.

The live schema reference and current routine definitions describe current state only. They cannot prove the original ordering, defaults, intermediate schema states, role assumptions, or exact historical SQL of the missing baseline. Later finance and RLS migrations are not substitutes for the original core migration. The bootstrap is also not safe to infer: Supabase auth roles, helper functions, grants, and test identities must match the actual historical expectations.

**No replacement SQL file was created.** This is deliberate: there is not enough trustworthy evidence to reconstruct either file without guessing.

## 3. Isolated PostgreSQL CI experiment

Added `.github/workflows/lamin-db-reconstruction-experiment.yml`. The workflow creates an ephemeral PostgreSQL 16 service with disposable credentials, confirms that the user schema is empty, and fails closed unless both original source files exist. It only attempts the replay step if the source gate passes. It does not connect to Supabase production.

Run: [38626886281](https://github.com/laminahmed12/school-mobile-app/actions/runs/38626886281)  
Commit: `eeb207778933d5c2430567b6be6525b524eb952d`  
Result: **FAILURE at the missing-source gate**. PostgreSQL service initialization and the empty-database check passed; the source-presence gate failed; full migration replay was skipped; evidence artifact upload succeeded.

Artifact: `lamin-db-baseline-reconstruction-evidence`  
SHA-256 digest reported by GitHub: `d55976feff2dc692578ec1b38974e99de6334b91c590ee0be5eae84d57b929b1`

This is an actual isolated CI result, but **not** a migration-chain test pass. It demonstrates the blocking condition without manufacturing a green result.

## 4. Files changed in this experiment

Created:
- `.github/workflows/lamin-db-reconstruction-experiment.yml`
- `docs/BASELINE_RECONSTRUCTION_EXPERIMENT_2026-10-14.md` (this report)

Not created or modified:
- `supabase/migrations/20260924214051_001_core_tables.sql`
- `test/sql/supabase_test_bootstrap.sql`
- Any production schema or migration history.
- `main`, the original DB repair branch, or the Flutter repair branch.

## 5. CI evidence and acceptance

- Flutter-only validation run `38530449708`: formatter, analyze and tests all succeeded on `ddda03211898737aa67c0bada77f0b13b44bb2ea`.
- Main scheduled validation run `38530600766`: all reported steps succeeded on `807da91475cc0f53827acb9940c62ca61c8f64d1`; includes candidate APK build, not a declaration that this database recovery is release-ready.
- DB clean-rebuild run `38608150147` and DB upgrade run `38608151296`: failed at the approved migration provenance/source gate.
- Isolated experiment run `38626886281`: empty PostgreSQL startup/check passed; missing source gate failed; chain execution skipped.

No full historical chain replay, clean-database schema equivalence, RLS school-isolation test suite, or backup/restore acceptance test has passed.

## Final decision

**Do not merge or release.** Preserve this branch and its failed CI evidence. Resume reconstruction only if the original source is recovered from a provenance-verifiable artifact, or if a separately reviewed, explicitly non-historical new-baseline strategy is approved. Never label a newly synthesized schema as the original `20260924214051` migration.
