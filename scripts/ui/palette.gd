class_name Palette
extends RefCounted

const DESK := Color("3b2a1e")
const DESK_TEXT := Color("f3e9d6")
const PAPER := Color("f2e8d0")
const PAPER_DIM := Color("e4d8bb")
const INK := Color("2b2118")
const INK_FAINT := Color("7a6a55")
const HILITE_BG := Color("ffe27a")
const HILITE_LINE := Color("c0392b")
const OK := Color("3c8d5a")
const NG := Color("c0392b")
const DROP_HINT := Color("2f6fb5")


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0,
		radius: int = 6, margin: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## 机の上の道具らしい配色のテーマ（コントラストを確保する）
static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	th.set_color("font_color", "Label", Palette.INK)
	# 机の上の道具らしい配色（コントラストを確保する）
	th.set_stylebox("normal", "Button", Palette.box(Palette.INK, Palette.INK, 0, 6, 8.0))
	th.set_stylebox("hover", "Button", Palette.box(Color("4a3a2c"), Palette.HILITE_BG, 2, 6, 8.0))
	th.set_stylebox("pressed", "Button", Palette.box(Color("1c150f"), Palette.HILITE_BG, 2, 6, 8.0))
	th.set_stylebox("disabled", "Button", Palette.box(Palette.PAPER_DIM, Palette.INK_FAINT, 1, 6, 8.0))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(key, "Button", Palette.DESK_TEXT)
	th.set_color("font_disabled_color", "Button", Palette.INK_FAINT)
	th.set_stylebox("background", "ProgressBar", Palette.box(Color("24190f"), Color.TRANSPARENT, 0, 6, 0.0))
	th.set_stylebox("fill", "ProgressBar", Palette.box(Palette.HILITE_BG, Color.TRANSPARENT, 0, 6, 0.0))
	return th
