#!/usr/bin/env python3
"""Privacy-bounded diagnostics for the Hearth Fedora appliance."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Iterable

STATUSES = ("PASS", "WARNING", "FAIL", "NOT CONFIGURED", "NOT APPLICABLE")
ROM_SUFFIXES = {
    ".7z", ".a26", ".a52", ".a78", ".bin", ".chd", ".cue", ".gb", ".gba", ".gbc",
    ".gcm", ".gcz", ".iso", ".lnx", ".m3u", ".md", ".n64", ".nds", ".nes", ".pbp",
    ".rvz", ".sfc", ".smc", ".sms", ".v64", ".wad", ".ws", ".wsc", ".z64", ".zip",
}


@dataclass(frozen=True)
class Check:
    id: str
    label: str
    status: str
    explanation: str
    remediation: str
    required: bool = False


class Report:
    def __init__(self) -> None:
        self.checks: list[Check] = []

    def add(
        self,
        check_id: str,
        label: str,
        status: str,
        explanation: str,
        remediation: str = "",
        *,
        required: bool = False,
    ) -> None:
        if status not in STATUSES:
            raise ValueError(f"invalid diagnostic status: {status}")
        self.checks.append(Check(check_id, label, status, explanation, remediation, required))

    @property
    def exit_code(self) -> int:
        return 1 if any(item.required and item.status == "FAIL" for item in self.checks) else 0

    def document(self) -> dict[str, object]:
        counts = {status: sum(item.status == status for item in self.checks) for status in STATUSES}
        return {
            "schema_version": 1,
            "generated_at": datetime.now(UTC).isoformat(timespec="seconds"),
            "summary": {"exit_code": self.exit_code, "counts": counts},
            "checks": [asdict(item) for item in self.checks],
        }


def command_path(*names: str) -> str | None:
    for name in names:
        value = shutil.which(name)
        if value:
            return value
    return None


def display_path(path: Path) -> str:
    home = Path.home()
    try:
        return "~/" + path.resolve().relative_to(home.resolve()).as_posix()
    except (OSError, ValueError):
        return path.as_posix()


def readable_version(command: Iterable[str]) -> str:
    try:
        result = subprocess.run(
            list(command), check=False, capture_output=True, text=True, timeout=3
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return (result.stdout or result.stderr).splitlines()[0][:160] if (result.stdout or result.stderr) else ""


def load_os_release(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" not in line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            values[key] = value.strip().strip('"')
    except OSError:
        pass
    return values


def count_games(root: Path) -> int:
    count = 0
    try:
        for directory, names, files in os.walk(root, followlinks=False):
            names[:] = [name for name in names if not name.startswith(".")]
            count += sum(Path(name).suffix.lower() in ROM_SUFFIXES for name in files)
    except OSError:
        return -1
    return count


def controller_names() -> list[str]:
    names: list[str] = []
    input_root = Path(os.environ.get("HEARTH_INPUT_CLASS_ROOT", "/sys/class/input"))
    try:
        for event in sorted(input_root.glob("event*")):
            name_path = event / "device/name"
            try:
                name = name_path.read_text(encoding="utf-8").strip()
                capabilities = (event / "device/capabilities/key").read_text(encoding="utf-8").strip()
            except OSError:
                continue
            lowered = name.casefold()
            if any(token in lowered for token in ("controller", "gamepad", "dualsense", "xbox", "joystick")):
                if capabilities and name not in names and not name.startswith("Hearth Virtual"):
                    names.append(name[:80])
    except OSError:
        pass
    return names


def flatpak_installed(app_id: str) -> bool:
    flatpak = command_path("flatpak")
    if not flatpak:
        return False
    try:
        result = subprocess.run(
            [flatpak, "info", app_id], check=False, capture_output=True, timeout=3
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def build_report(args: argparse.Namespace) -> Report:
    report = Report()
    install_root = Path(args.install_root)
    library_root = Path(args.library_root)
    config_root = Path(args.config_root).expanduser()
    os_release = load_os_release(Path(args.os_release))

    if os_release.get("ID") == "fedora":
        report.add("fedora", "Fedora", "PASS", os_release.get("PRETTY_NAME", "Fedora detected"))
    else:
        report.add(
            "fedora", "Fedora", "FAIL", os_release.get("PRETTY_NAME", "Fedora not detected"),
            "Install Hearth on a supported Fedora Workstation system.", required=True,
        )

    session = os.environ.get("XDG_SESSION_TYPE", "unknown").lower()
    if session == "wayland":
        report.add("session", "Display session", "PASS", "Wayland session detected")
    elif session == "x11":
        report.add("session", "Display session", "WARNING", "X11 session detected", "Use the Fedora Wayland session for appliance validation.")
    else:
        report.add("session", "Display session", "WARNING", "No graphical session detected", "Run diagnostics from the logged-in media account.")

    resolution = os.environ.get("HEARTH_DISPLAY_RESOLUTION", "")
    if not resolution and command_path("gnome-randr"):
        resolution = readable_version(["gnome-randr", "query"])
    report.add(
        "display", "Display", "PASS" if resolution else "WARNING",
        resolution[:80] if resolution else "Resolution unavailable in this process",
        "Confirm 1920×1080 and TV scaling manually.",
    )

    godot = Path(args.godot) if args.godot else None
    if not godot or not godot.is_file():
        candidate = command_path("godot", "godot4")
        godot = Path(candidate) if candidate else install_root / "runtime/godot"
    if godot.is_file() and os.access(godot, os.X_OK):
        report.add("godot", "Godot runtime", "PASS", readable_version([str(godot), "--version"]) or "Godot executable is available")
    else:
        report.add("godot", "Godot runtime", "FAIL", "Godot runtime is missing", "Run install.sh with --godot PATH.", required=True)

    project = install_root / "launcher/project.godot"
    report.add(
        "installation", "Hearth installation", "PASS" if project.is_file() else "FAIL",
        f"Project {'found' if project.is_file() else 'missing'} at {display_path(install_root)}",
        "Run deploy/fedora/install.sh from a trusted checkout.", required=True,
    )

    retroarch = command_path("retroarch")
    report.add(
        "retroarch", "RetroArch", "PASS" if retroarch else "WARNING",
        readable_version([retroarch, "--version"]) if retroarch else "RetroArch is not installed",
        "Install RetroArch before launching personal ROMs.",
    )
    core_roots = [config_root.parent / "retroarch/cores", Path("/usr/lib64/libretro")]
    cores = sorted({path.name for root in core_roots if root.is_dir() for path in root.glob("*_libretro.so")})
    report.add(
        "libretro_cores", "Libretro cores", "PASS" if cores else "NOT CONFIGURED",
        f"{len(cores)} compatible core files detected",
        "Install only required cores and keep system-registry.json allowlisted.",
    )

    for check_id, label, command_name, remediation in (
        ("steam", "Steam", "steam", "Install Steam if this destination is required."),
        ("browser", "Supported browser", "google-chrome-stable", "Install Google Chrome Stable or configure a supported bounded launcher."),
        ("zenity", "Zenity", "zenity", "Install Zenity for power confirmations."),
    ):
        available = command_path(command_name)
        if check_id == "browser" and not available:
            available = command_path("chromium", "chromium-browser")
        report.add(
            check_id, label, "PASS" if available else "WARNING",
            f"{label} {'is available' if available else 'is not installed'}", remediation,
        )
    report.add(
        "plex", "Plex HTPC", "PASS" if flatpak_installed("tv.plex.PlexHTPC") else "WARNING",
        "Plex HTPC Flatpak is installed" if flatpak_installed("tv.plex.PlexHTPC") else "Plex HTPC Flatpak is not installed",
        "Install tv.plex.PlexHTPC with Flatpak if Plex is required.",
    )

    rom_root = library_root / "games/roms"
    if not rom_root.exists():
        report.add("rom_library", "ROM library", "FAIL", f"Library root is missing: {display_path(rom_root)}", "Create it with install.sh.", required=True)
        game_count = 0
    elif not os.access(rom_root, os.R_OK | os.X_OK):
        report.add("rom_library", "ROM library", "FAIL", "Library root is not readable by the active user", "Correct ownership without making personal content world-readable.", required=True)
        game_count = 0
    else:
        game_count = count_games(rom_root)
        report.add(
            "rom_library", "ROM library", "PASS" if game_count > 0 else "WARNING",
            f"Readable; {max(game_count, 0)} game files detected",
            "Add personal files under the configured library root." if game_count == 0 else "",
        )
    report.add("game_count", "Detected games", "PASS" if game_count > 0 else "NOT CONFIGURED", f"{max(game_count, 0)} games detected")

    manifest = library_root / "games/pc/hearth-manifest.json"
    if not manifest.exists():
        report.add("native_manifest", "Native PC manifest", "NOT CONFIGURED", "No native PC manifest is present", "Create a local manifest only when native games are configured.")
    else:
        try:
            document = json.loads(manifest.read_text(encoding="utf-8"))
            entries = document.get("entries", [])
            valid = document.get("schema_version") == 1 and isinstance(entries, list)
        except (OSError, json.JSONDecodeError):
            valid, entries = False, []
        report.add(
            "native_manifest", "Native PC manifest", "PASS" if valid else "FAIL",
            f"Valid manifest with {len(entries)} entries" if valid else "Manifest is invalid",
            "Validate schema and approved helper IDs; do not place commands in JSON.",
            required=manifest.exists(),
        )

    controllers = controller_names()
    report.add(
        "controller", "Controller", "PASS" if controllers else "WARNING",
        ", ".join(controllers[:3]) if controllers else "No controller detected",
        "Pair or reconnect a controller; keyboard arrows, Enter, Escape, and Home remain available.",
    )
    uinput = Path(args.uinput)
    uinput_ready = uinput.exists() and os.access(uinput, os.R_OK | os.W_OK)
    report.add(
        "uinput", "/dev/uinput", "PASS" if uinput_ready else "FAIL",
        "Active user can create the bounded virtual keyboard" if uinput_ready else "Active user cannot access uinput",
        "Run install-input-access.sh, then log out and back in.", required=True,
    )
    evdev_ready = importlib.util.find_spec("evdev") is not None
    report.add(
        "bridge_dependencies", "Input bridge dependencies", "PASS" if evdev_ready else "FAIL",
        "Python evdev module is available" if evdev_ready else "Python evdev module is missing",
        "Install the Fedora python3-evdev package.", required=True,
    )
    bridge_process = False
    try:
        processes = subprocess.run(["pgrep", "-f", "hearth_input_bridge"], check=False, capture_output=True, timeout=2)
        bridge_process = processes.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        pass
    report.add(
        "input_bridge", "Input bridge", "PASS" if bridge_process else "NOT APPLICABLE",
        "Bridge process is active" if bridge_process else "Bridge is idle; it runs only for translated destinations",
    )

    report.add(
        "configuration", "Configuration directory",
        "PASS" if config_root.is_dir() else "NOT CONFIGURED",
        display_path(config_root),
        "Hearth creates local settings here after the first saved change.",
    )
    launchers = install_root / "launchers"
    bad_launchers = [
        path.name for path in launchers.glob("*.sh")
        if not (path.stat().st_mode & stat.S_IXUSR)
    ] if launchers.is_dir() else ["launchers directory missing"]
    report.add(
        "launchers", "Launcher permissions", "PASS" if not bad_launchers else "FAIL",
        "All bounded helpers are executable" if not bad_launchers else f"{len(bad_launchers)} launcher permission failures",
        "Rerun update.sh to restore source-controlled modes.", required=True,
    )

    service_path = Path.home() / ".config/systemd/user/hearth.service"
    service_state = readable_version(["systemctl", "--user", "is-enabled", "hearth.service"]) if command_path("systemctl") else ""
    report.add(
        "autostart", "Launch at login",
        "PASS" if service_state == "enabled" else ("NOT CONFIGURED" if not service_path.exists() else "WARNING"),
        "systemd user service enabled" if service_state == "enabled" else "systemd user service is not enabled",
        "Run systemctl --user enable hearth.service after installation.",
    )
    hearth_running = False
    try:
        hearth_running = subprocess.run(
            ["pgrep", "-f", f"{install_root}/.*godot"], check=False, capture_output=True, timeout=2
        ).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        pass
    report.add(
        "process", "Hearth process", "PASS" if hearth_running else "WARNING",
        "Hearth is running" if hearth_running else "Hearth is not currently running",
        "Start hearth.service or launch Hearth from the graphical session.",
    )
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit one JSON document")
    parser.add_argument("--output", type=Path, help="atomically write JSON to this file")
    parser.add_argument("--install-root", default=os.environ.get("HEARTH_INSTALL_ROOT", "/opt/hearth"))
    parser.add_argument("--library-root", default=os.environ.get("HEARTH_LIBRARY_ROOT", "/srv/library"))
    parser.add_argument("--config-root", default=os.environ.get("HEARTH_CONFIG_ROOT", "~/.config/hearth"))
    parser.add_argument("--os-release", default=os.environ.get("HEARTH_OS_RELEASE", "/etc/os-release"))
    parser.add_argument("--uinput", default=os.environ.get("HEARTH_UINPUT_PATH", "/dev/uinput"))
    parser.add_argument("--godot", default=os.environ.get("HEARTH_GODOT", ""))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = build_report(args)
    document = report.document()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name + ".tmp")
        temporary.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        os.replace(temporary, args.output)
    if args.json:
        print(json.dumps(document, indent=2))
    else:
        for item in report.checks:
            print(f"{item.status:<16} {item.label:<28} {item.explanation}")
            if item.remediation and item.status != "PASS":
                print(f"{'':17}Fix: {item.remediation}")
        print(f"\nRequired diagnostic result: {'PASS' if report.exit_code == 0 else 'FAIL'}")
    return report.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
