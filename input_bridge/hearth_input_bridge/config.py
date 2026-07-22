from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

CANONICAL_KEYS = {
    "arrow_up", "arrow_down", "arrow_left", "arrow_right", "enter", "escape",
    "home", "menu", "space", "tab", "backspace", "page_up", "page_down",
    "media_play_pause", "volume_up", "volume_down", "volume_mute",
    "browser_back", "browser_forward", "media_stop", "media_next", "media_previous",
    "media_record", "channel_up", "channel_down",
}
GAMEPAD_BUTTONS = {
    "south", "east", "west", "north", "back", "guide", "start", "left_stick",
    "right_stick", "left_shoulder", "right_shoulder", "dpad_up", "dpad_down",
    "dpad_left", "dpad_right", "misc1", "paddle1", "paddle2", "paddle3",
    "paddle4", "touchpad",
}
GAMEPAD_AXES = {"left_x", "left_y", "right_x", "right_y", "trigger_left", "trigger_right"}
ACTIONS = {
    "navigate_up", "navigate_down", "navigate_left", "navigate_right", "select", "back",
    "home", "menu", "play_pause", "page_left", "page_right",
}


class ConfigError(ValueError):
    """Raised when a shared Hearth input configuration is unsafe or invalid."""


@dataclass(frozen=True)
class BridgeConfig:
    profiles: dict[str, Any]
    policy: dict[str, Any]
    adapters: dict[str, Any]
    warnings: tuple[str, ...] = ()

    @classmethod
    def load(
        cls,
        config_dir: Path,
        user_config: Path | None = None,
        *,
        fallback_invalid_user: bool = False,
    ) -> "BridgeConfig":
        defaults = _read_json(config_dir / "input-profiles-defaults.json")
        policy = _read_json(config_dir / "app-input-policy.json")
        adapters = _read_json(config_dir / "input-adapters.json")
        profiles = defaults
        warnings: list[str] = []
        candidate = user_config or default_user_profile_path()
        if candidate.is_file():
            try:
                profiles = _merge_profiles(defaults, _read_json(candidate))
                _validate_profiles(profiles)
            except ConfigError as error:
                if not fallback_invalid_user:
                    raise
                profiles = defaults
                warnings.append(f"ignored invalid saved input profile {candidate}: {error}")
        _validate_profiles(profiles)
        _validate_policy(policy, adapters)
        return cls(profiles=profiles, policy=policy, adapters=adapters, warnings=tuple(warnings))

    def profile(self, profile_id: str) -> dict[str, Any]:
        for profile in self.profiles["profiles"]:
            if profile["id"] == profile_id:
                return profile
        raise ConfigError(f"Unknown profile: {profile_id}")

    def adapter_for_destination(self, destination_id: str) -> str:
        policy_id = self.policy["destinations"].get(destination_id)
        if not policy_id:
            raise ConfigError(f"Destination has no input policy: {destination_id}")
        adapter_id = self.policy["adapters"].get(policy_id)
        if not adapter_id:
            raise ConfigError(f"Input policy has no adapter: {policy_id}")
        return adapter_id


def default_user_profile_path() -> Path:
    config_root = os.environ.get("XDG_CONFIG_HOME")
    if not config_root:
        config_root = str(Path.home() / ".config")
    return Path(config_root) / "hearth" / "input-profiles.json"


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ConfigError(f"Could not read {path}: {error}") from error
    if not isinstance(value, dict):
        raise ConfigError(f"Expected a JSON object in {path}")
    return value


