extends Control
## 汎用のお知らせ（給料日・新しい依頼など）。

signal closed

var _title: Label
var _text: Label
var ok_button: Button


func _ready() -> void:
	visible = false
	var body := UiKit.make_modal(self, Vector2(560, 260))
	_title = UiKit.label("", 24)
	body.add_child(_title)
	body.add_child(HSeparator.new())
	_text = UiKit.label("", 17, UiKit.INK, true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_text)
	ok_button = UiKit.button("OK", 18)
	ok_button.custom_minimum_size = Vector2(160, 46)
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_button.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	body.add_child(ok_button)


func open(title: String, text: String) -> void:
	_title.text = title
	_text.text = text
	visible = true
