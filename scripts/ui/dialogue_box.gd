class_name DialogueBox
extends Control
## 探索画面の上に重ねる、会話ボックス。語りとセリフを1行ずつ流し、クリック／スペース／Enterで進む。
## 全部読み終えたら finished を出して、自分で消える。ストーリー画面の文章枠と、同じ見た目。

signal finished

const CHARS_PER_SEC := 34.0

var lines: Array[Dictionary] = []
var index := -1
var done := false

var _typing := false
var _revealed := 0.0
var _name_label: Label
var _text_label: Label
var _portrait: TextureRect
var _hint: Label


## lines の各行: {"speaker": 名前（空なら語り）, "text": 文, "portrait": 顔の絵の名前（空なら顔なし）}
func setup(p_lines: Array[Dictionary]) -> void:
	lines = p_lines
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	advance()


func _process(delta: float) -> void:
	if not _typing:
		return
	var total := _text_label.get_total_character_count()
	var before := _text_label.visible_characters
	_revealed = minf(float(total), _revealed + CHARS_PER_SEC * delta)
	_text_label.visible_characters = int(_revealed)
	if int(_revealed) / 3 > maxi(0, before) / 3:
		Sfx.play(&"type")
	if _revealed >= total:
		_typing = false
		_update_hint()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60.0
	panel.offset_right = -60.0
	panel.offset_top = -250.0
	panel.offset_bottom = -40.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK, 3, 10, 20.0))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(140, 140)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color("8a4a1a"))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text_label)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Palette.INK_FAINT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint)


## 次の行へ。文字送り中なら、まず最後まで表示する。最後まで読んだら終わる。
func advance() -> void:
	if done:
		return
	if _typing:
		_text_label.visible_characters = -1
		_revealed = float(_text_label.get_total_character_count())
		_typing = false
		_update_hint()
		return
	index += 1
	if index >= lines.size():
		_finish()
		return
	_show_line(lines[index])


func _show_line(line: Dictionary) -> void:
	var speaker: String = line["speaker"]
	var key: StringName = line["portrait"]
	_name_label.text = speaker
	_name_label.visible = speaker != ""
	var face: Texture2D = Illustrations.find("portraits", key) if key != &"" else null
	_portrait.texture = face
	_portrait.visible = face != null
	_text_label.text = "「%s」" % line["text"] if speaker != "" else String(line["text"])
	_text_label.visible_characters = 0
	_revealed = 0.0
	_typing = true
	_hint.text = ""


func _update_hint() -> void:
	_hint.text = "クリックで次へ ▼" if index < lines.size() - 1 else "クリックで閉じる ▼"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Sfx.play(&"click")
			advance()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not done and event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if done:
		return
	done = true
	_typing = false
	finished.emit()
	queue_free()
