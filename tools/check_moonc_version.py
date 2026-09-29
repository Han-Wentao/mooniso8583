#!/usr/bin/env python3
"""Fail when the active MoonBit compiler is older than the project minimum."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys


def parse_version(text: str) -> tuple[int, int, int] | None:
    match = re.search(r"v?(\d+)\.(\d+)\.(\d+)", text)
    if match is None:
        return None
    return tuple(int(part) for part in match.groups())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minimum", default="0.10.14")
    args = parser.parse_args()

    minimum = parse_version(args.minimum)
    if minimum is None:
        print(f"invalid minimum version: {args.minimum}", file=sys.stderr)
        return 2

    try:
        result = subprocess.run(
            ["moonc", "-v"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        print(f"unable to execute moonc: {error}", file=sys.stderr)
        return 2

    output = (result.stdout + "\n" + result.stderr).strip()
    detected = parse_version(output)
    if result.returncode != 0 or detected is None:
        print(f"unable to parse moonc version from: {output!r}", file=sys.stderr)
        return 2

    print(f"moonc {detected[0]}.{detected[1]}.{detected[2]} (minimum {args.minimum})")
    if detected < minimum:
        print("the installed MoonBit compiler is too old", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
