# Contributing to Hearth

Hearth is preparing for an alpha release. Contributions should improve installation, reliability, diagnostics, recovery, compatibility, tests, or accurate documentation without weakening its appliance boundaries.

## Before changing code

1. Read the [architecture and trust boundaries](docs/architecture.md).
2. Create a branch; do not work directly on `main`.
3. Keep fixtures fictional. Never add ROMs, BIOS files, saves, credentials, browser profiles, private media, device serials, or personal inventories.
4. Do not add arbitrary commands to JSON or make the Godot UI a shell interface.
5. Preserve the filesystem library and the existing launcher/input policy boundaries.

## Verify a change

Install Godot 4.6.3 or set `HEARTH_GODOT` to an executable Godot 4 runtime, then run:

```bash
HEARTH_GODOT=/path/to/godot ./verify/verify-project.sh --ci
```

The verifier runs Python unit tests, Godot headless import and smoke tests, JSON/reference checks, shell syntax, optional ShellCheck, documentation links, executable modes, privacy scanning, and a clean-tree check. Run the Fedora lifecycle tests directly when working on deployment:

```bash
python3 -m unittest discover -s deploy/fedora/tests -v
```

Hardware claims require the exact [physical validation matrix](docs/hardware-validation.md). Include evidence and leave unrun rows marked `NOT RUN`.

## Pull requests

Keep commits small and intentional. In the pull request, distinguish:

- behavior implemented;
- automation run and its result;
- manual checks actually performed;
- physical checks still pending;
- security or privacy boundaries affected;
- rollback considerations.

The project currently has no redistribution license. Contributions should not be submitted under an assumed license; see [LICENSE](LICENSE).
