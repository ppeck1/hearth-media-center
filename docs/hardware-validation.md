# Fedora appliance hardware validation

This is the release-gate checklist for the dedicated living-room PC. It is not an automated test result. Every row starts as **NOT RUN** and must be completed on the target hardware by the maintainer. Do not infer a pass from CI, a developer workstation, or a diagnostic report.

## Record the test environment

Before testing, record:

- Hearth commit and version:
- Fedora version and kernel:
- GPU and driver:
- television or receiver model:
- connection path (direct HDMI or receiver):
- controller and firmware:
- session type:
- test date and tester:

Save screenshots, short videos, or redacted logs outside the repository unless they contain only fictional fixture data. Evidence names should not reveal account names, private media, ROM filenames, device serials, or credentials.

## Test matrix

| ID | Test | Preconditions | Procedure | Expected result | Pass/fail | Notes | Evidence | Automatable later? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HW-01 | Cold boot into Hearth | Installed service enabled; PC powered off | Apply power and wait without keyboard use | Fedora reaches Hearth fullscreen with no terminal or desktop interaction | NOT RUN |  |  | Partly: boot timing and service state |
| HW-02 | Launch at login | Media account configured; Hearth stopped | Log out, then log in as the media user | Hearth starts once in the graphical session | NOT RUN |  |  | Yes: service-state assertion |
| HW-03 | Wired controller detection | Supported controller disconnected | Connect by USB; open System Health; navigate Home | Controller is detected and one input moves one item | NOT RUN |  |  | Partly: evdev detection |
| HW-04 | Bluetooth controller detection | Controller paired but disconnected | Connect wirelessly; open System Health; navigate | Controller is detected without terminal access | NOT RUN |  |  | Partly |
| HW-05 | Controller reconnect after reboot | Paired wireless controller | Reboot, reconnect controller, navigate | Controller reconnects and controls Hearth once | NOT RUN |  |  | Hardware-dependent |
| HW-06 | Controller reconnect after sleep | Controller working before suspend | Suspend, wake, reconnect, navigate and launch a safe destination | Control returns without duplicate inputs or restarting Hearth | NOT RUN |  |  | Hardware-dependent |
| HW-07 | Keyboard or remote fallback | Controller disconnected | Use arrows, Enter, Escape, and Home throughout menus | All essential navigation and return actions remain reachable | NOT RUN |  |  | Yes with injected input |
| HW-08 | Steam Big Picture launch and exit | Steam installed and signed in locally | Games → Steam Big Picture; exit Steam | Steam opens in gamepad UI and Hearth regains focus | NOT RUN |  |  | Partly; sign-in and rendering manual |
| HW-09 | Plex HTPC launch and exit | Plex Flatpak installed and configured locally | Movies & TV → Plex; exit or use return chord | Plex opens fullscreen and returns to Hearth | NOT RUN |  |  | Partly |
| HW-10 | RetroArch launch and exit | Allowlisted core and legal personal test ROM present | Launch one ROM; exit RetroArch | Correct core opens the selected game and returns to Hearth | NOT RUN |  |  | Partly; content must remain private |
| HW-11 | Browser streaming launch and exit | Supported browser installed; test profile configured | Open one streaming destination; return with Home or Create+Options | Browser opens fullscreen; bridge exits and Hearth regains focus | NOT RUN |  |  | Partly |
| HW-12 | Netflix browsing | Netflix profile signed in locally | Move through several rows and tiles; enter/leave action mode; fast-page | Focus remains visible and predictable; no credential is exposed | NOT RUN |  |  | Fragile browser fixture possible |
| HW-13 | Netflix playback controls | Netflix test title available | Start playback; pause/resume; exit playback | Play/pause and Back behave predictably and return to browsing | NOT RUN |  |  | Mostly manual |
| HW-14 | Controller return to Hearth | Translated destination running | Press Home; repeat using Create+Options failsafe | Child exits, Hearth regains focus, controller controls Hearth | NOT RUN |  |  | Partly |
| HW-15 | Bridge cleanup after normal exit | Controller and translated destination active | Exit destination normally; inspect `doctor.sh` and event behavior | No bridge process or virtual keyboard remains; physical device is released | NOT RUN |  |  | Yes with process/device probes |
| HW-16 | Bridge cleanup after application crash | Safe test destination can be terminated externally | Launch it; terminate child process; return to Hearth | Bridge exits and releases evdev/uinput resources | NOT RUN |  |  | Yes |
| HW-17 | Controller release after bridge failure | Safe method to deny or unload uinput prepared | Launch translated destination; induce bridge output failure | Application remains usable by fallback; controller is released; no root bridge exists | NOT RUN |  |  | Yes in a VM, hardware confirmation needed |
| HW-18 | Wayland fullscreen behavior | Wayland session active | Visit Hearth, Steam, Plex, RetroArch, and browser | Each intended surface fills the display and returns without stranded overlays | NOT RUN |  |  | Mostly manual |
| HW-19 | 1920×1080 rendering | TV accepts 1080p | Set 1920×1080; inspect all screens and overlays | No clipping, overlap, unreadable text, or off-screen control | NOT RUN |  |  | Screenshot comparison possible |
| HW-20 | Overscan and television scaling | TV picture controls accessible | Test normal and known overscan modes | Fedora/TV scaling can show the full Hearth safe area | NOT RUN |  |  | Manual |
| HW-21 | Audio output | Receiver/TV selected; known legal test audio available | Play audio in RetroArch, Plex, and browser; change volume externally | Audio uses intended output without requiring terminal access | NOT RUN |  |  | Hardware-dependent |
| HW-22 | Missing dependency behavior | One optional destination temporarily unavailable | Run doctor; select affected destination | Doctor gives a bounded remediation; Hearth shows a useful error and remains navigable | NOT RUN |  |  | Yes in fixture environment |
| HW-23 | Empty ROM library | Empty readable ROM root | Open Games → My Library; refresh | Clear empty-library message; Steam and other Home actions remain usable | NOT RUN |  |  | Yes |
| HW-24 | Inaccessible ROM library | Safe test directory with denied media-user access | Open library and run doctor; restore permission afterward | No crash or inventory leak; doctor reports access failure and remediation | NOT RUN |  |  | Yes in fixture environment |
| HW-25 | Application hang recovery | Safe test app that ignores TERM | Launch it; use return chord; wait through escalation | Helper escalates, reaps the child, releases input, and returns to Hearth | NOT RUN |  |  | Yes; hardware controller path remains manual |
| HW-26 | Shutdown and restart | No unsaved work; power confirmation available | Test Cancel, then Restart; after boot test Shut Down | Cancel is harmless; confirmed actions perform exactly once | NOT RUN |  |  | Manual/destructive |
| HW-27 | Usability without terminal access | Fresh login; keyboard hidden | Complete the demonstration flow using controller/remote only | All core tasks, diagnostics, recovery, and power controls are reachable | NOT RUN |  |  | Manual |

## Failure handling

1. Mark the row **FAIL**; do not soften it to “partial pass.”
2. Record only privacy-safe symptoms and evidence.
3. Run `/opt/hearth/deploy/fedora/doctor.sh --json` and retain the report locally.
4. Collect the relevant user-service journal with the redaction procedure in [troubleshooting](troubleshooting.md).
5. File an issue with the exact commit and hardware context.
6. After a fix, rerun the failed row and any row sharing the same launcher, input, display, or service boundary.

## Sign-off

- Required rows passed:
- Failed rows and linked issues:
- Rows intentionally not applicable, with reason:
- Maintainer decision:
- Date:
