# ShiftGrid 0.1.0 — first public release

ShiftGrid is a native macOS menu-bar utility for moving the window under the
pointer into one or two vertical screen zones.

## Included

- Automatic two- or three-column layouts.
- Hold-and-release left Shift workflow.
- Two-zone L gesture in both directions.
- Optional double-Shift and click workflow.
- Configurable spacing with a 2-pixel default.
- Correct handling of the menu bar, visible and auto-hidden Dock, and multiple
  displays.
- Universal 2 support for Apple Silicon and Intel Macs.
- Local-only operation with no analytics or network requests.

## Installation

Download `ShiftGrid-0.1.0-macOS-universal.zip`, unzip it and move
`ShiftGrid.app` to `/Applications` before granting Accessibility permission.

This first public build is ad-hoc signed and not Apple-notarized. If macOS
blocks the first launch, use **System Settings → Privacy & Security → Open
Anyway**. Then enable ShiftGrid in **Accessibility**.

## Known limitations

- Full-screen, fixed-size and some system windows cannot be resized.
- There is no launch-at-login option or auto-updater yet.
- The interface is currently Russian.
