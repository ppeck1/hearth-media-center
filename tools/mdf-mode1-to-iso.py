#!/usr/bin/env python3
"""Convert 2448-byte Mode 1 MDF sectors to a standard 2048-byte ISO."""

from __future__ import annotations

import argparse
from pathlib import Path

SECTOR_SIZE = 2448
USER_DATA_OFFSET = 16
USER_DATA_SIZE = 2048


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    size = args.source.stat().st_size
    if size == 0 or size % SECTOR_SIZE:
        raise SystemExit("Input is not a whole number of 2448-byte sectors.")
    if args.destination.exists():
        raise SystemExit(f"Destination already exists: {args.destination}")

    with args.source.open("rb") as source, args.destination.open("xb") as destination:
        while sector := source.read(SECTOR_SIZE):
            if len(sector) != SECTOR_SIZE:
                raise SystemExit("Truncated final MDF sector.")
            destination.write(
                sector[USER_DATA_OFFSET : USER_DATA_OFFSET + USER_DATA_SIZE]
            )

    with args.destination.open("rb") as converted:
        converted.seek(0x8001)
        if converted.read(5) != b"CD001":
            args.destination.unlink(missing_ok=True)
            raise SystemExit("Converted image has no ISO9660 primary volume descriptor.")
    print(
        f"Converted {size // SECTOR_SIZE} sectors to "
        f"{args.destination.stat().st_size} bytes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
