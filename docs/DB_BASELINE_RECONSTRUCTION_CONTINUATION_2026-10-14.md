# Lamīn database baseline recovery — continuation execution record

Date: 2026-10-14
Repository: https://github.com/laminahmed12/school-mobile-app

## Git safety and starting point

- Main observed at `807da91475cc0f53827acb9940c62ca61c8f64d1`; it was not modified.
- Existing stable recovery checkpoint: `checkpoint/lamin-db-root-gate-20261014` at `5dab15059a680db013f650049d2e64e1bf415c6e`.
- The requested branch name `experiment/lamin-db-baseline-reconstruction-20261014` already existed at `2313185809c33fe7bbe5356bd8f02f569035fbb9`. Its history diverged from the current recovery checkpoint (15 commits ahead and 2 behind, merge base `ae8936c06b6308ab8bbb93975fab2f2439efd8e3`). It was preserved without reset or force-push.
- Created continuation branch `experiment/lamin-db-baseline-reconstruction-20261014-continuation` directly from the current checkpoint SHA above. The branch started one commit ahead after adding its isolated CI gate.

## Source recovery checks performed

- Exact missing migration checked on 10 reachable refs: `main`, source checkpoint, DB root-gate checkpoint, prior experiment, DB recovery, PostgreSQL integration, release-readiness, RC1, RC2, and APK build branch. The file was absent on all 10.
- Exact missing bootstrap checked on 5 reachable refs (main, source checkpoint, DB root-gate checkpoint, prior experiment, DB recovery); absent on all 5.
- GitHub commit path-history query for `supabase/migrations/20260924214051_001_core_tables.sql`: 0 commits.
- GitHub code search for the exact migration filename in this repository: 0 results.
- GitHub Releases API: 0 releases returned. The five existing pull requests were inventoried; none provides an identified source package.
- Current repository tree at checkpoint contains 106 entries, including schema catalogs and routine/policy snapshots, but no trusted source archive (.zip/.tar/.gz/.dump/.backup/.bundle) and no original migration/bootstrap. These current-state snapshots do not prove the historical SQL body or ordering.
- Prior isolated reconstruction run [38626886281](https://github.com/laminahmed12/school-mobile-app/actions/runs/38626886281) has one evidence artifact (785 bytes, digest `sha256:d55976feff2dc692578ec1b38974e99de6334b91c590ee0be5eae84d57b929b1`). It is gate evidence, not a source archive.

## Actual changes and CI

- Added `.github/workflows/lamin-db-reconstruction-continuation.yml` in commit `78713c1ae08511043292eb0530a7919eed457daf`.
- Workflow uses an ephemeral PostgreSQL 16 service, checks the database is empty, inventories migration files, and fails closed if the historical migration or test bootstrap is missing. It never connects to production.
- Actual run: [38631321208](https://github.com/laminahmed12/school-mobile-app/actions/runs/38631321208). Record final result after run completion; no success is assumed before the run finishes.
- Previous DB gate runs [38608150147](https://github.com/laminahmed12/school-mobile-app/actions/runs/38608150147) and [38608151296](https://github.com/laminahmed12/school-mobile-app/actions/runs/38608151296) failed at the absent approved-source manifest; migration execution was skipped.
- App CI success is separately evidenced by [38530600766](https://github.com/laminahmed12/school-mobile-app/actions/runs/38530600766) on main SHA `807da91475cc0f53827acb9940c62ca61c8f64d1`: format, Flutter analysis, automated tests, and candidate APK build succeeded in that run. This does not validate migration replay or make the DB repair release-ready.

## Reconstruction decision

Do not synthesize `20260924214051_001_core_tables.sql` from current schema metadata and do not invent `test/sql/supabase_test_bootstrap.sql`. The schema catalog cannot prove which objects existed at the original baseline, their original defaults/order, intermediate states, or the expected Supabase auth roles/helpers/grants. No historical replacement SQL was created.

## Remaining blocker and next safe action

A provenance-verifiable original source package is required: an author-controlled checkout/Git bundle/archive containing the migration chain and test bootstrap, or an explicitly reviewed non-historical baseline/reconciliation strategy. Until then, clean rebuild, trusted-baseline upgrade, RLS/tenant isolation, and backup/restore acceptance remain unverified. Do not merge to main or issue a final APK.
