class_name KeywordChip
extends PanelContainer
## 通信ログ中のハイライト語。ドラッグしてノートへ運ぶ。クリック→クリックの代替操作にも対応。

signal chip_clicked(chip: KeywordChip)

var keyword_id: StringName
var display_text := ""
## 文字送りで表示されるまでは掴めない
var enabled := false
## チュートリアルで「この言葉を運んで」と示すとき
var guided := false
var _guide_tween: Tween
var selected := false:
	set(value):
		selected = value
		_apply_style()


func setup(id: StringName, text: String) -> void:
	keyword_id = id
	display_text = text
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Palette.INK)
	add_child(label)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()


func set_guide(value: bool) -> void:
	guided = value
	pivot_offset = size / 2.0
	if _guide_tween != null:
		_guide_tween.kill()
		_guide_tween = null
	if guided:
		_guide_tween = create_tween().set_loops()
		_guide_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.45).set_trans(Tween.TRANS_SINE)
		_guide_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		scale = Vector2.ONE
	_apply_style()


func set_enabled(value: bool) -> void:
	enabled = value
	mouse_default_cursor_shape = Control.CURSOR_DRAG if enabled else Control.CURSOR_ARROW
	_apply_style()


func _apply_style() -> void:
	# 色だけに頼らず、背景＋下線（太い下枠）で示す
	var sb := Palette.box(Palette.HILITE_BG if enabled else Palette.PAPER_DIM, Palette.HILITE_LINE, 0, 4, 4.0)
	sb.border_width_bottom = 4
	if guided:
		sb.set_border_width_all(3)
		sb.border_color = Color("e0a800")
		sb.border_width_bottom = 5
		sb.shadow_color = Color(1.0, 0.85, 0.2, 0.9)
		sb.shadow_size = 10
	if selected:
		sb.set_border_width_all(3)
		sb.border_color = Palette.DROP_HINT
		sb.border_width_bottom = 4
	add_theme_stylebox_override("panel", sb)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not enabled:
		return null
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", Palette.box(Palette.HILITE_BG, Palette.HILITE_LINE, 2, 6, 8.0))
	var label := Label.new()
	label.text = display_text
	label.add_theme_color_override("font_color", Palette.INK)
	preview.add_child(label)
	preview.rotation = deg_to_rad(-3.0)
	set_drag_preview(preview)
	Sfx.play(&"grab")
	return {"type": "keyword", "id": keyword_id, "text": display_text}


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# ドラッグではなく、その場でのクリックのときだけ「選択」とみなす
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			chip_clicked.emit(self)
