from pathlib import Path

root = Path(defines["root"])
package = root / "dist" / "启动台安装包"

format = "UDZO"
filesystem = "HFS+"
files = [
    str(package / "启动台.app"),
    str(package / "安装说明.txt"),
    str(package / "清理旧版残留.command"),
]
symlinks = {"Applications": "/Applications"}
icon = str(root / ".build" / "AppIcon.icns")
background = str(root / ".build" / "dmg-background.tiff")
window_rect = ((160, 160), (720, 750))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
grid_spacing = 90
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 80
# Keep FinderInfo attributes off the signed app bundle. Finder normally hides
# .app extensions itself; changing them with SetFile breaks strict verification.
hide_extensions = ["安装说明.txt", "清理旧版残留.command"]
icon_locations = {
    "启动台.app": (180, 190),
    "Applications": (540, 190),
    "安装说明.txt": (240, 667),
    "清理旧版残留.command": (480, 667),
}
