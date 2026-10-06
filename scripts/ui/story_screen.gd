class_name StoryScreen
extends Control
## ノベル風の場面の画面。文章が1行ずつ流れ、クリック（またはスペース／Enter）で次へ進む。
## 再生する場面は GameSession.story_scene で決まり、終わったら GameSession.story_next のシーンへ進む。

signal finished

const CHARS_PER_SEC := 34.0

var scene: StoryScene
var index := -1
## 場面を最後まで見終わったか
var done := false
## false にすると、終わってもシーンを切り替えない（テスト用）
var navigate := true

var _typing := false
var _revealed := 0.0
var _text_label: Label
var _name_label: Label
var _portrait: TextureRect
var _hint: Label
var _title_label: Label
var _progress: Label
var _panel: PanelContainer
var _background: TextureRect


func _ready() -> void:
	theme = Palette.make_theme()
	scene = StoryData.find(GameSession.story_scene)
	_build_ui()
	if scene == null or scene.lines.is_empty():
		_finish()
		return
	_title_label.text = scene.title
	advance()


func _process(delta: float) -> void:
	if not _typing:
		return
	var total := _text_label.get_total_character_count()
	_revealed = minf(float(total), _revealed + CHARS_PER_SEC * delta)
	var before := _text_label.visible_characters
	_text_label.visible_characters = int(_revealed)
	if int(_revealed) / 3 > maxi(0, before) / 3:
		Sfx.play(&"type")
	if _revealed >= total:
		_typing = false
		_hint.text = "クリックで次へ ▼" if index < scene.lines.size() - 1 else "クリックで終わる ▼"


func _build_ui() -> void:
	var desk := ColorRect.new()
	desk.color = Palette.DESK
	desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	# 背景の絵（assets/illustrations/backgrounds/<場面id>.png があれば）
	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if scene != null:
		var bg := Illustrations.find("backgrounds", scene.id)
		if bg != null:
			_background.texture = bg
	add_child(_background)

	# クリックで進める、画面全体の受け皿
	var click_area := Control.new()
	click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_area.gui_input.connect(_on_click_area_input)
	add_child(click_area)

	_title_label = Label.new()
	_title_label.position = Vector2(32, 24)
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Palette.DESK_TEXT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_progress = Label.new()
	_progress.position = Vector2(32, 62)
	_progress.add_theme_color_override("font_color", Palette.INK_FAINT)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	var skip := Button.new()
	skip.text = "スキップ"
	skip.custom_minimum_size = Vector2(120, 40)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(1280 - 150, 20)
	skip.pressed.connect(_on_skip)
	add_child(skip)

	# 下の文章枠
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 60.0
	_panel.offset_right = -60.0
	_panel.offset_top = -270.0
	_panel.offset_bottom = -40.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK, 3, 10, 22.0))
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(150, 150)
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
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", Color("8a4a1a"))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 25)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text_label)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Palette.INK_FAINT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint)


## 次の行へ。文字送り中なら、まず最後まで表示する。最後まで読んだら、場面を終える。
func advance() -> void:
	if done or scene == null:
		return
	if _typing:
		_text_label.visible_characters = -1
		_revealed = float(_text_label.get_total_character_count())
		_typing = false
		_hint.text = "クリックで次へ ▼" if index < scene.lines.size() - 1 else "クリックで終わる ▼"
		return
	index += 1
	if index >= scene.lines.size():
		_finish()
		return
	_show_line(scene.lines[index])


func _show_line(line: Dictionary) -> void:
	var speaker: String = line["speaker"]
	var portrait_key: StringName = line["portrait"]
	var is_speech := speaker != ""
	_name_label.text = speaker
	_name_label.visible = is_speech
	var face: Texture2D = null
	if portrait_key != &"":
		face = Illustrations.find("portraits", portrait_key)
	_portrait.texture = face
	_portrait.visible = face != null
	# セリフは「」で囲み、語りは地の文として、そのまま出す
	_text_label.text = "「%s」" % line["text"] if is_speech else String(line["text"])
	_text_label.visible_characters = 0
	_revealed = 0.0
	_typing = true
	_hint.text = ""
	_progress.text = "%d / %d" % [index + 1, scene.lines.size()]


func _on_click_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Sfx.play(&"click")
			advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _on_skip() -> void:
	Sfx.play(&"click")
	_finish()


## 場面を見たことにして、次のシーンへ進む
func _finish() -> void:
	if done:
		return
	done = true
	_typing = false
	if scene != null:
		GameSession.mark_seen(scene.id)
	finished.emit()
	if navigate:
		GameSession.go_to(get_tree(), GameSession.story_next)
