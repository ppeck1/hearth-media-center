from __future__ import annotations

import json
import signal
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from input_bridge.hearth_input_bridge import BridgeConfig, ConfigError, EventDecoder, SessionRunner, UInputSink
from input_bridge.hearth_input_bridge.evdev_source import is_controller_capabilities


REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = REPO_ROOT / "launcher" / "config"


class FakeEcodes:
    EV_KEY = 1
    EV_ABS = 3
    BTN_SOUTH = 304
    BTN_EAST = 305
    BTN_NORTH = 307
    BTN_WEST = 308
    BTN_TL = 310
    BTN_TR = 311
    BTN_SELECT = 314
    BTN_START = 315
    BTN_MODE = 316
    BTN_THUMBL = 317
    BTN_THUMBR = 318
    ABS_X = 0
    ABS_Y = 1
    ABS_Z = 2
    ABS_RX = 3
    ABS_RY = 4
    ABS_RZ = 5
    ABS_HAT0X = 16
    ABS_HAT0Y = 17
    KEY_UP = 103
    KEY_DOWN = 108
    KEY_LEFT = 105
    KEY_RIGHT = 106
    KEY_ENTER = 28
    KEY_ESC = 1
    KEY_PLAYPAUSE = 164


class FakeUInput:
    def __init__(self, events: dict[int, list[int]], **metadata: Any) -> None:
        self.events = events
        self.metadata = metadata
        self.writes: list[tuple[int, int, int] | tuple[str]] = []
        self.closed = False

    def write(self, event_type: int, code: int, value: int) -> None:
        self.writes.append((event_type, code, value))

    def syn(self) -> None:
        self.writes.append(("syn",))

    def close(self) -> None:
        self.closed = True


class FakeEvdev:
    ecodes = FakeEcodes

    def __init__(self) -> None:
        self.devices: list[FakeUInput] = []

    def UInput(self, events: dict[int, list[int]], **metadata: Any) -> FakeUInput:
        device = FakeUInput(events, **metadata)
        self.devices.append(device)
        return device


class EvdevDecoderTests(unittest.TestCase):
    def setUp(self) -> None:
        axis_info = SimpleNamespace(min=-32768, max=32767)
        self.decoder = EventDecoder(FakeEcodes, lambda _code: axis_info)

    def test_controller_capability_filter_rejects_keyboard_and_virtual_keyboard_shape(self) -> None:
        controller = {
            FakeEcodes.EV_KEY: [
                FakeEcodes.BTN_SOUTH,
                FakeEcodes.BTN_EAST,
                FakeEcodes.BTN_NORTH,
                FakeEcodes.BTN_WEST,
            ],
            FakeEcodes.EV_ABS: [FakeEcodes.ABS_X, FakeEcodes.ABS_Y],
        }
        keyboard = {FakeEcodes.EV_KEY: [FakeEcodes.KEY_UP, FakeEcodes.KEY_ENTER]}
        self.assertTrue(is_controller_capabilities(controller, FakeEcodes))
        self.assertFalse(is_controller_capabilities(keyboard, FakeEcodes))

    def test_decodes_dualsense_buttons_and_release(self) -> None:
        pressed = self.decoder.feed(SimpleNamespace(type=FakeEcodes.EV_KEY, code=FakeEcodes.BTN_SOUTH, value=1))
        released = self.decoder.feed(SimpleNamespace(type=FakeEcodes.EV_KEY, code=FakeEcodes.BTN_SOUTH, value=0))
        self.assertEqual(pressed, [{"control": "gamepad_button:south", "pressed": True}])
        self.assertEqual(released, [{"control": "gamepad_button:south", "pressed": False}])

    def test_hat_direction_releases_before_opposite_press(self) -> None:
        left = self.decoder.feed(SimpleNamespace(type=FakeEcodes.EV_ABS, code=FakeEcodes.ABS_HAT0X, value=-1))
        right = self.decoder.feed(SimpleNamespace(type=FakeEcodes.EV_ABS, code=FakeEcodes.ABS_HAT0X, value=1))
        self.assertEqual(left, [{"control": "gamepad_button:dpad_left", "pressed": True}])
        self.assertEqual(
            right,
            [
                {"control": "gamepad_button:dpad_left", "pressed": False},
                {"control": "gamepad_button:dpad_right", "pressed": True},
            ],
        )

    def test_normalizes_stick_axis(self) -> None:
        event = SimpleNamespace(type=FakeEcodes.EV_ABS, code=FakeEcodes.ABS_X, value=32767)
        decoded = self.decoder.feed(event)
        self.assertEqual(decoded[0]["control"], "gamepad_axis:left_x")
        self.assertAlmostEqual(decoded[0]["value"], 1.0)


