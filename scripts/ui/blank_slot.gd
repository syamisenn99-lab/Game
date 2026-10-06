class_name BlankSlot
extends PanelContainer
## ノートの虫食い穴。キーワードをドロップして確定する。

signal keyword_dropped(keyword_id: StringName, target_id: StringName)
signal target_clicked(target_id: StringName)

var blank_id: StringName
var fill_text := ""
var filled := false
var _label: Label


func setup(id: StringName, fill: String, is_filled: bool) -> void:
	blank_id = id
	fill_text = fill
	custom_minimum_size = Vector2(96, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	set_filled(is_filled)


func set_filled(value: bool) -> void:
	filled = value
	if filled:
		_label.text = fill_text
		_label.add_theme_color_override("font_color", Palette.HILITE_LINE)
	else:
		_label.text = "？？？"
		_label.add_theme_color_override("font_color", Palette.INK_FAINT)
	_apply_style(false)


func _apply_style(hint: bool) -> void:
	var border := Palette.DROP_HINT if hint else Palette.INK_FAINT
	var bg := Palette.PAPER if filled else Color(0.85, 0.8, 0.68)
	var sb := Palette.box(bg, border, 2 if (hint or not filled) else 0, 4, 2.0)
	add_theme_stylebox_override("panel", sb)


func pop() -> void:
	Effects.pop(self)


func flash(color: Color) -> void:
	modulate = color
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and not filled:
		_apply_style(true)
	elif what == NOTIFICATION_DRAG_END:
		_apply_style(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not filled and data is Dictionary and data.get("type", "") == "keyword"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	keyword_dropped.emit(StringName(data["id"]), blank_id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			target_clicked.emit(blank_id)
