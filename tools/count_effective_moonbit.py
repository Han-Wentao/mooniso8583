#!/usr/bin/env python3
"""Report conservative MoonBit source-line categories for this repository."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class LineCount:
    files: int = 0
    physical: int = 0
    effective: int = 0

    def add(self, physical: int, effective: int) -> "LineCount":
        return LineCount(self.files + 1, self.physical + physical, self.effective + effective)


def is_effective(line: str, in_block_comment: bool) -> tuple[bool, bool]:
    text = line.strip()
    if in_block_comment:
        end = text.find("*/")
        if end < 0:
            return False, True
        text = text[end + 2 :].strip()
        in_block_comment = False
    if not text or text.startswith("//"):
        return False, in_block_comment
    while text.startswith("/*"):
        end = text.find("*/", 2)
        if end < 0:
            return False, True
        text = text[end + 2 :].strip()
        if not text:
            return False, False
    return True, in_block_comment


def count_file(path: Path) -> tuple[int, int]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    effective = 0
    in_block_comment = False
    for line in lines:
        counted, in_block_comment = is_effective(line, in_block_comment)
        if counted:
            effective += 1
    return len(lines), effective


def category(root: Path, path: Path) -> str:
    relative = path.relative_to(root)
    name = path.name
    if relative.parts and relative.parts[0] == "examples":
        return "examples"
    if name.endswith("_test.mbt") or name.endswith("_wbtest.mbt"):
        return "tests"
    if name == "profile_1987.mbt":
        return "specification"
    if len(relative.parts) == 1:
        return "core"
    return "other"


def collect(root: Path) -> dict[str, LineCount]:
    totals = {name: LineCount() for name in ("core", "specification", "tests", "examples", "other")}
    for path in sorted(root.rglob("*.mbt")):
        if any(part in {"_build", ".mooncakes", "target"} for part in path.parts):
            continue
        physical, effective = count_file(path)
        key = category(root, path)
        totals[key] = totals[key].add(physical, effective)
    return totals


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check-core", type=int, default=0, metavar="LINES")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    totals = collect(root)
    if args.json:
        print(json.dumps({key: asdict(value) for key, value in totals.items()}, ensure_ascii=False, indent=2))
    else:
        print("category       files  physical  effective")
        print("-------------  -----  --------  ---------")
        for key, value in totals.items():
            print(f"{key:13}  {value.files:5d}  {value.physical:8d}  {value.effective:9d}")
        implementation = totals["core"].effective + totals["specification"].effective
        print(f"implementation effective (core + specification): {implementation}")
        print("core excludes tests, examples, generated output, and profile_1987.mbt")
    if args.check_core and totals["core"].effective < args.check_core:
        print(
            f"core effective lines {totals['core'].effective} are below required {args.check_core}",
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
