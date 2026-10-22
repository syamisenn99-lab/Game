class_name UiKit
extends RefCounted
## UI 部品を作る小さな道具箱（色・枠・ラベル・モーダル）。

const INK := Color("3b2a1a")
const INK_SOFT := Color("6b5640")
const CREAM := Color("f3e7cf")
const CREAM_SOFT := Color("cdbb9a")
const PAPER := Color("efe3c4")
const PARCHMENT := Color("f4ead2")
const WOOD := Color("7a5230")
const WOOD_DARK := Color("4a3018")
const BAR := Color("33261b")
const STAMP_RED := Color("b3261e")
const GOOD := Color("2f7d32")
const WARN := Color("c77700")
const BAD := Color("b3261e")
const INFO := Color("2a5d9f")

## 結果ID → 色
const OUTCOME_COLORS := {
	"great_success": Color("1f7a8c"),
	"success": Color("2f7d32"),
	"narrow_success": Color("8a8a1a"),
	"failure": Color("c77700"),
	"great_failure": Color("b3261e"),
}


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 4, padding: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	return s


static func label(text: String, size: int = 16, color: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", box(Color("6b4a2b"), WOOD_DARK, 2, 6, 8))
	b.add_theme_stylebox_override("hover", box(Color("85603a"), WOOD_DARK, 2, 6, 8))
	b.add_theme_stylebox_override("pressed", box(Color("4f3520"), Color("e0b84f"), 2, 6, 8))
	b.add_theme_stylebox_override("hover_pressed", box(Color("5c3f26"), Color("e0b84f"), 2, 6, 8))
	b.add_theme_stylebox_override("disabled", box(Color("9a8f80"), Color("7d7266"), 2, 6, 8))
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("ffe29a"))
	b.add_theme_color_override("font_hover_pressed_color", Color("ffe29a"))
	b.add_theme_color_override("font_disabled_color", Color("d9d2c5"))
	return b


static func outcome_color(outcome_id: String) -> Color:
	return OUTCOME_COLORS.get(outcome_id, INK)


static func rate_color(rate: float) -> Color:
	if rate >= 0.8:
		return GOOD
	if rate >= 0.5:
		return WARN
	return BAD


static func percent(rate: float) -> String:
	return "%.1f%%" % (rate * 100.0)


static func signed(value: int) -> String:
	return "%+d" % value


static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## 自分を全画面の暗幕にして、中央に枠を置く。中身を入れる VBoxContainer を返す
static func make_modal(owner: Control, size: Vector2) -> VBoxContainer:
	owner.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", box(PARCHMENT, WOOD_DARK, 4, 8, 18))
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	return body
