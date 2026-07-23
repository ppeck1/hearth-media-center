from __future__ import annotations

import select
import time
from dataclasses import dataclass
from typing import Any, Callable, Iterable


VIRTUAL_DEVICE_PREFIX = "Hearth Virtual"


class EvdevUnavailable(RuntimeError):
    """Raised when the Linux evdev runtime is not installed or accessible."""


def load_evdev() -> Any:
    try:
        import evdev  # type: ignore[import-not-found]
    except ImportError as error:
        raise EvdevUnavailable(
            "python3-evdev is not installed; on Fedora run: sudo dnf install python3-evdev"
        ) from error
    return evdev


def _code(ecodes: Any, name: str) -> int | None:
    value = getattr(ecodes, name, None)
    return value if isinstance(value, int) else None


def _codes(ecodes: Any, names: Iterable[str]) -> set[int]:
    return {value for name in names if (value := _code(ecodes, name)) is not None}


def _capability_codes(entries: Iterable[Any]) -> set[int]:
    """Return event codes from both plain and ``(code, info)`` evdev shapes."""
    codes: set[int] = set()
    for entry in entries:
        if isinstance(entry, int):
            codes.add(entry)
        elif isinstance(entry, tuple) and entry and isinstance(entry[0], int):
            codes.add(entry[0])
    return codes


def is_controller_capabilities(capabilities: dict[int, Any], ecodes: Any) -> bool:
    key_codes = _capability_codes(capabilities.get(ecodes.EV_KEY, []))
    abs_codes = _capability_codes(capabilities.get(ecodes.EV_ABS, []))
    gamepad_buttons = _codes(
        ecodes,
        (
            "BTN_SOUTH",
            "BTN_EAST",
            "BTN_NORTH",
            "BTN_WEST",
            "BTN_START",
            "BTN_SELECT",
            "BTN_MODE",
            "BTN_TL",
            "BTN_TR",
        ),
    )
    gamepad_axes = _codes(ecodes, ("ABS_X", "ABS_Y", "ABS_RX", "ABS_RY", "ABS_HAT0X", "ABS_HAT0Y"))
    return len(key_codes & gamepad_buttons) >= 4 and len(abs_codes & gamepad_axes) >= 2


@dataclass(frozen=True)
class ControllerInfo:
    path: str
    name: str
    vendor_id: int
    product_id: int


class EventDecoder:
    """Converts Linux input events into backend-neutral controls."""

    def __init__(self, ecodes: Any, absinfo: Callable[[int], Any]) -> None:
        self._ecodes = ecodes
        self._absinfo = absinfo
        self._hat_state: dict[int, int] = {}
        self._buttons = {
            code: control
            for name, control in {
                "BTN_SOUTH": "south",
                "BTN_EAST": "east",
                "BTN_WEST": "west",
                "BTN_NORTH": "north",
                "BTN_SELECT": "back",
                "BTN_MODE": "guide",
                "BTN_START": "start",
                "BTN_THUMBL": "left_stick",
                "BTN_THUMBR": "right_stick",
                "BTN_TL": "left_shoulder",
                "BTN_TR": "right_shoulder",
                "BTN_DPAD_UP": "dpad_up",
                "BTN_DPAD_DOWN": "dpad_down",
                "BTN_DPAD_LEFT": "dpad_left",
                "BTN_DPAD_RIGHT": "dpad_right",
            }.items()
            if (code := _code(ecodes, name)) is not None
        }
        self._axes = {
            code: control
            for name, control in {
                "ABS_X": "left_x",
                "ABS_Y": "left_y",
                "ABS_RX": "right_x",
                "ABS_RY": "right_y",
                "ABS_Z": "trigger_left",
                "ABS_RZ": "trigger_right",
            }.items()
            if (code := _code(ecodes, name)) is not None
        }
        self._hats = {
            code: controls
            for name, controls in {
                "ABS_HAT0X": ("dpad_left", "dpad_right"),
                "ABS_HAT0Y": ("dpad_up", "dpad_down"),
            }.items()
            if (code := _code(ecodes, name)) is not None
        }

    def feed(self, event: Any) -> list[dict[str, Any]]:
        if event.type == self._ecodes.EV_KEY and event.code in self._buttons:
            return [
                {
                    "control": "gamepad_button:" + self._buttons[event.code],
                    "pressed": event.value != 0,
                }
            ]
        if event.type != self._ecodes.EV_ABS:
            return []
        if event.code in self._hats:
            return self._decode_hat(event.code, int(event.value))
        if event.code in self._axes:
            return [
                {
                    "control": "gamepad_axis:" + self._axes[event.code],
                    "value": self._normalize_axis(event.code, float(event.value)),
                }
            ]
        return []

    def _decode_hat(self, code: int, value: int) -> list[dict[str, Any]]:
        previous = self._hat_state.get(code, 0)
        if value == previous:
            return []
        negative, positive = self._hats[code]
        events: list[dict[str, Any]] = []
        if previous < 0:
            events.append({"control": "gamepad_button:" + negative, "pressed": False})
        elif previous > 0:
            events.append({"control": "gamepad_button:" + positive, "pressed": False})
        if value < 0:
            events.append({"control": "gamepad_button:" + negative, "pressed": True})
        elif value > 0:
            events.append({"control": "gamepad_button:" + positive, "pressed": True})
        self._hat_state[code] = value
        return events

    def _normalize_axis(self, code: int, value: float) -> float:
        info = self._absinfo(code)
        minimum = float(getattr(info, "min", -32768.0))
        maximum = float(getattr(info, "max", 32767.0))
        if maximum <= minimum:
            return 0.0
        midpoint = (minimum + maximum) / 2.0
        half_range = (maximum - minimum) / 2.0
        return max(-1.0, min(1.0, (value - midpoint) / half_range))


