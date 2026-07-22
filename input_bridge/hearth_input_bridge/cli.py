from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import TextIO

from .config import BridgeConfig, ConfigError
from .evdev_source import EvdevSource, EvdevUnavailable
from .mapper import AdapterMapper, SemanticMapper
from .process_runner import SessionRunner
from .uinput_sink import UInputSink, UInputUnavailable


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Hearth Fedora controller bridge")
    subparsers = parser.add_subparsers(dest="command", required=True)
    replay = subparsers.add_parser("replay", help="translate canonical JSON events without accessing input devices")
    replay.add_argument("--config-dir", type=Path, required=True)
    replay.add_argument("--profile", required=True)
    replay.add_argument("--destination", required=True)
    replay.add_argument("--input", type=Path, help="newline-delimited JSON; stdin when omitted")
    probe = subparsers.add_parser("probe", help="report controller and uinput readiness without launching an app")
    probe.add_argument("--no-uinput", action="store_true", help="skip the virtual-keyboard permission check")
    run = subparsers.add_parser("run", help="supervise one translated application session")
    run.add_argument("--config-dir", type=Path, required=True)
    run.add_argument("--profile", default="ps5")
    run.add_argument("--destination", required=True)
    run.add_argument("--no-grab", action="store_true", help="do not exclusively grab the controller")
    run.add_argument("application", nargs=argparse.REMAINDER)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "probe":
            return _probe(skip_uinput=args.no_uinput)
        if args.command == "run":
            application = list(args.application)
            if application and application[0] == "--":
                application.pop(0)
            config = BridgeConfig.load(args.config_dir, fallback_invalid_user=True)
            for warning in config.warnings:
                print(f"hearth-input-bridge: {warning}", file=sys.stderr)
            runner = SessionRunner(
                config,
                args.profile,
                args.destination,
                application,
                grab=not args.no_grab,
            )
            return runner.run()
        config = BridgeConfig.load(args.config_dir)
        adapter_id = config.adapter_for_destination(args.destination)
        semantic_mapper = SemanticMapper(config.profile(args.profile))
        adapter_mapper = AdapterMapper(config.adapters, adapter_id, args.destination)
        source: TextIO
        if args.input:
            source = args.input.open("r", encoding="utf-8")
        else:
            source = sys.stdin
        try:
            for line_number, line in enumerate(source, start=1):
                if not line.strip():
                    continue
                event = json.loads(line)
                for action in semantic_mapper.feed(event):
                    print(json.dumps({"action": action, "output": adapter_mapper.output_for(action)}, sort_keys=True))
        finally:
            if args.input:
                source.close()
    except (ConfigError, EvdevUnavailable, UInputUnavailable, OSError, json.JSONDecodeError, ValueError) as error:
        print(f"hearth-input-bridge: {error}", file=sys.stderr)
        return 2
    return 0


def _probe(*, skip_uinput: bool) -> int:
    errors: list[str] = []
    controllers = EvdevSource.probe(errors=errors)
    for error in errors:
        print(f"hearth-input-bridge: {error}", file=sys.stderr)
    if controllers:
        for controller in controllers:
            print(
                f"controller: {controller.path} {controller.name} "
                f"{controller.vendor_id:04x}:{controller.product_id:04x}"
            )
    else:
        print("controller: none detected")
    if not skip_uinput:
        sink = UInputSink()
        sink.close()
        print("uinput: ready")
    return 0 if controllers else 1


if __name__ == "__main__":
    raise SystemExit(main())
