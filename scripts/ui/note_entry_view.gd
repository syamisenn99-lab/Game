class_name NoteEntryView
extends PanelContainer
## ノートの1項目の表示。キーワードのドロップ先になる。虫食い穴は BlankSlot として埋め込む。

signal keyword_dropped(keyword_id: StringName, target_id: StringName)
signal target_clicked(target_id: StringName)

var entry: NoteEntry
var slots: Dictionary = {}
var _stamp: Label


func setup(p_entry: NoteEntry, filled_blanks: Dictionary) -> void:
	entry = p_entry
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style(false)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var head := HBoxContainer.new()
	vbox.add_child(head)
	var title := Label.new()
	title.text = entry.title
	title.add_theme_font_size_override("font_size", 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	if entry.reliability <= 0:
		var note := Label.new()
		note.text = "（不確か）"
		note.add_theme_color_override("font_color", Palette.INK_FAINT)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(note)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_stamp = Label.new()
	_stamp.text = "照合済"
	_stamp.add_theme_color_override("font_color", Palette.NG)
	_stamp.visible = false
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# コンテナの子だと拡大・回転が毎フレーム戻されるので、素の Control に載せる
	var stamp_holder := Control.new()
	stamp_holder.custom_minimum_size = Vector2(80, 32)
	stamp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_holder.add_child(_stamp)
	head.add_child(stamp_holder)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 0)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(flow)
	for seg in entry.body_segments():
		if seg["blank"] != &"":
			var blank_id: StringName = seg["blank"]
			var slot := BlankSlot.new()
			slot.setup(blank_id, str(entry.blank_fills.get(blank_id, "？")), filled_blanks.has(blank_id))
			slot.keyword_dropped.connect(func(kw: StringName, target: StringName) -> void: keyword_dropped.emit(kw, target))
			slot.target_clicked.connect(func(target: StringName) -> void: target_clicked.emit(target))
			flow.add_child(slot)
			slots[blank_id] = slot
		else:
			# 日本語は単語区切りが無いので、1文字ずつ流し込んで折り返せるようにする
			for ch in String(seg["text"]):
				var label := Label.new()
				label.text = ch
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				flow.add_child(label)


func show_stamp(value: bool, animated: bool = false) -> void:
	_stamp.visible = value
	if value and animated:
		_stamp.reset_size()
		Effects.stamp_slam(_stamp)
	elif not value:
		_stamp.scale = Vector2.ONE
		_stamp.modulate.a = 1.0


func flash(color: Color) -> void:
	modulate = color
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)


func pop() -> void:
	Effects.pop(self)


func wobble() -> void:
	Effects.wobble(self)


func _apply_style(hint: bool) -> void:
	var border := Palette.DROP_HINT if hint else Palette.PAPER_DIM
	add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, border, 2, 6, 10.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_apply_style(true)
	elif what == NOTIFICATION_DRAG_END:
		_apply_style(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "keyword"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	keyword_dropped.emit(StringName(data["id"]), entry.id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			target_clicked.emit(entry.id)
