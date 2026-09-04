# ShiftGrid 0.1.1

ShiftGrid is a native macOS menu-bar utility for moving the window under the
pointer into one or two vertical screen zones.

## Download

- **Recommended:** `ShiftGrid-0.1.1-macOS-universal.dmg`
- **Alternative:** `ShiftGrid-0.1.1-macOS-universal.zip`
- `SHA256SUMS.txt` contains the SHA-256 checksums for both downloads.

Do not download the automatically generated `Source code` archives: they do
not contain the ready-to-run application.

## Install from the DMG

1. Open the downloaded DMG.
2. Drag `ShiftGrid.app` onto the **Applications** shortcut in the installer
   window.
3. Wait for the copy to finish, eject the ShiftGrid disk image, and launch
   ShiftGrid from the Applications folder.
4. If macOS blocks the first launch, open **System Settings → Privacy &
   Security**, find the ShiftGrid message and click **Open Anyway**. Launch the
   app again.
5. Open ShiftGrid from its three-column menu-bar icon and enable it in **System
   Settings → Privacy & Security → Accessibility**.

If the DMG cannot be opened, download the ZIP instead, unzip it, and move
`ShiftGrid.app` to the Applications folder before launching it.

## Included

- Automatic two- or three-column layouts.
- Hold-and-release left Shift workflow.
- Two-zone L gesture in both directions.
- Optional double-Shift and click workflow.
- Configurable spacing with a 2-pixel default.
- Correct handling of the menu bar, visible and auto-hidden Dock, and multiple
  displays.
- Universal 2 support for Apple Silicon and Intel Macs.
- A convenient drag-and-drop DMG, with the ZIP retained as a fallback.
- Local-only operation with no analytics or network requests.

This build is ad-hoc signed and is not Apple-notarized because a Developer ID
certificate is not configured yet. The DMG makes copying the app easier, but
does not remove the Gatekeeper warning described above. An update may also
require Accessibility permission to be enabled again.

## Known limitations

- Full-screen, fixed-size and some system windows cannot be resized.
- There is no launch-at-login option or auto-updater yet.
- The interface is currently Russian.
