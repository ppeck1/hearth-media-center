# Changelog

All notable changes are recorded here. Hearth follows semantic-version-shaped prerelease labels while the appliance remains experimental.

## [Unreleased]

- Physical Fedora appliance validation remains pending.
- A distributable software license remains a maintainer decision.

## [0.1.0-alpha] — draft

### Added

- GitHub Actions verification for portable JSON, configuration, artwork, privacy, shell, Python, Godot, documentation, and repository checks.
- Fedora `install.sh`, `update.sh`, `uninstall.sh`, and privacy-bounded `doctor.sh` lifecycle tools.
- A controller-accessible System Health screen backed by a fixed diagnostic helper.
- Repeatable hardware-validation, architecture, troubleshooting, demonstration, contributing, and release documentation.
- A visible Refresh Library action in the filesystem library drawer.
- Smart, full-image, and fill-tile artwork fitting for mixed-aspect game libraries.

### Existing alpha foundation

- Controller-first Godot home screen, filesystem ROM discovery, hierarchical and flat browsing, folder artwork and wallpaper conventions, RetroArch and native launch boundaries, Steam Big Picture, Plex HTPC, streaming destinations, local settings, and the bounded input bridge.

### Security and privacy

- No telemetry or cloud library service was introduced.
- ROMs, BIOS files, saves, credentials, media, and browser profiles remain outside the repository.
- The input bridge remains unprivileged and emits only allowlisted virtual keys.

[Unreleased]: https://github.com/ppeck1/hearth-media-center/compare/v0.1.0-alpha...HEAD
[0.1.0-alpha]: https://github.com/ppeck1/hearth-media-center/releases/tag/v0.1.0-alpha
