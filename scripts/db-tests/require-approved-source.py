#!/usr/bin/env python3
"""Fail-closed provenance gate for isolated Lamin PostgreSQL tests.

No database commands are run by this program. It only validates an approved
source manifest and the exact file hashes before a test runner may proceed.
"""
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "test/sql/approved_migration_source_manifest.json"
MODE = os.environ.get("LAMIN_DB_TEST_MODE", "").strip()
if MODE not in {"clean", "upgrade"}:
    raise SystemExit("BLOCKED: set LAMIN_DB_TEST_MODE=clean or upgrade")

def fail(message):
    raise SystemExit("BLOCKED: " + message)

if not MANIFEST.is_file():
    fail(f"{MANIFEST.relative_to(ROOT)} is absent. Historical SQL provenance has not been approved; no migration test may execute.")

try:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
except Exception as exc:
    fail(f"manifest is not valid JSON: {exc}")

if data.get("schema_version") != 1:
    fail("manifest schema_version must be 1")
if data.get("approval", {}).get("status") != "approved":
    fail("manifest approval.status must be approved")
if not data.get("approval", {}).get("reviewed_by") or not data.get("approval", {}).get("evidence_url"):
    fail("manifest must identify reviewer and review evidence URL")
if not re.fullmatch(r"[0-9a-f]{40}", str(data.get("source_revision", ""))):
    fail("source_revision must be a full 40-character Git commit SHA")

def check_file(entry, label):
    if not isinstance(entry, dict):
        fail(f"{label} entry must be an object")
    path = entry.get("path", "")
    expected = entry.get("sha256", "")
    provenance = entry.get("provenance_url", "")
    if not path or Path(path).is_absolute() or ".." in Path(path).parts:
        fail(f"{label} has unsafe or missing relative path")
    target = ROOT / path
    if not target.is_file():
        fail(f"{label} file is absent: {path}")
    if not re.fullmatch(r"[0-9a-f]{64}", str(expected)):
        fail(f"{label} needs an approved SHA-256")
    actual = hashlib.sha256(target.read_bytes()).hexdigest()
    if actual != expected:
        fail(f"{label} hash mismatch: {path}")
    if not isinstance(provenance, str) or not provenance.startswith("https://"):
        fail(f"{label} needs an HTTPS provenance URL")
    return path

migrations = data.get("production_migrations")
if not isinstance(migrations, list) or len(migrations) != 74:
    fail("production_migrations must enumerate all 74 production history entries")
versions = [str(m.get("version", "")) for m in migrations if isinstance(m, dict)]
if len(versions) != 74 or len(set(versions)) != 74 or any(not re.fullmatch(r"\d{14}", v) for v in versions):
    fail("production migration versions must be unique 14-digit values")
for item in migrations:
    if not item.get("name"):
        fail("every production migration entry must include its recorded name")
    check_file(item, "migration " + str(item.get("version")))

check_file(data.get("bootstrap"), "test bootstrap")
if MODE == "upgrade":
    baseline = data.get("upgrade_baseline")
    if not isinstance(baseline, dict):
        fail("upgrade_baseline must identify a trusted schema dump and its provenance")
    check_file(baseline, "upgrade baseline")
    later = data.get("upgrade_migrations")
    if not isinstance(later, list) or not later:
        fail("upgrade_migrations must list explicitly approved post-baseline migrations")
    for item in later:
        check_file(item, "upgrade migration")
    if not data.get("baseline_schema_fingerprint"):
        fail("upgrade baseline needs an independently reviewed schema fingerprint")
print(f"APPROVED SOURCE GATE PASSED ({MODE}); manifest hashes and provenance references validated.")
print("This gate is not itself a migration test and does not establish schema correctness.")
