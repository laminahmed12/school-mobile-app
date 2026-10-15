#!/usr/bin/env python3
"""Validate migration provenance bookkeeping; this does not execute migrations."""
import csv
from pathlib import Path

MAP = Path("supabase/migration_history_map.csv")
GAPS = Path("docs/MIGRATION_SOURCE_GAP_REGISTER_2026-10-15.csv")

def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    print(f"PASS: {message}")

rows = read_csv(MAP)
gaps = read_csv(GAPS)

require(len(rows) == 93, f"migration map has 93 rows (actual {len(rows)})")
require(sum(bool(r["production_version"]) for r in rows) == 74,
        "migration map accounts for 74 production-history rows")
require(sum(not r["production_version"] and bool(r["repository_version"]) for r in rows) == 19,
        "migration map accounts for 19 repository-only candidates")
require(all(r.get("status") and r["status"] != "unresolved" for r in rows),
        "every migration row has an explicit non-unresolved status")
require(all(r.get("evidence", "").strip() and r.get("evidence_url", "").strip() for r in rows),
        "every migration row has evidence text and an evidence URL")
require(sum(bool(r["repository_file"]) for r in rows) == 25,
        "25 candidate source files are recorded")
require(all(r["source_ref"].strip() and r["source_commit"].strip()
            for r in rows if r["repository_file"]),
        "every recorded candidate source identifies a containing ref and commit snapshot")
require({r["production_version"] for r in rows
         if r["status"] == "historical_source_missing"} == {"20260924214051", "20260924214123"},
        "the two missing historical SQL sources are explicitly identified")
require(sum(r["status"] == "effect_missing_reconciled_by_baseline" for r in rows) == 2,
        "the two missing catalog effects are marked as baseline-reconciled")
require(sum(r["status"] == "effect_incorrect_reconciled_by_baseline" for r in rows) == 1,
        "the incorrect rollover-close effect is marked as baseline-reconciled")
require(len(gaps) == 3, f"source-gap register has exactly 3 entries (actual {len(gaps)})")
require({r["artifact_path"] for r in gaps} == {
    "supabase/migrations/20260924214051_001_core_tables.sql",
    "supabase/migrations/20260924214123_002_rls_policies_rpcs.sql",
    "test/sql/supabase_test_bootstrap.sql",
}, "source-gap register names exactly the three missing artifacts")
require(all(r["status"] in {"historical_source_not_found", "test_fixture_source_not_found"} for r in gaps),
        "source-gap register does not falsely claim any original source was recovered")
require(all(not r["source_commit"] and not r["source_blob_sha"] for r in gaps),
        "missing originals have no fabricated source commit or blob SHA")
require(all(r["baseline_substitute"].strip() and r["baseline_substitute_blob_sha"].strip() for r in gaps),
        "each source gap documents a distinct baseline/test substitute and its blob SHA")
print("PASS: migration provenance bookkeeping is internally consistent")
