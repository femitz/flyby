# dmgbuild settings for the Flyby installer window (see scripts/make-dmg.sh).
# Window content is 660x400, matching the background art; the frame is 28pt taller to
# account for the title bar. Icon centers are measured in the content area.

import os

app = defines["app"]            # path to Flyby.app
background = defines["background"]  # path to background.png (background@2x.png is picked up automatically)
volume_icon = defines.get("volume_icon")

app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}

if volume_icon:
    icon = volume_icon

window_rect = ((200, 120), (660, 428))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
label_pos = "bottom"
arrange_by = None

icon_locations = {
    app_name: (165, 200),
    "Applications": (495, 200),
}