class EvdevSource:
    """Discovers, grabs, and polls controller event nodes for one app session."""

    def __init__(
        self,
        *,
        grab: bool = True,
        name_contains: Iterable[str] = (),
        vendor_id: int | None = None,
        product_ids: Iterable[int] = (),
        rescan_interval: float = 1.0,
        evdev_module: Any | None = None,
    ) -> None:
        self._evdev = evdev_module or load_evdev()
        self._grab = grab
        self._name_contains = tuple(value.casefold() for value in name_contains if value)
        self._vendor_id = vendor_id
        self._product_ids = set(product_ids)
        self._rescan_interval = rescan_interval
        self._next_scan = 0.0
        self._devices: dict[str, tuple[Any, EventDecoder]] = {}
        self.last_error = ""

    @classmethod
    def probe(cls, evdev_module: Any | None = None, errors: list[str] | None = None) -> list[ControllerInfo]:
        module = evdev_module or load_evdev()
        controllers: list[ControllerInfo] = []
        for path in module.list_devices():
            device: Any | None = None
            try:
                device = module.InputDevice(path)
                if device.name.startswith(VIRTUAL_DEVICE_PREFIX):
                    continue
                if not is_controller_capabilities(device.capabilities(), module.ecodes):
                    continue
                controllers.append(
                    ControllerInfo(
                        path=device.path,
                        name=device.name,
                        vendor_id=int(device.info.vendor),
                        product_id=int(device.info.product),
                    )
                )
            except OSError as error:
                if errors is not None:
                    errors.append(f"could not inspect {path}: {error}")
            finally:
                try:
                    if device is not None:
                        device.close()
                except OSError:
                    pass
        return controllers

    def poll(self, timeout: float = 0.1) -> list[dict[str, Any]]:
        self._scan_if_due()
        if not self._devices:
            time.sleep(max(0.0, min(timeout, self._rescan_interval)))
            self._scan_if_due(force=True)
            return []
        devices_by_fd = {device.fd: (path, device, decoder) for path, (device, decoder) in self._devices.items()}
        try:
            ready, _, _ = select.select(list(devices_by_fd), [], [], timeout)
        except (OSError, ValueError) as error:
            self.last_error = f"controller poll failed: {error}"
            self._drop_all()
            return []
        decoded: list[dict[str, Any]] = []
        for descriptor in ready:
            path, device, decoder = devices_by_fd[descriptor]
            try:
                for event in device.read():
                    decoded.extend(decoder.feed(event))
            except (BlockingIOError, InterruptedError):
                continue
            except OSError as error:
                self.last_error = f"controller disconnected ({device.name}): {error}"
                self._drop(path)
        return decoded

    def close(self) -> None:
        self._drop_all()

    def _scan_if_due(self, force: bool = False) -> None:
        now = time.monotonic()
        if not force and now < self._next_scan:
            return
        self._next_scan = now + self._rescan_interval
        try:
            paths = set(self._evdev.list_devices())
        except OSError as error:
            self.last_error = f"could not list input devices: {error}"
            return
        for stale in set(self._devices) - paths:
            self._drop(stale)
        for path in sorted(paths - set(self._devices)):
            if self._devices:
                break
            self._add(path)

    def _add(self, path: str) -> None:
        try:
            device = self._evdev.InputDevice(path)
            if device.name.startswith(VIRTUAL_DEVICE_PREFIX) or not self._matches_device(device) or not is_controller_capabilities(
                device.capabilities(), self._evdev.ecodes
            ):
                device.close()
                return
            if self._grab:
                device.grab()
            self._devices[path] = (device, EventDecoder(self._evdev.ecodes, device.absinfo))
        except OSError as error:
            self.last_error = f"could not open controller {path}: {error}"
            try:
                device.close()
            except (NameError, OSError):
                pass

    def _matches_device(self, device: Any) -> bool:
        has_evdev_identity = self._vendor_id is not None
        if has_evdev_identity and int(device.info.vendor) == self._vendor_id:
            if not self._product_ids or int(device.info.product) in self._product_ids:
                return True
        if not self._name_contains and not has_evdev_identity:
            return True
        normalized = device.name.casefold()
        return any(fragment in normalized for fragment in self._name_contains)

    def _drop(self, path: str) -> None:
        entry = self._devices.pop(path, None)
        if entry is None:
            return
        device, _ = entry
        if self._grab:
            try:
                device.ungrab()
            except OSError:
                pass
        try:
            device.close()
        except OSError:
            pass

    def _drop_all(self) -> None:
        for path in list(self._devices):
            self._drop(path)
