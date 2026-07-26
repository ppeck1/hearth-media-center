# Honest alpha demonstration

Do not add a video file to the repository. Record locally at 1920×1080, use fictional library fixtures, and ensure browser account names, avatars, recommendations, notifications, network names, device serials, and credentials are not visible.

## Suggested flow

1. Start on the Hearth Home screen.
2. Show controller navigation and one recovery key.
3. Open **Games**.
4. Open **My Library** and browse the privacy-safe personal-library fixture.
5. Open a system or folder and show its `icon.*` and `wallpaper.*`.
6. Launch an authorized test game, then return to Hearth.
7. Open **Movies & TV**.
8. Launch one configured streaming destination.
9. Demonstrate directional navigation and page movement.
10. Return with Home or the Create+Options failsafe.
11. Open **Settings → System Health** and explain that hardware checks remain separate.
12. Return to Home and show **Power** without confirming a destructive action.

## Capture guidance

- Use the existing privacy-safe screenshot fixture for still images:

  ```bash
  godot --headless --path launcher --script res://tests/capture_readme_screenshots.gd
  ```

- For a video, use the desktop’s local capture tool or OBS with microphone and notification capture disabled.
- Keep the video short enough to show normal interaction rather than edited claims.
- State the exact commit, Fedora version, controller, and which physical matrix rows have actually passed.
- If a destination is not installed or validated, show its diagnostic status rather than simulating success.

Before publishing, watch the entire capture at normal speed and inspect every frame containing a browser, desktop shell, file picker, log, or System Health screen.
