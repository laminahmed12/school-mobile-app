#!/usr/bin/env python3
"""Apply only manifest-approved source to a disposable, empty PostgreSQL database."""
import json, os, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
db=os.environ.get("PGDATABASE","")
if db != "lamin_clean_test":
    raise SystemExit("Refusing to run: PGDATABASE must be lamin_clean_test")
manifest=json.loads((ROOT/"test/sql/approved_migration_source_manifest.json").read_text())
def psql_file(path):
    subprocess.run(["psql","-X","-v","ON_ERROR_STOP=1","-f",str(ROOT/path)],cwd=ROOT,check=True)
def query(sql):
    return subprocess.run(["psql","-X","-A","-t","-v","ON_ERROR_STOP=1","-c",sql],cwd=ROOT,check=True,text=True,capture_output=True).stdout.strip()
if query("select count(*) from pg_catalog.pg_tables where schemaname not in ('pg_catalog','information_schema')") != "0":
    raise SystemExit("Refusing to apply chain: target database is not empty")
psql_file(manifest["bootstrap"]["path"])
for item in sorted(manifest["production_migrations"],key=lambda x:x["version"]):
    print("APPLY",item["version"],item["name"],flush=True)
    psql_file(item["path"])
for name in ("schema_invariants","rls_authorization","tenant_isolation","backup_restore"):
    print("VERIFY",name,flush=True)
    psql_file(manifest["verification_suites"][name]["path"])
print("CLEAN REBUILD AND DECLARED VERIFICATION SUITES COMPLETED")
