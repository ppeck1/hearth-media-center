#!/usr/bin/env python3
"""Portable repository checks that do not require Fedora or physical hardware."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*]\(([^)]+)\)")
PRIVATE_PATTERNS = (
    re.compile("/" + "home" + r"/[A-Za-z0-9._-]+"),
    re.compile(r"C:\\Users\\", re.IGNORECASE),
    re.compile(r"BEGIN [A-Z ]*PRIVATE KEY"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
)
TEXT_SUFFIXES = {
    ".css", ".gd", ".godot", ".html", ".js", ".json", ".md", ".ps1", ".py",
    ".rules", ".service", ".sh", ".svg", ".toml", ".txt", ".yml", ".yaml",
}


class CheckFailure(RuntimeError):
    pass


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [ROOT / Path(value.decode()) for value in result.stdout.split(b"\0") if value]


def check_json(files: list[Path]) -> int:
    count = 0
    for path in files:
        if path.suffix != ".json":
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise CheckFailure(f"invalid JSON in {path.relative_to(ROOT)}: {error}") from error
        count += 1
    return count


def check_markdown_links(files: list[Path]) -> int:
    checked = 0
    for path in files:
        if path.suffix.lower() != ".md":
            continue
        for match in MARKDOWN_LINK.finditer(path.read_text(encoding="utf-8")):
            raw_target = match.group(1).strip()
            if raw_target.startswith("<") and raw_target.endswith(">"):
                raw_target = raw_target[1:-1]
            target = raw_target.split(maxsplit=1)[0]
            parsed = urlsplit(target)
            if parsed.scheme or target.startswith("#"):
                continue
            relative = unquote(parsed.path)
            if not relative:
                continue
            destination = (path.parent / relative).resolve()
            try:
                destination.relative_to(ROOT)
            except ValueError as error:
                raise CheckFailure(
                    f"documentation link escapes the repository: {path.relative_to(ROOT)} -> {target}"
                ) from error
            if not destination.exists():
                raise CheckFailure(
                    f"broken documentation link: {path.relative_to(ROOT)} -> {target}"
                )
            checked += 1
    return checked


def check_privacy(files: list[Path]) -> int:
    checked = 0
    for path in files:
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for pattern in PRIVATE_PATTERNS:
            match = pattern.search(text)
            if match:
                raise CheckFailure(
                    f"privacy marker in {path.relative_to(ROOT)}: {match.group(0)!r}"
                )
        checked += 1
    return checked


def check_executable_modes() -> int:
    expected = [
        path
        for folder in ("deploy/fedora", "launchers", "tools", "verify")
        for path in (ROOT / folder).glob("*.sh")
    ]
    modes = subprocess.run(
        ["git", "ls-files", "--stage", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=False,
    ).stdout.split(b"\0")
    executable_paths = {
        entry.decode().split(maxsplit=3)[3]
        for entry in modes
        if entry and entry.decode().startswith("100755 ")
    }
    for path in expected:
        relative = path.relative_to(ROOT).as_posix()
        if relative not in executable_paths:
            raise CheckFailure(f"Git executable mode is missing: {relative}")
    return len(expected)


def check_clean_tree() -> None:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    if result.stdout:
        raise CheckFailure("verification changed the repository:\n" + result.stdout.rstrip())


def main() -> int:
    try:
        files = tracked_files()
        json_count = check_json(files)
        link_count = check_markdown_links(files)
        privacy_count = check_privacy(files)
        executable_count = check_executable_modes()
        if os.environ.get("HEARTH_VERIFY_ALLOW_DIRTY") != "1":
            check_clean_tree()
    except (CheckFailure, subprocess.CalledProcessError) as error:
        print(f"repository check: FAIL: {error}", file=sys.stderr)
        return 1
    print(
        "repository check: PASS "
        f"({json_count} JSON files, {link_count} local documentation links, "
        f"{privacy_count} privacy-scanned text files, {executable_count} executable scripts)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
