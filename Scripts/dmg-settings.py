application = defines["app"]  # noqa: F821
volume_icon = defines["icon"]  # noqa: F821

background = "#f3f6fc"

format = "UDZO"
filesystem = "HFS+"
compression_level = 9

files = [(application, "ShiftGrid.app")]
symlinks = {"Applications": "/Applications"}

icon = volume_icon
icon_locations = {
    "ShiftGrid.app": (170, 180),
    "Applications": (490, 180),
}

window_rect = ((200, 200), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = True
include_icon_view_settings = True

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 90
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 14
icon_size = 112