def _merge_profiles(defaults: dict[str, Any], saved: dict[str, Any]) -> dict[str, Any]:
    if saved.get("schema_version") != defaults.get("schema_version"):
        raise ConfigError("Saved input profiles use an unsupported schema version")
    merged = json.loads(json.dumps(saved))
    saved_profiles = merged.get("profiles")
    if not isinstance(saved_profiles, list) or any(not isinstance(profile, dict) for profile in saved_profiles):
        raise ConfigError("Saved input profiles are malformed")
    saved_by_id = {profile.get("id"): profile for profile in saved_profiles}
    for default_profile in defaults.get("profiles", []):
        saved_profile = saved_by_id.get(default_profile.get("id"))
        if saved_profile is None:
            merged.setdefault("profiles", []).append(json.loads(json.dumps(default_profile)))
            continue
        saved_bindings = saved_profile.get("bindings")
        if not isinstance(saved_bindings, dict):
            raise ConfigError(f"Saved profile {saved_profile.get('id', '')} has malformed bindings")
        for action, bindings in default_profile.get("bindings", {}).items():
            saved_bindings.setdefault(action, json.loads(json.dumps(bindings)))
    merged_defaults = dict(defaults.get("default_profiles", {}))
    merged_defaults.update(merged.get("default_profiles", {}))
    merged["default_profiles"] = merged_defaults
    return merged


def _validate_profiles(data: dict[str, Any]) -> None:
    if data.get("schema_version") != 2:
        raise ConfigError("Input profile schema must be version 2")
    profiles = data.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        raise ConfigError("Input profiles must be a non-empty list")
    ids: set[str] = set()
    for profile in profiles:
        if not isinstance(profile, dict) or not isinstance(profile.get("id"), str) or not profile["id"]:
            raise ConfigError("Every profile must have an id")
        if profile["id"] in ids:
            raise ConfigError(f"Duplicate profile id: {profile['id']}")
        ids.add(profile["id"])
        bindings = profile.get("bindings")
        if not isinstance(bindings, dict):
            raise ConfigError(f"Profile {profile['id']} has no bindings")
        match = profile.get("match", {})
        if not isinstance(match, dict):
            raise ConfigError(f"Profile {profile['id']} has malformed device matching")
        name_contains = match.get("name_contains", [])
        if not isinstance(name_contains, list) or any(not isinstance(value, str) or not value for value in name_contains):
            raise ConfigError(f"Profile {profile['id']} has malformed device names")
        evdev_match = match.get("evdev", {})
        if not isinstance(evdev_match, dict):
            raise ConfigError(f"Profile {profile['id']} has malformed evdev matching")
        vendor_id = evdev_match.get("vendor_id")
        product_ids = evdev_match.get("product_ids", [])
        if vendor_id is not None and (not isinstance(vendor_id, int) or isinstance(vendor_id, bool) or not 0 <= vendor_id <= 0xFFFF):
            raise ConfigError(f"Profile {profile['id']} has an invalid evdev vendor id")
        if not isinstance(product_ids, list) or any(
            not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= 0xFFFF for value in product_ids
        ):
            raise ConfigError(f"Profile {profile['id']} has invalid evdev product ids")
        if set(bindings) != ACTIONS:
            raise ConfigError(f"Profile {profile['id']} must define exactly the canonical action set")
        for action, action_bindings in bindings.items():
            if not isinstance(action_bindings, list) or not action_bindings:
                raise ConfigError(f"Profile {profile['id']} has no binding for {action}")
            for binding in action_bindings:
                _validate_binding(binding)
    defaults = data.get("default_profiles")
    if not isinstance(defaults, dict) or any(value not in ids for value in defaults.values()):
        raise ConfigError("Default profile references are invalid")
    assignments = data.get("device_assignments")
    if not isinstance(assignments, list):
        raise ConfigError("Device assignments must be a list of structured selectors")
    for assignment in assignments:
        if not isinstance(assignment, dict) or assignment.get("profile_id") not in ids:
            raise ConfigError("A device assignment references an unknown profile")
        selectors = assignment.get("selectors")
        if not isinstance(selectors, list) or not selectors:
            raise ConfigError("A device assignment must contain selectors")
        for selector in selectors:
            if not isinstance(selector, dict) or selector.get("backend") not in {"godot", "evdev"}:
                raise ConfigError("A device selector must name the godot or evdev backend")
            if selector["backend"] == "godot" and not any(selector.get(field) for field in ("device_kind", "guid", "name")):
                raise ConfigError("A Godot device selector has no identity")
            if selector["backend"] == "evdev" and not any(selector.get(field) for field in ("vendor_id", "product_id", "capability_fingerprint", "uniq")):
                raise ConfigError("An evdev device selector has no identity")


