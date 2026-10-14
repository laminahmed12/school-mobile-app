# Lamīn database test infrastructure checkpoint — 2026-10-14

Branch: `fix/lamin-db-recovery-root-cause-20261014`

## Environment

GitHub Actions supports disposable PostgreSQL service containers through `jobs.<job>.services`. The repository already used this pattern; the two new manual workflows isolate their own databases and do not require Docker on the developer's device:

- `.github/workflows/lamin-db-clean-rebuild.yml`
- `.github/workflows/lamin-db-upgrade.yml`

Both workflows save environment and source-gate logs as run artifacts. The source gate runs before any bootstrap, restore, or migration command. Shell pipeline failure propagation is enabled so `tee` cannot mask a failing gate. Workflow permissions are read-only for repository contents.

## Execution safety

`scripts/db-tests/require-approved-source.py` is a fail-closed provenance gate. It requires an approved `test/sql/approved_migration_source_manifest.json`, a full source commit SHA, reviewer and evidence URL, hashes and provenance URLs for all 74 production migrations and the bootstrap, and reviewed SQL suites for schema invariants, RLS/authorization, tenant isolation, and backup/restore. Upgrade mode additionally requires a hash-verified baseline dump, a schema fingerprint, and an explicit post-baseline migration list.

The clean runner refuses any database except `lamin_clean_test` and checks that it is empty before applying anything. The upgrade runner similarly refuses any database except `lamin_upgrade_test`, checks that it is empty, restores only the manifest-approved baseline, and applies only the approved post-baseline list. Neither runner contains production connection settings or targets a Supabase project.

**No approved manifest, baseline dump, or reviewed verification suite was fabricated.** Those required artifacts are not currently present, so the gate must block execution. The runners and workflows are preparation, not proof of a successful rebuild or upgrade.

## Per-record migration evidence review

The classification CSV enumerates each of the 93 records independently. Its evidence is limited to the available Supabase migration-history metadata and repository file map; it is not evidence that SQL bodies are equivalent or that a source is absent from all Git objects/backups.

- **68 production-history rows:** relabelled from the over-strong `MISSING_SOURCE` to `NO_EXACT_REPOSITORY_FILENAME_MATCH`. Evidence: the recorded production version/name has no exact normalized file match in the inspected repository map. This does not prove that no recoverable source exists elsewhere.
- **6 production-history rows with similarly named repository files:** remain `CANDIDATE_NEEDS_CONTENT_PROOF`. The repository search did not surface authoritative matching historical SQL bodies. Filename similarity cannot establish equivalence; none is approved for replay.
- **19 repository-only candidate files:** remain `REPOSITORY_ONLY_NO_PRODUCTION_MATCH`. The available history does not establish that they were deployed, not deployed, or applied under a different version. Do not replay them against a populated database without a content/effects reconciliation.

A code-search attempt for each of the six candidate migration name stems returned no matches from the search tool's default-branch index. That is a limited negative result, not proof that the source is absent from all branches, Git objects, artifacts, or external backups.

## Current test status

- PostgreSQL service capability: **confirmed by repository workflow configuration**.
- Source provenance gate: **implemented; expected to block while the approved manifest is absent**.
- Clean rebuild: **not run**.
- Trusted-baseline upgrade: **not run**.
- RLS/authorization, cross-school isolation, schema invariants, and backup/restore suites: **required by the gate but not yet authored or executed**, because their assertions must be derived from an approved schema/source contract rather than guessed.
- No production SQL was executed; no migration was applied to production; no merge to `main`; no APK release.

## Next valid transition

Recover and review authoritative migration SQL, bootstrap requirements, and a trusted baseline snapshot. Populate and review the source manifest with SHA-256 hashes and provenance. Author independent verification suites against the approved source/authorization contract. Then dispatch each workflow separately and retain its run logs/artifacts. A workflow's environment start or a passing source gate alone is not a database-test pass.
