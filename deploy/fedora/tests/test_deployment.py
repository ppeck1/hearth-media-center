from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
FEDORA_ROOT = REPO_ROOT / "deploy/fedora"
GODOT = Path("/opt/hearth/runtime/godot")


class DeploymentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="hearth-appliance-tests-")
        root = Path(self.temp.name)
        self.install_root = root / "hearth-test-install"
        self.library_root = root / "hearth-library-test-install"
        self.etc_root = root / "etc"
        self.target_home = root / "media-home"
        self.os_release = root / "os-release"
        self.uinput = root / "uinput"
        self.config_root = self.target_home / ".config/hearth"
        self.os_release.write_text(
            'ID=fedora\nVERSION_ID=44\nPRETTY_NAME="Fedora Test Fixture"\n',
            encoding="utf-8",
        )
        self.target_home.mkdir()
        self.env = os.environ.copy()
        self.env.update(
            {
                "HEARTH_TEST_MODE": "1",
                "HEARTH_TARGET_USER": os.environ.get("USER", "nobody"),
                "HEARTH_TARGET_HOME": str(self.target_home),
                "HEARTH_INSTALL_ROOT": str(self.install_root),
                "HEARTH_LIBRARY_ROOT": str(self.library_root),
                "HEARTH_ETC_ROOT": str(self.etc_root),
                "HEARTH_OS_RELEASE": str(self.os_release),
                "HEARTH_UINPUT_PATH": str(self.uinput),
                "HEARTH_CONFIG_ROOT": str(self.config_root),
                "HEARTH_GODOT": str(GODOT),
                "HEARTH_SKIP_DOCTOR": "1",
                "HOME": str(self.target_home),
                "XDG_SESSION_TYPE": "wayland",
            }
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_script(self, name: str, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(FEDORA_ROOT / name), *arguments],
            cwd=REPO_ROOT,
            env=self.env,
            text=True,
            capture_output=True,
            check=check,
        )

    @unittest.skipUnless(GODOT.is_file(), "installed Godot fixture is unavailable")
    def test_install_update_uninstall_preserve_personal_state(self) -> None:
        self.run_script("install.sh", "--source", str(REPO_ROOT), "--godot", str(GODOT))
        self.assertTrue((self.install_root / "launcher/project.godot").is_file())
        self.assertTrue((self.install_root / "runtime/godot").stat().st_mode & 0o100)
        self.assertTrue((self.target_home / ".config/systemd/user/hearth.service").is_file())

        personal_rom = self.library_root / "games/roms/Fixture Console/Private Fixture.rom"
        personal_rom.parent.mkdir(parents=True)
        personal_rom.write_bytes(b"fixture")
        local_setting = self.config_root / "local-setting.json"
        local_setting.parent.mkdir(parents=True)
        local_setting.write_text('{"local": true}\n', encoding="utf-8")
        browser_cookie = self.target_home / ".config/media-kiosk/netflix/fixture-cookie"
        browser_cookie.parent.mkdir(parents=True)
        browser_cookie.write_text("fixture", encoding="utf-8")

        self.run_script("update.sh", "--source", str(REPO_ROOT), "--godot", str(GODOT))
        self.assertEqual(personal_rom.read_bytes(), b"fixture")
        self.assertTrue(local_setting.is_file())
        self.assertTrue(browser_cookie.is_file())
        backups = list(self.install_root.parent.glob(self.install_root.name + "-backups/*"))
        self.assertEqual(len(backups), 1)

        self.run_script("uninstall.sh")
        self.assertFalse(self.install_root.exists())
        self.assertEqual(personal_rom.read_bytes(), b"fixture")
        self.assertTrue(local_setting.is_file())
        self.assertTrue(browser_cookie.is_file())

    @unittest.skipUnless(GODOT.is_file(), "installed Godot fixture is unavailable")
    def test_settings_removal_requires_explicit_flag(self) -> None:
        self.run_script("install.sh", "--source", str(REPO_ROOT), "--godot", str(GODOT))
        setting = self.config_root / "settings.json"
        setting.parent.mkdir(parents=True)
        setting.write_text("{}\n", encoding="utf-8")
        self.run_script("uninstall.sh", "--remove-settings")
        self.assertFalse(self.config_root.exists())
        self.assertTrue(self.library_root.exists())

    def test_doctor_json_is_bounded_and_machine_readable(self) -> None:
        (self.install_root / "launcher").mkdir(parents=True)
        (self.install_root / "launcher/project.godot").write_text("[application]\n", encoding="utf-8")
        launcher_root = self.install_root / "launchers"
        launcher_root.mkdir()
        helper = launcher_root / "fixture.sh"
        helper.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
        helper.chmod(0o755)
        rom_root = self.library_root / "games/roms/Fixture Console"
        rom_root.mkdir(parents=True)
        (rom_root / "Private Fixture Name.z64").write_bytes(b"fixture")
        manifest = self.library_root / "games/pc/hearth-manifest.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('{"schema_version":1,"entries":[]}\n', encoding="utf-8")
        self.uinput.write_bytes(b"")
        self.uinput.chmod(0o666)

        result = self.run_script("doctor.sh", "--json", check=False)
        document = json.loads(result.stdout)
        self.assertEqual(document["schema_version"], 1)
        self.assertGreaterEqual(len(document["checks"]), 20)
        encoded = json.dumps(document)
        self.assertNotIn("Private Fixture Name", encoded)
        self.assertNotIn(str(self.target_home), encoded)
        self.assertIn("1 game files detected", encoded)
        self.assertTrue(all("status" in item and "remediation" in item for item in document["checks"]))

    def test_non_fedora_install_fails_before_writes(self) -> None:
        self.os_release.write_text('ID=ubuntu\nPRETTY_NAME="Ubuntu Fixture"\n', encoding="utf-8")
        result = self.run_script(
            "install.sh", "--source", str(REPO_ROOT), "--godot", str(GODOT), check=False
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.install_root.exists())


if __name__ == "__main__":
    unittest.main()
