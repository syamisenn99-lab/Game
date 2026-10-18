class_name UIKit
extends RefCounted
## 画面づくりの共通部品（色、ラベル、ボタンの見た目）。

const ATTACK_COLOR := Color(0.75, 0.3, 0.28)
const SKILL_COLOR := Color(0.3, 0.5, 0.75)
const BG_COLOR := Color(0.13, 0.13, 0.17)


static func label(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


static func box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	return s


static func color_button(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", box(color))
	btn.add_theme_stylebox_override("hover", box(color.lightened(0.2)))
	btn.add_theme_stylebox_override("pressed", box(color.darkened(0.2)))
	btn.add_theme_stylebox_override("disabled", box(color.darkened(0.55)))


static func card_color(data: CardData) -> Color:
	return ATTACK_COLOR if data.card_type == CardData.CardType.ATTACK else SKILL_COLOR


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)


static func button(text: String, on_press: Callable, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b
