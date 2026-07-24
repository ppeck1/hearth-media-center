#!/usr/bin/env python3
"""Link Genesis ROMs to a complete local artwork pack without network lookups."""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
ROM_EXTENSIONS = {".bin", ".gen", ".md", ".smd"}


def normalized_title(value: str) -> str:
    value = re.split(r" [([]", value, maxsplit=1)[0]
    return "".join(character for character in value.casefold() if character.isascii() and character.isalnum())


def candidate_score(path: Path) -> tuple[int, str]:
    name = path.name.casefold()
    if "(usa)" in name:
        score = 0
    elif "(world)" in name:
        score = 10
    elif "(usa," in name or ", usa)" in name:
        score = 20
    elif "(europe)" in name:
        score = 30
    elif "(japan)" in name:
        score = 40
    else:
        score = 50
    if "rev " in name or "(rev" in name:
        score += 2
    for less_preferred in (
        "virtual console",
        "gamecube edition",
        "e-reader edition",
        "prototype",
        "demo",
        "[p]",
        "[h",
        "[b",
        "[tr ",
    ):
        if less_preferred in name:
            score += 100
    return score, name


def artwork_index(pack: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for path in pack.iterdir():
        if not path.is_file() or path.suffix.casefold() not in IMAGE_EXTENSIONS:
            continue
        key = normalized_title(path.stem)
        if key and (key not in result or candidate_score(path) < candidate_score(result[key])):
            result[key] = path
    return result


def decode_smd(raw: bytes) -> bytes:
    if raw[0x100:0x104] == b"SEGA":
        return raw
    if len(raw) % 16384 != 512:
        return raw
    source = raw[512:]
    decoded = bytearray(len(source))
    for offset in range(0, len(source), 16384):
        block = source[offset : offset + 16384]
        if len(block) != 16384:
            break
        decoded[offset : offset + 16384 : 2] = block[8192:]
        decoded[offset + 1 : offset + 16384 : 2] = block[:8192]
    return bytes(decoded)


def embedded_titles(path: Path) -> list[str]:
    raw = decode_smd(path.read_bytes())
    if len(raw) < 0x180:
        return []
    values = []
    for start, end in ((0x150, 0x180), (0x120, 0x150)):
        title = raw[start:end].decode("ascii", "ignore")
        title = " ".join(title.replace("\x00", " ").split()).strip(" -")
        if title and title not in values:
            values.append(title)
    return values


def title_keys(title: str) -> list[str]:
    keys = [normalized_title(title)]
    replacements = (
        (r"\b2\b", "II"),
        (r"\b3\b", "III"),
        (r"\b4\b", "IV"),
        (r"\bII\b", "2"),
        (r"\bIII\b", "3"),
        (r"\bIV\b", "4"),
    )
    for pattern, replacement in replacements:
        alternate = normalized_title(re.sub(pattern, replacement, title, flags=re.IGNORECASE))
        if alternate and alternate not in keys:
            keys.append(alternate)
    return keys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom-dir", type=Path, required=True)
    parser.add_argument("--pack-dir", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    index = artwork_index(args.pack_dir)
    covers = args.rom_dir / "covers"
    roms = sorted(
        path
        for path in args.rom_dir.iterdir()
        if path.is_file() and path.suffix.casefold() in ROM_EXTENSIONS
    )
    matched = 0
    existing = 0
    for rom in roms:
        destination_candidates = [covers / f"{rom.stem}{extension}" for extension in IMAGE_EXTENSIONS]
        if any(path.exists() for path in destination_candidates):
            existing += 1
            continue
        match = None
        for title in embedded_titles(rom):
            for key in title_keys(title):
                if key in index:
                    match = index[key]
                    break
            if match is not None:
                break
        if match is None:
            continue
        matched += 1
        if args.apply:
            covers.mkdir(parents=True, exist_ok=True)
            destination = covers / f"{rom.stem}{match.suffix.casefold()}"
            if not destination.exists():
                os.symlink(match, destination)

    print(
        f"Genesis artwork: {matched} newly matched, {existing} already linked, "
        f"{len(roms) - matched - existing} unmatched, {len(roms)} ROMs total."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
