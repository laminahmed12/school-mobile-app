#!/usr/bin/env python3
"""Normalize concatenated PostgreSQL pg_get_functiondef() exports.

pg_get_functiondef() returns a CREATE FUNCTION definition whose outer
 dollar-quoted body does not necessarily include the terminating SQL
 semicolon. When several definitions are concatenated, the next CREATE can
 therefore be parsed as part of the previous statement.

This script adds only a missing statement terminator immediately after the
 outer dollar-quote delimiter. It never edits function bodies or attributes.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FUNCTION_START = re.compile(r"(?im)^\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\b")
OUTER_BODY = re.compile(r"\bAS\s+(\$[A-Za-z_][A-Za-z0-9_]*\$)", re.IGNORECASE)


def missing_terminators(source: str) -> list[int]:
    starts = [m.start() for m in FUNCTION_START.finditer(source)]
    missing: list[int] = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(source)
        statement = source[start:end]
        opening = OUTER_BODY.search(statement)
        if not opening:
            raise ValueError(f"Cannot identify dollar-quoted function body near byte {start}")
        tag = opening.group(1)
        opening_end = opening.end()
        close = statement.rfind(tag)
        if close < opening_end:
            raise ValueError(f"Unbalanced outer dollar quote for function near byte {start}")
        after = close + len(tag)
        if after >= len(statement) or statement[after] != ";":
            missing.append(start + after)
    return missing


def normalize(source: str) -> str:
    positions = missing_terminators(source)
    for position in reversed(positions):
        source = source[:position] + ";" + source[position:]
    return source


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="write normalized SQL in place")
    mode.add_argument("--check", action="store_true", help="check-only mode (the default)")
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()
    failed = False
    for path in args.files:
        original = path.read_text(encoding="utf-8")
        try:
            positions = missing_terminators(original)
        except ValueError as exc:
            print(f"ERROR {path}: {exc}", file=sys.stderr)
            failed = True
            continue
        if not positions:
            print(f"OK {path}: every function statement has a terminator")
            continue
        if args.write:
            path.write_text(normalize(original), encoding="utf-8")
            print(f"FIXED {path}: added {len(positions)} missing statement terminator(s)")
        else:
            print(f"FAIL {path}: {len(positions)} missing function statement terminator(s)")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
