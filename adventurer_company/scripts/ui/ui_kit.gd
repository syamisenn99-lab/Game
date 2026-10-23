class_name UiKit
extends RefCounted
## UI 部品を作る小さな道具箱（色・文字の大きさ・枠・ラベル・札・モーダル）。

## 文字の大きさの段階。画面の文字はこの段階から選ぶ（13 未満は使わない）
const SIZE_TITLE := 24
const SIZE_HEADING := 19
const SIZE_BODY := 16
const SIZE_SMALL := 14
const SIZE_TINY := 13

const INK := Color("33241a")
## 補足の文字。羊皮紙の上でも読めるよう、薄くしすぎない
const INK_SOFT := Color("5a4632")
const CREAM := Color("f6ecd6")
const CREAM_SOFT := Color("e0cfaa")
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
## 報酬・所持金の色
const GOLD := Color("8a5a00")
const GOLD_BRIGHT := Color("ffd76a")

## 職業ID → 札の色
const JOB_COLORS := {
	"warrior": Color("8c3b2e"),
	"scout": Color("3f6b3a"),
	"mage": Color("3b4f8c"),
}

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


static var _bold_font: FontVariation


## 太字（テーマの日本語フォントを太らせたもの）
static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		var theme: Theme = load("res://ui/theme.tres")
		_bold_font.base_font = theme.default_font
		_bold_font.variation_embolden = 0.7
	return _bold_font


static func label(text: String, size: int = SIZE_BODY, color: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 太字のラベル（名前・見出し・大事な数字）
static func bold(text: String, size: int = SIZE_BODY, color: Color = INK, wrap: bool = false) -> Label:
	var l := label(text, size, color, wrap)
	l.add_theme_font_override("font", bold_font())
	return l


## 色つきの札（職業・状態・結果など）
static func chip(text: String, bg: Color, fg: Color = Color.WHITE, size: int = SIZE_SMALL) -> Label:
	var l := label(text, size, fg)
	l.add_theme_font_override("font", bold_font())
	var s := box(bg, bg.darkened(0.25), 1, 10, 2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	l.add_theme_stylebox_override("normal", s)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


static func job_chip(config: BalanceConfig, job_id: String, matched: bool = false, size: int = SIZE_SMALL) -> Label:
	return chip(config.job_name(job_id) + ("★" if matched else ""), JOB_COLORS.get(job_id, INK_SOFT), Color.WHITE, size)


## 見出し（区切り線つき）
static func heading(text: String, size: int = SIZE_SMALL) -> Label:
	var l := bold(text, size, WOOD)
	return l


## 「見出し：値」の2列の表を作る。rows は [見出し, 値, 色(省略可)] の配列
static func info_grid(rows: Array, key_size: int = SIZE_SMALL, value_size: int = SIZE_BODY) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for row: Array in rows:
		grid.add_child(label(str(row[0]), key_size, INK_SOFT))
		grid.add_child(bold(str(row[1]), value_size, row[2] if row.size() > 2 else INK))
	return grid


static func button(text: String, size: int = SIZE_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", bold_font())
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