class UInputSinkTests(unittest.TestCase):
    def test_emits_complete_key_tap_and_closes(self) -> None:
        module = FakeEvdev()
        sink = UInputSink(module, tap_delay=0)
        sink.emit("key:enter")
        sink.close()
        self.assertEqual(
            module.devices[0].writes,
            [
                (FakeEcodes.EV_KEY, FakeEcodes.KEY_ENTER, 1),
                ("syn",),
                (FakeEcodes.EV_KEY, FakeEcodes.KEY_ENTER, 0),
                ("syn",),
            ],
        )
        self.assertTrue(module.devices[0].closed)
        self.assertEqual(module.devices[0].metadata["name"], "Hearth Virtual Keyboard")

    def test_rejects_non_allowlisted_output(self) -> None:
        sink = UInputSink(FakeEvdev(), tap_delay=0)
        with self.assertRaises(ValueError):
            sink.emit("command:shutdown")
        sink.close()

    def test_releases_key_when_tap_is_interrupted(self) -> None:
        module = FakeEvdev()
        sink = UInputSink(module, tap_delay=0.01)
        with patch("input_bridge.hearth_input_bridge.uinput_sink.time.sleep", side_effect=InterruptedError):
            with self.assertRaises(InterruptedError):
                sink.emit("key:media_play_pause")
        self.assertEqual(module.devices[0].writes[-2:], [(FakeEcodes.EV_KEY, FakeEcodes.KEY_PLAYPAUSE, 0), ("syn",)])
        sink.close()


class FakeSource:
    def __init__(self, events: list[dict[str, Any]], *, grab: bool) -> None:
        self.events = events
        self.grab = grab
        self.closed = False

    def poll(self, _timeout: float) -> list[dict[str, Any]]:
        events, self.events = self.events, []
        return events

    def close(self) -> None:
        self.closed = True


class FakeSink:
    def __init__(self) -> None:
        self.outputs: list[str] = []
        self.closed = False

    def emit(self, output: str) -> None:
        self.outputs.append(output)

    def close(self) -> None:
        self.closed = True


class FailingSink(FakeSink):
    def emit(self, output: str) -> None:
        del output
        raise OSError("uinput disappeared")


class FakeProcess:
    pid = 4242

    def __init__(self, finish_after_polls: int = 2) -> None:
        self.finish_after_polls = finish_after_polls
        self.polls = 0
        self.returncode: int | None = None
        self.terminated = False

    def poll(self) -> int | None:
        if self.returncode is not None:
            return self.returncode
        self.polls += 1
        if self.polls >= self.finish_after_polls:
            self.returncode = 0
        return self.returncode

    def wait(self, timeout: float | None = None) -> int:
        del timeout
        if self.returncode is None:
            self.returncode = 0
        return self.returncode

    def terminate(self) -> None:
        self.terminated = True
        self.returncode = 0

    def send_signal(self, _signum: int) -> None:
        self.terminate()


class StubbornProcess(FakeProcess):
    def __init__(self) -> None:
        super().__init__(finish_after_polls=100)
        self.wait_attempts = 0

    def wait(self, timeout: float | None = None) -> int:
        self.wait_attempts += 1
        if self.wait_attempts == 1 and timeout is not None:
            raise subprocess.TimeoutExpired("fake-browser", timeout)
        self.returncode = 0
        return 0


class SessionRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = BridgeConfig.load(CONFIG_DIR, user_config=REPO_ROOT / "does-not-exist.json")

    def test_browser_session_routes_controller_and_cleans_up(self) -> None:
        source = FakeSource([{"control": "gamepad_button:south", "pressed": True}], grab=True)
        sink = FakeSink()
        process = FakeProcess()
        runner = SessionRunner(
            self.config,
            "ps5",
            "netflix",
            ["fake-browser"],
            source_factory=lambda **_kwargs: source,
            sink_factory=lambda: sink,
            popen=lambda *_args, **_kwargs: process,
            signal_process=lambda child, _signum: child.terminate(),
            poll_interval=0,
        )
        self.assertEqual(runner.run(), 0)
        self.assertEqual(sink.outputs, ["key:enter"])
        self.assertTrue(source.closed)
        self.assertTrue(sink.closed)

    def test_native_destination_never_creates_translation_devices(self) -> None:
        process = FakeProcess(finish_after_polls=1)
        runner = SessionRunner(
            self.config,
            "ps5",
            "steam",
            ["fake-steam"],
            source_factory=lambda **_kwargs: self.fail("native destination opened evdev"),
            sink_factory=lambda: self.fail("native destination opened uinput"),
            popen=lambda *_args, **_kwargs: process,
        )
        self.assertEqual(runner.run(), 0)

    def test_guide_requests_safe_return_to_hearth(self) -> None:
        source = FakeSource(
            [
                {"control": "gamepad_button:guide", "pressed": True},
                {"control": "gamepad_button:south", "pressed": True},
            ],
            grab=True,
        )
        sink = FakeSink()
        process = FakeProcess(finish_after_polls=100)
        runner = SessionRunner(
            self.config,
            "ps5",
            "netflix",
            ["fake-browser"],
            source_factory=lambda **_kwargs: source,
            sink_factory=lambda: sink,
            popen=lambda *_args, **_kwargs: process,
            signal_process=lambda child, _signum: child.terminate(),
            poll_interval=0,
        )
        self.assertEqual(runner.run(), 0)
        self.assertTrue(process.terminated)
        self.assertEqual(sink.outputs, [])

    def test_runtime_translation_failure_keeps_application_open(self) -> None:
        source = FakeSource([{"control": "gamepad_button:south", "pressed": True}], grab=True)
        sink = FailingSink()
        process = FakeProcess(finish_after_polls=3)
        runner = SessionRunner(
            self.config,
            "ps5",
            "netflix",
            ["fake-browser"],
            source_factory=lambda **_kwargs: source,
            sink_factory=lambda: sink,
            popen=lambda *_args, **_kwargs: process,
            signal_process=lambda child, _signum: child.terminate(),
            poll_interval=0,
        )
        self.assertEqual(runner.run(), 0)
        self.assertFalse(process.terminated)
        self.assertTrue(source.closed)
        self.assertTrue(sink.closed)

    def test_home_escalates_and_reaps_an_unresponsive_application(self) -> None:
        source = FakeSource([{"control": "gamepad_button:guide", "pressed": True}], grab=True)
        sink = FakeSink()
        process = StubbornProcess()
        delivered_signals: list[int] = []

        def deliver(child: FakeProcess, signum: int) -> None:
            del child
            delivered_signals.append(signum)

        runner = SessionRunner(
            self.config,
            "ps5",
            "netflix",
            ["fake-browser"],
            source_factory=lambda **_kwargs: source,
            sink_factory=lambda: sink,
            popen=lambda *_args, **_kwargs: process,
            signal_process=deliver,
            poll_interval=0,
            graceful_timeout=0,
        )
        self.assertEqual(runner.run(), 0)
        self.assertEqual(delivered_signals, [signal.SIGTERM, getattr(signal, "SIGKILL", 9)])
        self.assertEqual(process.wait_attempts, 3)


