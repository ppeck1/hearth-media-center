from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from input_bridge.hearth_input_bridge import AdapterMapper, BridgeConfig, ConfigError, SemanticMapper


REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = REPO_ROOT / "launcher" / "config"


class BridgeConfigTests(unittest.TestCase):
    def test_loads_shared_configs_and_destination_policy(self) -> None:
        config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")
        self.assertEqual(config.adapter_for_destination("netflix"), "keyboard_navigation")
        self.assertEqual(config.adapter_for_destination("steam"), "native")

    def test_rejects_invalid_axis_threshold(self) -> None:
        config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")
        broken = json.loads(json.dumps(config.profiles))
        broken["profiles"][0]["bindings"]["navigate_left"][1]["threshold"] = 2
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory) / "invalid-profile.json"
            temporary.write_text(json.dumps(broken), encoding="utf-8")
            with self.assertRaises(ConfigError):
                BridgeConfig.load(CONFIG_DIR, user_config=temporary)

    def test_restores_missing_canonical_action_from_defaults(self) -> None:
        config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")
        broken = json.loads(json.dumps(config.profiles))
        del broken["profiles"][0]["bindings"]["select"]
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory) / "missing-action.json"
            temporary.write_text(json.dumps(broken), encoding="utf-8")
            merged = BridgeConfig.load(CONFIG_DIR, user_config=temporary)
            self.assertIn("select", merged.profile("ps5")["bindings"])

    def test_rejects_structurally_malformed_saved_profile(self) -> None:
        config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")
        broken = json.loads(json.dumps(config.profiles))
        broken["profiles"][0]["bindings"] = []
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory) / "malformed-profile.json"
            temporary.write_text(json.dumps(broken), encoding="utf-8")
            with self.assertRaises(ConfigError):
                BridgeConfig.load(CONFIG_DIR, user_config=temporary)

    def test_live_runtime_can_fall_back_from_malformed_saved_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory) / "malformed-profile.json"
            temporary.write_text("{not valid json", encoding="utf-8")
            config = BridgeConfig.load(
                CONFIG_DIR,
                user_config=temporary,
                fallback_invalid_user=True,
            )
            self.assertEqual(config.profile("ps5")["id"], "ps5")
            self.assertEqual(len(config.warnings), 1)

    def test_rejects_backend_specific_godot_keycodes(self) -> None:
        config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")
        broken = json.loads(json.dumps(config.profiles))
        broken["profiles"][0]["bindings"]["select"] = [{"control": "godot_keycode:4194309"}]
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory) / "nonportable-profile.json"
            temporary.write_text(json.dumps(broken), encoding="utf-8")
            with self.assertRaises(ConfigError):
                BridgeConfig.load(CONFIG_DIR, user_config=temporary)


class MapperTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")

    def test_button_to_browser_output(self) -> None:
        semantic = SemanticMapper(self.config.profile("ps5"))
        adapter = AdapterMapper(self.config.adapters, "keyboard_navigation", "netflix")
        actions = semantic.feed({"control": "gamepad_button:south", "pressed": True})
        self.assertEqual(actions, ["select"])
        self.assertEqual(adapter.output_for(actions[0]), "key:enter")

    def test_axis_requires_neutral_before_repeating(self) -> None:
        semantic = SemanticMapper(self.config.profile("ps5"))
        right = {"control": "gamepad_axis:left_x", "value": 0.9}
        self.assertEqual(semantic.feed(right), ["navigate_right"])
        self.assertEqual(semantic.feed(right), [])
        self.assertEqual(semantic.feed({"control": "gamepad_axis:left_x", "value": 0.0}), [])
        self.assertEqual(semantic.feed(right), ["navigate_right"])

    def test_native_adapter_emits_nothing(self) -> None:
        adapter = AdapterMapper(self.config.adapters, "native", "steam")
        self.assertIsNone(adapter.output_for("select"))


if __name__ == "__main__":
    unittest.main()
