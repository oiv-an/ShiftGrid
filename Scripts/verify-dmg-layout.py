#!/usr/bin/env python3

import math
import sys
from pathlib import Path

from ds_store import DSStore


def fail(message: str) -> None:
    raise SystemExit(f"Invalid DMG Finder layout: {message}")


if len(sys.argv) != 2:
    fail("expected the path to .DS_Store")

store_path = Path(sys.argv[1])
if not store_path.is_file():
    fail(f"missing {store_path}")

entries = {}
with DSStore.open(str(store_path), "r") as store:
    for entry in store:
        entries[(entry.filename, entry.code)] = entry.value

expected_locations = {
    "ShiftGrid.app": (170, 180),
    "Applications": (490, 180),
}
for filename, expected_location in expected_locations.items():
    actual_location = entries.get((filename, b"Iloc"))
    if actual_location != expected_location:
        fail(
            f"{filename} is at {actual_location!r}, expected {expected_location!r}"
        )

browser_settings = entries.get((".", b"bwsp"))
if not isinstance(browser_settings, dict):
    fail("missing Finder window settings")
if browser_settings.get("WindowBounds") != "{{200, 200}, {660, 400}}":
    fail(f"unexpected window bounds: {browser_settings.get('WindowBounds')!r}")
for hidden_control in ("ShowStatusBar", "ShowToolbar", "ShowSidebar"):
    if browser_settings.get(hidden_control) is not False:
        fail(f"{hidden_control} must be disabled")

icon_settings = entries.get((".", b"icvp"))
if not isinstance(icon_settings, dict):
    fail("missing Finder icon-view settings")
if icon_settings.get("backgroundType") != 1:
    fail("the installer must use a scale-independent color background")
if icon_settings.get("iconSize") != 112.0:
    fail(f"unexpected icon size: {icon_settings.get('iconSize')!r}")
if icon_settings.get("arrangeBy") != "none":
    fail("Finder must preserve the configured icon positions")

expected_color = {
    "backgroundColorRed": 0xF3 / 255,
    "backgroundColorGreen": 0xF6 / 255,
    "backgroundColorBlue": 0xFC / 255,
}
for component, expected_value in expected_color.items():
    actual_value = icon_settings.get(component)
    if not isinstance(actual_value, (float, int)) or not math.isclose(
        actual_value, expected_value, abs_tol=1e-9
    ):
        fail(f"unexpected {component}: {actual_value!r}")

print("Verified DMG Finder window and icon layout")
