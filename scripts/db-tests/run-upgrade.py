#!/usr/bin/env python3
"""Restore an approved schema baseline and test only manifest-approved later migrations."""
import json, os, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
if os.environ.get("PGDATABASE") != "lamin_upgrade_test":
    raise SystemExit("Refusing to run: PGDATABASE must be lamin_upgrade_test")
manifest=json.loads((ROOT/"test/sql/approved_migration_source_manifest.json").read_text())
def psql_file(path):
    subprocess.run(["psql","-X","-v","ON_ERROR_STOP=1","-f",str(ROOT/path)],cwd=ROOT,check=True)
def query(sql):
    return subprocess.run(["psql","-X","-A","-t","-v","ON_ERROR_STOP=1","-c",sql],cwd=ROOT,check=True,text=True,capture_output=True).stdout.strip()
if query("select count(*) from pg_catalog.pg_tables where schemaname not in ('pg_catalog','information_schema')") != "0":
    raise SystemExit("Refusing to restore baseline: target database is not empty")
baseline=manifest["upgrade_baseline"]
print("RESTORE BASELINE",baseline["path"],flush=True)
psql_file(baseline["path"])
for item in sorted(manifest["upgrade_migrations"],key=lambda x:x["version"]):
    print("APPLY POST-BASELINE",item["version"],item.get("name",""),flush=True)
    psql_file(item["path"])
for name in ("schema_invariants","rls_authorization","tenant_isolation","backup_restore"):
    print("VERIFY",name,flush=True)
    psql_file(manifest["verification_suites"][name]["path"])
print("UPGRADE AND DECLARED VERIFICATION SUITES COMPLETED")
