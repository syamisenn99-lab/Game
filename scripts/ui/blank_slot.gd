class_name BlankSlot
extends PanelContainer
## ノートの虫食い穴。キーワードをドロップして確定する。
## ドラッグ中は枠がうっすら脈打ち、その上に乗せると強く光る（項目そのものとは別の選択肢だと分かるように）。

signal keyword_dropped(keyword_id: StringName, target_id: StringName)
signal target_clicked(target_id: StringName)

enum Hint { NONE, DRAGGING, HOVER }

const SLOT_SIZE := Vector2(150, 52)

var blank_id: StringName
var fill_text := ""
var filled := false
var hint := Hint.NONE
var _label: Label
var _pulse: Tween


func setup(id: StringName, fill: String, is_filled: bool) -> void:
	blank_id = id
	fill_text = fill
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	add_child(_label)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_filled(is_filled)


func set_filled(value: bool) -> void:
	filled = value
	_refresh()


## ドラッグ中だけ、マウスの出入りで光り方を切り替える
func _on_mouse_entered() -> void:
	if not filled and get_viewport().gui_is_dragging():
		_set_hint(Hint.HOVER)


func _on_mouse_exited() -> void:
	if not filled and get_viewport().gui_is_dragging():
		_set_hint(Hint.DRAGGING)


func _set_hint(value: Hint) -> void:
	if value == hint:
		return
	hint = value
	_refresh()


func _refresh() -> void:
	if filled:
		_label.text = fill_text
		_label.add_theme_font_size_override("font_size", 28)
		_label.add_theme_color_override("font_color", Palette.HILITE_LINE)
	elif hint == Hint.HOVER:
		_label.text = "ここ！"
		_label.add_theme_font_size_override("font_size", 28)
		_label.add_theme_color_override("font_color", Palette.INK)
	else:
		_label.text = "？？？"
		_label.add_theme_font_size_override("font_size", 26)
		_label.add_theme_color_override("font_color", Palette.INK_FAINT)
	add_theme_stylebox_override("panel", _make_style())


func _make_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat
	if filled:
		sb = Palette.box(Palette.PAPER, Color.TRANSPARENT, 0, 6, 4.0)
	elif hint == Hint.HOVER:
		# 強く光る: 明るい黄色の地＋太い青枠＋外側へにじむ光
		sb = Palette.box(Color("fff3b0"), Palette.DROP_HINT, 4, 8, 4.0)
		sb.shadow_color = Color(1.0, 0.85, 0.2, 0.9)
		sb.shadow_size = 16
		sb.set_expand_margin_all(5.0)
	elif hint == Hint.DRAGGING:
		# 「ここに入れられるよ」と知らせる、青い枠
		sb = Palette.box(Color(0.82, 0.88, 0.97), Palette.DROP_HINT, 3, 8, 4.0)
		sb.shadow_color = Color(0.18, 0.43, 0.71, 0.45)
		sb.shadow_size = 8
	else:
		sb = Palette.box(Color(0.85, 0.8, 0.68), Palette.INK_FAINT, 2, 8, 4.0)
	return sb


func _start_pulse() -> void:
	_stop_pulse()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate", Color(1.12, 1.12, 1.12), 0.45)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.45)


func _stop_pulse() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	modulate = Color.WHITE


func pop() -> void:
	Effects.pop(self)


func flash(color: Color) -> void:
	modulate = color
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and not filled:
		_set_hint(Hint.DRAGGING)
		_start_pulse()
	elif what == NOTIFICATION_DRAG_END:
		_stop_pulse()
		_set_hint(Hint.NONE)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not filled and data is Dictionary and data.get("type", "") == "keyword"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	keyword_dropped.emit(StringName(data["id"]), blank_id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			target_clicked.emit(blank_id)
