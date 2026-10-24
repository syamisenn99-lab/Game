class_name UiTheme
extends RefCounted
## 配色とテーマ。日本語は同梱の Noto Serif JP で出し、念のため OS の明朝・ゴシックにも頼れるようにする。

const FONT_PATH := "res://assets/fonts/NotoSerifJP-Regular.otf"

const BG := Color("1b130e")
const WOOD := Color("2a1d14")
const PAPER := Color("efe3c8")
const INK := Color("2b2118")
const INK_FAINT := Color("6f5f4a")
const ACCENT := Color("8f2a2a")
const GOLD := Color("d9b26a")
const LIGHT_TEXT := Color("f3e9d6")
const DIM_TEXT := Color("bfae8f")


static func make_font() -> Font:
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray([
		"Noto Serif CJK JP", "Noto Serif JP", "Yu Mincho", "Hiragino Mincho ProN", "MS Mincho",
		"Noto Sans CJK JP", "Hiragino Sans", "Yu Gothic", "Meiryo", "Droid Sans Fallback", "sans-serif",
	])
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	if font == null:
		return fallback
	font = font.duplicate()
	font.fallbacks = [fallback]
	return font


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, margin: float = 16.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(margin)
	return sb


static func make() -> Theme:
	var th := Theme.new()
	th.default_font = make_font()
	th.default_font_size = 26
	th.set_color("font_color", "Label", INK)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_stylebox("panel", "PanelContainer", box(PAPER, GOLD, 2, 20.0))
	th.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	return th
