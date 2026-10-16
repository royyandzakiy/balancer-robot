#!/usr/bin/env python3
"""Convert an lcov tracefile to a GitHub-flavoured Markdown table or a shields.io badge.

Usage:
    python3 scripts/cov-to-md.py coverage.lcov            # Markdown table (default)
    llvm-cov export -format=lcov ... | python3 scripts/cov-to-md.py   # table from stdin
    python3 scripts/cov-to-md.py --shields coverage.lcov  # shields.io endpoint JSON

Reads the per-file LF/LH (lines), FNF/FNH (functions), BRF/BRH (branches) records that
llvm-cov (or gcov/lcov) emit. The default mode prints one row per file plus a TOTAL row;
--shields prints a shields.io endpoint object built from total LINE coverage.
"""
import json
import os
import sys


def read_text(path: str | None) -> str:
    if path:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    return sys.stdin.read()


def pct(hit: int, found: int) -> str:
    return f"{100.0 * hit / found:.1f}%" if found else "—"


KEYS = ("LF", "LH", "FNF", "FNH", "BRF", "BRH")


def parse(text: str):
    files, totals, current = [], dict.fromkeys(KEYS, 0), None
    for line in text.splitlines():
        if line.startswith("SF:"):
            current = {"file": os.path.basename(line[3:]), **dict.fromkeys(KEYS, 0)}
        elif line == "end_of_record" and current:
            files.append(current)
            current = None
        elif current:
            for key in KEYS:
                if line.startswith(key + ":"):
                    value = int(line[len(key) + 1:])
                    current[key] = value
                    totals[key] += value
                    break
    return files, totals


def badge_color(percent: float) -> str:
    for threshold, color in (
        (90, "brightgreen"),
        (80, "green"),
        (70, "yellowgreen"),
        (60, "yellow"),
        (50, "orange"),
    ):
        if percent >= threshold:
            return color
    return "red"


def shields_json(totals: dict) -> str:
    found, hit = totals["LF"], totals["LH"]
    percent = 100.0 * hit / found if found else 0.0
    return json.dumps(
        {
            "schemaVersion": 1,
            "label": "coverage",
            "message": f"{percent:.1f}%",
            "color": badge_color(percent),
        }
    )


def main() -> None:
    args = sys.argv[1:]
    shields = "--shields" in args
    args = [a for a in args if a != "--shields"]
    path = args[0] if args else None

    files, totals = parse(read_text(path))

    if shields:
        print(shields_json(totals))
        return

    rows = ["| File | Lines | Functions | Branches |", "|---|---|---|---|"]
    for f in sorted(files, key=lambda x: x["file"]):
        rows.append(
            f"| `{f['file']}` | {pct(f['LH'], f['LF'])} "
            f"| {pct(f['FNH'], f['FNF'])} | {pct(f['BRH'], f['BRF'])} |"
        )
    rows.append(
        f"| **TOTAL** | **{pct(totals['LH'], totals['LF'])}** "
        f"| **{pct(totals['FNH'], totals['FNF'])}** | **{pct(totals['BRH'], totals['BRF'])}** |"
    )
    print("\n".join(rows))


if __name__ == "__main__":
    main()
