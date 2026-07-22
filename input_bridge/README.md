# Hearth input bridge foundation

This package is the non-privileged, backend-neutral core of Hearth's planned Fedora input bridge. It currently:

- validates the same saved profiles used by the Godot launcher;
- converts canonical physical events into Hearth semantic actions;
- applies destination policy and semantic output adapters;
- supports deterministic newline-delimited JSON replay for development and tests.

It intentionally does **not** open `/dev/input/event*`, grab a controller, create a `uinput` device, run as root, or alter application launchers yet. Those pieces require the actual Fedora controller and remote so device capabilities, logind ACLs, disconnect recovery, and duplicate-input prevention can be verified safely.

From the repository root:

```bash
python3 -m unittest discover -s input_bridge/tests
printf '%s\n' '{"control":"gamepad_button:south","pressed":true}' | \
  python3 -m input_bridge.hearth_input_bridge replay \
    --config-dir launcher/config --profile ps5 --destination netflix
```
