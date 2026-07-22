from __future__ import annotations

from typing import Any


class SemanticMapper:
    """Converts canonical physical events into Hearth semantic actions."""

    def __init__(self, profile: dict[str, Any], neutral_threshold: float = 0.35) -> None:
        self._bindings: dict[str, list[dict[str, Any]]] = profile["bindings"]
        self._neutral_threshold = neutral_threshold
        self._axis_armed: dict[str, bool] = {}

    def feed(self, event: dict[str, Any]) -> list[str]:
        control = event.get("control")
        if not isinstance(control, str):
            return []
        if control.startswith("gamepad_axis:"):
            return self._feed_axis(event)
        if event.get("pressed", True) is not True:
            return []
        return [
            action
            for action, bindings in self._bindings.items()
            if any(binding.get("control") == control for binding in bindings)
        ]

    def _feed_axis(self, event: dict[str, Any]) -> list[str]:
        control = event["control"]
        try:
            value = float(event["value"])
        except (KeyError, TypeError, ValueError):
            return []
        if abs(value) <= self._neutral_threshold:
            self._axis_armed[control] = True
            return []
        if not self._axis_armed.get(control, True):
            return []
        direction = -1 if value < 0 else 1
        matches: list[str] = []
        for action, bindings in self._bindings.items():
            for binding in bindings:
                if binding.get("control") != control or binding.get("direction") != direction:
                    continue
                if abs(value) >= float(binding.get("threshold", 0.72)):
                    matches.append(action)
                    break
        if matches:
            self._axis_armed[control] = False
        return matches


class AdapterMapper:
    """Maps semantic actions to safe virtual-output requests for one app adapter."""

    def __init__(self, adapters: dict[str, Any], adapter_id: str, destination_id: str = "") -> None:
        definition = adapters["adapters"].get(adapter_id)
        if not isinstance(definition, dict):
            raise ValueError(f"Unknown adapter: {adapter_id}")
        self._outputs = dict(definition.get("outputs", {}))
        overrides = definition.get("destination_overrides", {}).get(destination_id, {})
        self._outputs.update(overrides)

    def output_for(self, action: str) -> str | None:
        value = self._outputs.get(action)
        return value if isinstance(value, str) and value else None
