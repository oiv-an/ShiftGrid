# Changelog

All notable changes to ShiftGrid are documented here.

## [0.1.1] - 2026-09-04

### Added

- A drag-and-drop DMG with `ShiftGrid.app` and an Applications shortcut.
- SHA-256 checksums for both the recommended DMG and the fallback ZIP archive.

### Changed

- Release automation now builds and verifies both distribution formats before
  publishing them together.
- Publishing refuses to replace the assets of an existing GitHub Release.

## [0.1.0] - 2026-09-04

### Added

- Two- and three-column window layouts with an automatic 3000-pixel threshold.
- Window selection under the pointer.
- Left Shift hold-and-release gesture and optional click confirmation.
- L-shaped gesture for joining two adjacent zones in either direction.
- Configurable 0–30 physical pixel spacing with a 2-pixel default.
- Correct visible Dock, auto-hidden Dock, menu bar and multi-display geometry.
- Menu-bar settings and Accessibility status.
- Universal 2 release packaging for Apple Silicon and Intel Macs.

### Fixed

- Overlay positioning on displays with non-zero and negative origins.
- Repeated Accessibility prompts caused by unstable local signing.
- Right-to-left two-zone resizing being clamped to a single zone.
