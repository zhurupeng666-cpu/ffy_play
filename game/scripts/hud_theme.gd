# 城镇界面主题：统一面板、按钮、分类菜单和选项卡的配色与间距。
extends RefCounted


# 面板样式：用细边框和适度内边距区分操作区与地图。
static func surface(fill: String, stroke: String, padding: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill)
	box.border_color = Color(stroke)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box


# 控件主题：共用背景和交互态，让资源区、建造区和管理区的层次一致。
static func make() -> Theme:
	var hud := Theme.new()
	hud.default_font_size = 15
	hud.set_color("font_color", "Label", Color("#e8dfc9"))
	var window_frame := surface("#252e27", "#68735b")
	window_frame.expand_margin_top = 32
	hud.set_stylebox("embedded_border", "Window", window_frame)
	hud.set_color("title_color", "Window", Color("#ead7a0"))
	hud.set_stylebox("panel", "AcceptDialog", surface("#252e27", "#68735b"))
	hud.set_stylebox("panel", "ItemList", surface("#202820", "#414c3e", 5))
	hud.set_stylebox("selected", "ItemList", surface("#493f2c", "#7f6c45", 2))
	hud.set_stylebox("selected_focus", "ItemList", surface("#665735", "#a18b58", 2))
	hud.set_stylebox("panel", "PanelContainer", surface("#252e27", "#495342"))
	hud.set_stylebox("panel", "TabContainer", surface("#202820", "#414c3e"))
	hud.set_stylebox("tab_selected", "TabContainer", surface("#665735", "#a18b58", 6))
	hud.set_stylebox("tab_unselected", "TabContainer", surface("#303b31", "#495342", 6))
	hud.set_stylebox("tab_hovered", "TabContainer", surface("#414e3b", "#7e8c65", 6))
	hud.set_stylebox("panel", "PopupMenu", surface("#252e27", "#68735b", 5))
	hud.set_stylebox("hover", "PopupMenu", surface("#414e3b", "#7e8c65", 5))
	hud.set_color("font_color", "PopupMenu", Color("#e8dfc9"))
	hud.set_stylebox("background", "ProgressBar", surface("#181e19", "#495342", 2))
	hud.set_stylebox("fill", "ProgressBar", surface("#a89458", "#a89458", 1))
	for control_type: String in ["Button", "MenuButton", "OptionButton"]:
		hud.set_stylebox("normal", control_type, surface("#303b31", "#52604a", 6))
		hud.set_stylebox("hover", control_type, surface("#414e3b", "#7e8c65", 6))
		hud.set_stylebox("pressed", control_type, surface("#665735", "#a18b58", 6))
		hud.set_stylebox("disabled", control_type, surface("#252b25", "#3e473c", 6))
		hud.set_color("font_color", control_type, Color("#e8dfc9"))
	return hud
