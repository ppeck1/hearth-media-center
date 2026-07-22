from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from collections.abc import Callable, Sequence
from typing import Any

from .config import BridgeConfig
from .evdev_source import EvdevSource, EvdevUnavailable
from .mapper import AdapterMapper, SemanticMapper
from .uinput_sink import UInputSink, UInputUnavailable

FORCE_KILL_SIGNAL = getattr(signal, "SIGKILL", 9)


def _signal_process(child: Any, signum: int) -> None:
    if os.name == "posix":
        os.killpg(child.pid, signum)
    else:
        child.send_signal(signum)


class SessionRunner:
    """Supervises one translated destination and owns all input resources."""

    def __init__(
        self,
        config: BridgeConfig,
        profile_id: str,
        destination_id: str,
        command: Sequence[str],
        *,
        grab: bool = True,
        source_factory: Callable[..., Any] = EvdevSource,
        sink_factory: Callable[[], Any] = UInputSink,
        popen: Callable[..., Any] = subprocess.Popen,
        signal_process: Callable[[Any, int], None] = _signal_process,
        poll_interval: float = 0.08,
        graceful_timeout: float = 10.0,
    ) -> None:
        if not command:
            raise ValueError("an application command is required")
        self._config = config
        self._profile_id = profile_id
        self._destination_id = destination_id
        self._command = list(command)
        self._grab = grab
        self._source_factory = source_factory
        self._sink_factory = sink_factory
        self._popen = popen
        self._signal_process = signal_process
        self._poll_interval = poll_interval
        self._graceful_timeout = graceful_timeout
        self._stop_signal: int | None = None
        self._child: Any | None = None

    def run(self) -> int:
        adapter_id = self._config.adapter_for_destination(self._destination_id)
        if adapter_id in {"native", "internal"}:
            return self._run_native()

        profile = self._config.profile(self._profile_id)
        mapper = SemanticMapper(profile)
        adapter = AdapterMapper(self._config.adapters, adapter_id, self._destination_id)
        source: Any | None = None
        sink: Any | None = None
        reported_source_error = ""
        try:
            try:
                name_contains = profile.get("match", {}).get("name_contains", [])
                evdev_match = profile.get("match", {}).get("evdev", {})
                source = self._source_factory(
                    grab=self._grab,
                    name_contains=name_contains,
                    vendor_id=evdev_match.get("vendor_id"),
                    product_ids=evdev_match.get("product_ids", []),
                )
                sink = self._sink_factory()
            except (EvdevUnavailable, UInputUnavailable, OSError) as error:
                print(f"hearth-input-bridge: controller translation unavailable: {error}", file=sys.stderr)
                if source is not None:
                    source.close()
                source = None
                sink = None
            restore_handlers = self._install_signal_handlers()
            try:
                self._child = self._start_child()
                while self._child.poll() is None and self._stop_signal is None:
                    if source is None or sink is None:
                        time.sleep(self._poll_interval)
                        continue
                    try:
                        events = source.poll(self._poll_interval)
                        source_error = str(getattr(source, "last_error", ""))
                        if source_error and source_error != reported_source_error:
                            print(f"hearth-input-bridge: {source_error}", file=sys.stderr)
                            reported_source_error = source_error
                        return_requested = False
                        for event in events:
                            for action in mapper.feed(event):
                                output = adapter.output_for(action)
                                if output == "bridge:return_to_hearth":
                                    self._terminate_child()
                                    return_requested = True
                                    break
                                if output is not None:
                                    sink.emit(output)
                            if return_requested:
                                break
                    except Exception as error:
                        print(
                            f"hearth-input-bridge: controller translation stopped; application remains open: {error}",
                            file=sys.stderr,
                        )
                        try:
                            sink.close()
                        except Exception:
                            pass
                        try:
                            source.close()
                        except Exception:
                            pass
                        sink = None
                        source = None
            finally:
                restore_handlers()
            if self._stop_signal is not None:
                self._terminate_child(self._stop_signal)
            return int(self._child.wait())
        except BaseException:
            self._terminate_child()
            raise
        finally:
            try:
                if sink is not None:
                    sink.close()
            finally:
                if source is not None:
                    source.close()

    def _run_native(self) -> int:
        self._child = self._start_child()
        return int(self._child.wait())

    def _start_child(self) -> Any:
        kwargs: dict[str, Any] = {}
        if os.name == "posix":
            kwargs["start_new_session"] = True
        return self._popen(self._command, **kwargs)

    def _install_signal_handlers(self) -> Callable[[], None]:
        previous: dict[int, Any] = {}

        def remember(signum: int, _frame: Any) -> None:
            self._stop_signal = signum

        for signum in (signal.SIGINT, signal.SIGTERM):
            previous[signum] = signal.getsignal(signum)
            signal.signal(signum, remember)

        def restore() -> None:
            for signum, handler in previous.items():
                signal.signal(signum, handler)

        return restore

    def _terminate_child(self, signum: int = signal.SIGTERM) -> None:
        if self._child is None or self._child.poll() is not None:
            return
        self._signal_process(self._child, signum)
        try:
            self._child.wait(timeout=self._graceful_timeout)
        except subprocess.TimeoutExpired:
            self._signal_process(self._child, FORCE_KILL_SIGNAL)
            self._child.wait(timeout=3.0)
