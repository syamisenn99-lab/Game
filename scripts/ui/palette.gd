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
