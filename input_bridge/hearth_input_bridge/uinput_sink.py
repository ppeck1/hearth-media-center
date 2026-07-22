from __future__ import annotations

import time
from typing import Any

from .evdev_source import VIRTUAL_DEVICE_PREFIX, load_evdev


KEY_NAMES = {
    "arrow_up": "KEY_UP",
    "arrow_down": "KEY_DOWN",
    "arrow_left": "KEY_LEFT",
    "arrow_right": "KEY_RIGHT",
    "enter": "KEY_ENTER",
    "escape": "KEY_ESC",
    "home": "KEY_HOME",
    "menu": "KEY_MENU",
    "space": "KEY_SPACE",
    "tab": "KEY_TAB",
    "backspace": "KEY_BACKSPACE",
    "page_up": "KEY_PAGEUP",
    "page_down": "KEY_PAGEDOWN",
    "media_play_pause": "KEY_PLAYPAUSE",
    "volume_up": "KEY_VOLUMEUP",
    "volume_down": "KEY_VOLUMEDOWN",
    "volume_mute": "KEY_MUTE",
    "browser_back": "KEY_BACK",
    "browser_forward": "KEY_FORWARD",
    "media_stop": "KEY_STOPCD",
    "media_next": "KEY_NEXTSONG",
    "media_previous": "KEY_PREVIOUSSONG",
    "media_record": "KEY_RECORD",
    "channel_up": "KEY_CHANNELUP",
    "channel_down": "KEY_CHANNELDOWN",
}


class UInputUnavailable(RuntimeError):
    """Raised when the virtual keyboard cannot be created safely."""


class UInputSink:
    """Emits allowlisted key taps through one short-lived virtual keyboard."""

    def __init__(self, evdev_module: Any | None = None, tap_delay: float = 0.008) -> None:
        self._evdev = evdev_module or load_evdev()
        self._tap_delay = tap_delay
        ecodes = self._evdev.ecodes
        self._key_codes = {
            key: getattr(ecodes, code_name)
            for key, code_name in KEY_NAMES.items()
            if hasattr(ecodes, code_name)
        }
        for character in "abcdefghijklmnopqrstuvwxyz0123456789":
            code_name = "KEY_" + character.upper()
            if hasattr(ecodes, code_name):
                self._key_codes[character] = getattr(ecodes, code_name)
        try:
            self._device = self._evdev.UInput(
                {ecodes.EV_KEY: sorted(set(self._key_codes.values()))},
                name=VIRTUAL_DEVICE_PREFIX + " Keyboard",
                vendor=0x4845,
                product=0x0001,
                version=1,
            )
        except OSError as error:
            raise UInputUnavailable(
                f"could not open /dev/uinput: {error}; run the Fedora input setup and verify the active-user ACL"
            ) from error

    def emit(self, output: str) -> None:
        if not output.startswith("key:"):
            raise ValueError(f"unsupported virtual output: {output}")
        key_name = output.removeprefix("key:")
        key_code = self._key_codes.get(key_name)
        if key_code is None:
            raise ValueError(f"unsupported virtual key: {key_name}")
        ecodes = self._evdev.ecodes
        self._device.write(ecodes.EV_KEY, key_code, 1)
        self._device.syn()
        try:
            if self._tap_delay > 0:
                time.sleep(self._tap_delay)
        finally:
            self._device.write(ecodes.EV_KEY, key_code, 0)
            self._device.syn()

    def close(self) -> None:
        self._device.close()