def _validate_binding(binding: Any) -> None:
    if not isinstance(binding, dict) or not isinstance(binding.get("control"), str):
        raise ConfigError("Every binding must have a canonical control")
    control = binding["control"]
    if control.startswith("key:"):
        key = control.removeprefix("key:")
        if key not in CANONICAL_KEYS and not (len(key) == 1 and key.isascii() and key.isalnum()):
            raise ConfigError(f"Unsupported canonical key: {control}")
    elif control.startswith("gamepad_button:"):
        if control.removeprefix("gamepad_button:") not in GAMEPAD_BUTTONS:
            raise ConfigError(f"Unsupported gamepad button: {control}")
    elif control.startswith("gamepad_axis:"):
        if control.removeprefix("gamepad_axis:") not in GAMEPAD_AXES:
            raise ConfigError(f"Unsupported gamepad axis: {control}")
    else:
        raise ConfigError(f"Unsupported control: {control}")
    if control.startswith("gamepad_axis:"):
        if binding.get("direction") not in {-1, 1}:
            raise ConfigError(f"Axis binding has an invalid direction: {control}")
        threshold = binding.get("threshold")
        if not isinstance(threshold, (int, float)) or isinstance(threshold, bool) or not 0 < threshold <= 1:
            raise ConfigError(f"Axis binding has an invalid threshold: {control}")


def _validate_policy(policy: dict[str, Any], adapters: dict[str, Any]) -> None:
    if policy.get("schema_version") != 1 or adapters.get("schema_version") != 1:
        raise ConfigError("Input policy and adapter schemas must be version 1")
    adapter_definitions = adapters.get("adapters")
    if not isinstance(adapter_definitions, dict):
        raise ConfigError("Adapter definitions are missing")
    policy_adapters = policy.get("adapters")
    destinations = policy.get("destinations")
    if not isinstance(policy_adapters, dict) or not isinstance(destinations, dict):
        raise ConfigError("Input policy mappings are missing")
    for policy_id, adapter_id in policy_adapters.items():
        if adapter_id not in adapter_definitions:
            raise ConfigError(f"Policy {policy_id} references unknown adapter {adapter_id}")
    if any(policy_id not in policy_adapters for policy_id in destinations.values()):
        raise ConfigError("A destination references an unknown policy")
    for adapter_id, definition in adapter_definitions.items():
        if not isinstance(definition, dict):
            raise ConfigError(f"Adapter {adapter_id} is malformed")
        outputs = definition.get("outputs", {})
        overrides = definition.get("destination_overrides", {})
        if not isinstance(outputs, dict) or not isinstance(overrides, dict):
            raise ConfigError(f"Adapter {adapter_id} outputs are malformed")
        if any(action not in ACTIONS for action in outputs):
            raise ConfigError(f"Adapter {adapter_id} references an unknown semantic action")
        for output in outputs.values():
            _validate_adapter_output(output)
        for destination_id, destination_outputs in overrides.items():
            if destination_id not in destinations or not isinstance(destination_outputs, dict):
                raise ConfigError(f"Adapter {adapter_id} has an invalid destination override")
            if any(action not in ACTIONS for action in destination_outputs):
                raise ConfigError(f"Adapter {adapter_id} override references an unknown semantic action")
            for output in destination_outputs.values():
                _validate_adapter_output(output)


def _validate_adapter_output(output: Any) -> None:
    if output == "bridge:return_to_hearth":
        return
    if not isinstance(output, str) or not output.startswith("key:"):
        raise ConfigError("Adapter outputs must be allowlisted keys or bridge:return_to_hearth")
    key = output.removeprefix("key:")
    if key not in CANONICAL_KEYS and not (len(key) == 1 and key.isascii() and key.isalnum()):
        raise ConfigError(f"Unsupported adapter output: {output}")
