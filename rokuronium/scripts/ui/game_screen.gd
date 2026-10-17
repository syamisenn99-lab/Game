extends Control
## メイン画面: 背景・立ち絵・状況欄・本文（文字送り）・選択肢・メニュー。
## 表示するだけで、進行はすべて StoryEngine に任せる。

const PORTRAIT_SIZE := Vector2(270, 390)
const PORTRAIT_Y := 44.0
const PORTRAIT_XS := {
	1: [505.0],
	2: [230.0, 780.0],
	3: [110.0, 505.0, 900.0],
}

var engine: StoryEngine

var _bg_rect: ColorRect
var _bg_tex: TextureRect
var _bg_label: Label
var _portrait_layer: Control
var _status_label: Label
var _text: RichTextLabel
var _more_mark: Label
var _choice_box: VBoxContainer
var _menu_overlay: Control
var _menu_content: RichTextLabel

var _pages: Array[String] = []
var _page := 0
var _typing := false
var _progress := 0.0


func _ready() -> void:
	engine = App.engine
	_build_ui()
	_render_scene()


# ---------------------------------------------------------------- UI 構築

func _build_ui() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	_bg_tex = TextureRect.new()
	_bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_tex)
	_bg_label = UIKit.make_label("", 60, Color(1, 1, 1, 0.16))
	_bg_label.position = Vector2(0, 160)
	_bg_label.size = Vector2(1280, 90)
	_bg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_label)

	_portrait_layer = Control.new()
	_portrait_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_layer)

	# 状況欄
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.06, 0.1, 0.85), UIKit.COLOR_BORDER, 6, 1))
	status_panel.position = Vector2(10, 8)
	status_panel.size = Vector2(1120, 40)
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_panel)
	_status_label = UIKit.make_label("", 17)
	_status_label.clip_text = true
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(_status_label)

	var menu_btn := UIKit.make_button("メニュー", 18)
	menu_btn.position = Vector2(1140, 8)
	menu_btn.size = Vector2(130, 40)
	menu_btn.pressed.connect(_open_menu)
	add_child(menu_btn)

	# 選択肢（下端そろえで上に積む）
	_choice_box = VBoxContainer.new()
	_choice_box.position = Vector2(240, 70)
	_choice_box.size = Vector2(800, 356)
	_choice_box.alignment = BoxContainer.ALIGNMENT_END
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_choice_box)

	# 本文ボックス
	var text_panel := PanelContainer.new()
	text_panel.add_theme_stylebox_override("panel", UIKit.box())
	text_panel.position = Vector2(40, 442)
	text_panel.size = Vector2(1200, 262)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	_text.add_theme_color_override("default_color", UIKit.COLOR_TEXT)
	_text.add_theme_constant_override("line_separation", 6)
	text_panel.add_child(_text)
	_more_mark = UIKit.make_label("▼", 20, Color(1, 0.9, 0.5))
	_more_mark.position = Vector2(1200, 668)
	_more_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_more_mark)

	_build_menu()
	gui_input.connect(_on_root_gui_input)


func _build_menu() -> void:
	_menu_overlay = Control.new()
	_menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.visible = false
	add_child(_menu_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.07, 0.08, 0.12, 0.98)))
	panel.position = Vector2(170, 70)
	panel.size = Vector2(940, 580)
	_menu_overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	var defs := [["ステータス", "status"], ["持ち物", "items"], ["親密度", "affinity"], ["依頼", "quests"], ["セーブ・ロード", "save"]]
	for d in defs:
		var b := UIKit.make_button(d[0], 18)
		if d[1] in ["quests", "save"]:
			b.disabled = true
			b.tooltip_text = "フェーズ2以降で対応予定"
		else:
			b.pressed.connect(_show_menu_tab.bind(d[1]))
		tabs.add_child(b)

	_menu_content = RichTextLabel.new()
	_menu_content.bbcode_enabled = true
	_menu_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_content.add_theme_font_size_override("normal_font_size", 21)
	_menu_content.add_theme_font_size_override("bold_font_size", 21)
	_menu_content.add_theme_color_override("default_color", UIKit.COLOR_TEXT)
	vb.add_child(_menu_content)

	var close := UIKit.make_button("閉じる", 20)
	close.pressed.connect(func(): _menu_overlay.visible = false)
	vb.add_child(close)


func _open_menu() -> void:
	_show_menu_tab("status")
	_menu_overlay.visible = true


func _show_menu_tab(tab: String) -> void:
	var s := App.state
	match tab:
		"status":
			_menu_content.text = MenuText.status(s)
		"items":
			_menu_content.text = MenuText.items(s, App.db)
		"affinity":
			_menu_content.text = MenuText.affinity(s, App.db)


# ---------------------------------------------------------------- シーン表示

