from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import TextIO

from .config import BridgeConfig, ConfigError
from .mapper import AdapterMapper, SemanticMapper


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Hearth input bridge dry-run tools")
    subparsers = parser.add_subparsers(dest="command", required=True)
    replay = subparsers.add_parser("replay", help="translate canonical JSON events without accessing input devices")
    replay.add_argument("--config-dir", type=Path, required=True)
    replay.add_argument("--profile", required=True)
    replay.add_argument("--destination", required=True)
    replay.add_argument("--input", type=Path, help="newline-delimited JSON; stdin when omitted")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
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
    except (ConfigError, OSError, json.JSONDecodeError, ValueError) as error:
        print(f"hearth-input-bridge: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
