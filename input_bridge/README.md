# Hearth Fedora input bridge

This package provides Hearth's non-privileged, per-application Fedora controller bridge. It:

- validates the same saved profiles used by the Godot launcher;
- converts canonical physical events into Hearth semantic actions;
- applies destination policy and semantic output adapters;
- discovers and exclusively grabs joystick-capable evdev nodes for translated destinations;
- emits allowlisted virtual-keyboard taps through `/dev/uinput`;
- supervises Chrome or Plex and releases every input resource when the application exits;
- supports deterministic newline-delimited JSON replay for development and tests.

Steam and RetroArch remain native destinations and never open the bridge's evdev or uinput backends. The runtime never runs as root. Fedora requires `python3-evdev` plus the repository's one-time active-user uinput rule; see the root README for deployment steps.

From the repository root:

```bash
python3 -m unittest discover -s input_bridge/tests
PYTHONPATH=input_bridge python3 -m hearth_input_bridge probe --no-uinput
printf '%s\n' '{"control":"gamepad_button:south","pressed":true}' | \
  PYTHONPATH=input_bridge python3 -m hearth_input_bridge replay \
    --config-dir launcher/config --profile ps5 --destination netflix
```

The launch helpers call the live runtime in this form:

```bash
PYTHONPATH=/opt/hearth/input_bridge python3 -m hearth_input_bridge run \
  --config-dir /opt/hearth/launcher/config \
  --profile ps5 --destination netflix -- /usr/bin/google-chrome-stable ...
```

The final USB and Bluetooth DualSense paths, reconnect behavior, and streaming-site navigation must still be exercised on the target Fedora PC before calling the feature production-validated.