func _render_scene() -> void:
	var sc := engine.scene
	_clear_choices()
	_status_label.text = App.state.status_line()
	_update_background(str(sc.get("background", "")), str(sc.get("location", "")))
	_update_portraits(sc.get("portraits", []))
	if sc.has("bgm"):
		App.play_bgm(str(sc["bgm"]))
	if sc.has("se"):
		App.play_se(str(sc["se"]))

	_pages.clear()
	var notices := engine.take_notices()
	var lines := engine.get_lines()
	if lines.is_empty():
		lines.append("")
	for i in lines.size():
		var page := _escape(lines[i])
		if i == 0 and not notices.is_empty():
			var head := ""
			for n in notices:
				head += "[color=%s]%s[/color]\n" % [UIKit.COLOR_NOTICE, _escape(str(n))]
			page = head + page
		_pages.append(page)
	_page = 0
	_show_page()


func _escape(s: String) -> String:
	return s.replace("[", "[lb]")


func _show_page() -> void:
	_text.text = _pages[_page]
	_more_mark.visible = false
	if int(App.settings["text_speed"]) <= 0:
		_finish_typing()
		return
	_text.visible_characters = 0
	_progress = 0.0
	_typing = true


func _finish_typing() -> void:
	_text.visible_characters = -1
	_typing = false
	if _page < _pages.size() - 1:
		_more_mark.visible = true
	else:
		_show_choices()


func _process(delta: float) -> void:
	if not _typing:
		return
	_progress += float(App.settings["text_speed"]) * delta
	var count := int(_progress)
	if count >= _text.get_total_character_count():
		_finish_typing()
	else:
		_text.visible_characters = count


## クリック／Enter／Space: 文字送り中なら全文表示、表示済みなら次のページへ。
func _advance() -> void:
	if _menu_overlay.visible:
		return
	if _typing:
		_finish_typing()
	elif _page < _pages.size() - 1:
		_page += 1
		_show_page()


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < _choice_box.get_child_count() and not _menu_overlay.visible:
			(_choice_box.get_child(n) as Button).pressed.emit()


# ---------------------------------------------------------------- 選択肢

func _clear_choices() -> void:
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()


func _show_choices() -> void:
	_clear_choices()
	if engine.is_end():
		var b := _make_choice_button("タイトルへ戻る")
		b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
		_choice_box.add_child(b)
		b.grab_focus()
		return
	for i in engine.shown_choices.size():
		var ch: Dictionary = engine.shown_choices[i]
		var b := _make_choice_button(str(ch.get("text", "")))
		b.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(b)
	if _choice_box.get_child_count() > 0:
		(_choice_box.get_child(0) as Button).grab_focus()


func _make_choice_button(text: String) -> Button:
	var b := UIKit.make_button(text, 22)
	b.custom_minimum_size = Vector2(800, 54)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _on_choice(index: int) -> void:
	_clear_choices()
	engine.choose(index)
	_render_scene()


# ---------------------------------------------------------------- 背景・立ち絵

func _update_background(bg_id: String, location: String) -> void:
	var tex := UIKit.load_background_texture(bg_id)
	_bg_tex.texture = tex
	_bg_tex.visible = tex != null
	_bg_rect.color = UIKit.background_color(App.db, bg_id)
	# 仮素材のあいだは、場所名をうっすら大きく出す
	_bg_label.text = location if tex == null else ""


func _update_portraits(ids: Array) -> void:
	for c in _portrait_layer.get_children():
		_portrait_layer.remove_child(c)
		c.queue_free()
	var n := mini(ids.size(), 3)
	if n == 0:
		return
	var xs: Array = PORTRAIT_XS[n]
	for i in n:
		var node := _make_portrait(str(ids[i]))
		node.position = Vector2(xs[i], PORTRAIT_Y)
		_portrait_layer.add_child(node)


func _make_portrait(portrait_id: String) -> Control:
	var tex := UIKit.load_portrait_texture(portrait_id)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = PORTRAIT_SIZE
		tr.size = PORTRAIT_SIZE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	# 仮素材: 色付きの四角形と名前ラベル
	var parts := portrait_id.split("_", true, 1)
	var char_id := parts[0]
	var expr := parts[1] if parts.size() > 1 else ""
	var col := Color("#888888")
	if App.db.characters.has(char_id):
		col = Color(str(App.db.characters[char_id].get("color", "#888888")))
	var panel := Panel.new()
	panel.size = PORTRAIT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UIKit.box(col.darkened(0.25), col.lightened(0.3), 14, 3))
	var name_l := UIKit.make_label(App.db.char_name(char_id), 34)
	name_l.position = Vector2(0, 150)
	name_l.size = Vector2(PORTRAIT_SIZE.x, 50)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_l)
	var expr_l := UIKit.make_label(expr, 20, Color(1, 1, 1, 0.7))
	expr_l.position = Vector2(0, 205)
	expr_l.size = Vector2(PORTRAIT_SIZE.x, 30)
	expr_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expr_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(expr_l)
	return panel


# ---------------------------------------------------------------- テスト用

func debug_choice_buttons() -> Array:
	return _choice_box.get_children()


func debug_is_typing() -> bool:
	return _typing


func debug_page_info() -> Vector2i:
	return Vector2i(_page, _pages.size())