class ProbeDevice:
    def __init__(self, path: str, name: str = "DualSense Wireless Controller") -> None:
        self.path = path
        self.name = name
        self.info = SimpleNamespace(vendor=0x054C, product=0x0CE6)
        self.closed = False
        self.grabbed = False
        self.ungrabbed = False
        self.fd = 10

    def capabilities(self) -> dict[int, list[int]]:
        return {
            FakeEcodes.EV_KEY: [
                FakeEcodes.BTN_SOUTH,
                FakeEcodes.BTN_EAST,
                FakeEcodes.BTN_NORTH,
                FakeEcodes.BTN_WEST,
            ],
            FakeEcodes.EV_ABS: [FakeEcodes.ABS_X, FakeEcodes.ABS_Y],
        }

    def absinfo(self, _code: int) -> Any:
        return SimpleNamespace(min=-32768, max=32767)

    def grab(self) -> None:
        self.grabbed = True

    def ungrab(self) -> None:
        self.ungrabbed = True

    def close(self) -> None:
        self.closed = True


class ProbeEvdev:
    ecodes = FakeEcodes

    def __init__(self, names: dict[str, str], inaccessible: set[str] | None = None) -> None:
        self.names = names
        self.inaccessible = inaccessible or set()
        self.opened: list[ProbeDevice] = []

    def list_devices(self) -> list[str]:
        return list(self.names)

    def InputDevice(self, path: str) -> ProbeDevice:
        if path in self.inaccessible:
            raise PermissionError("access denied")
        device = ProbeDevice(path, self.names[path])
        self.opened.append(device)
        return device


class EvdevSourceLifecycleTests(unittest.TestCase):
    def test_probe_skips_inaccessible_nodes_and_reports_error(self) -> None:
        from input_bridge.hearth_input_bridge import EvdevSource

        module = ProbeEvdev(
            {"/dev/input/event0": "Keyboard", "/dev/input/event9": "DualSense Wireless Controller"},
            inaccessible={"/dev/input/event0"},
        )
        errors: list[str] = []
        controllers = EvdevSource.probe(module, errors)
        self.assertEqual([controller.path for controller in controllers], ["/dev/input/event9"])
        self.assertEqual(len(errors), 1)

    def test_name_filter_grabs_only_one_matching_controller_and_releases_it(self) -> None:
        from input_bridge.hearth_input_bridge import EvdevSource

        module = ProbeEvdev(
            {
                "/dev/input/event1": "Generic Gamepad",
                "/dev/input/event2": "DualSense Wireless Controller",
                "/dev/input/event3": "DualSense Wireless Controller",
            }
        )
        source = EvdevSource(evdev_module=module, name_contains=["dualsense"], rescan_interval=0)
        source._scan_if_due(force=True)
        grabbed = [device for device in module.opened if device.grabbed]
        self.assertEqual(len(grabbed), 1)
        self.assertEqual(grabbed[0].path, "/dev/input/event2")
        source.close()
        self.assertTrue(grabbed[0].ungrabbed)
        self.assertTrue(grabbed[0].closed)

    def test_dualsense_vendor_identity_accepts_fedora_wireless_name(self) -> None:
        from input_bridge.hearth_input_bridge import EvdevSource

        module = ProbeEvdev({"/dev/input/event7": "Sony Interactive Entertainment Wireless Controller"})
        source = EvdevSource(
            evdev_module=module,
            name_contains=["dualsense"],
            vendor_id=0x054C,
            product_ids=[0x0CE6],
            rescan_interval=0,
        )
        source._scan_if_due(force=True)
        self.assertEqual(len([device for device in module.opened if device.grabbed]), 1)
        source.close()


class PolicyValidationTests(unittest.TestCase):
    def test_rejects_command_like_adapter_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config_dir = Path(directory)
            for name in ("input-profiles-defaults.json", "app-input-policy.json", "input-adapters.json"):
                (config_dir / name).write_text((CONFIG_DIR / name).read_text(encoding="utf-8"), encoding="utf-8")
            adapters_path = config_dir / "input-adapters.json"
            adapters = json.loads(adapters_path.read_text(encoding="utf-8"))
            adapters["adapters"]["keyboard_navigation"]["outputs"]["select"] = "command:rm"
            adapters_path.write_text(json.dumps(adapters), encoding="utf-8")
            with self.assertRaises(ConfigError):
                BridgeConfig.load(config_dir, user_config=REPO_ROOT / "does-not-exist.json")


if __name__ == "__main__":
    unittest.main()
