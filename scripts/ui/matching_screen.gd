class_name MatchingScreen
extends Control
## 探索フェーズの照合画面。報告（タイプライター表示）→ 照合ドロップ → 能力値を選んで指示 → ダイス判定。
## ロジックは MatchingState に任せ、ここは表示と入力の橋渡しだけを行う。

enum Phase { REPORTING, ROLLING, RESULT, SUMMARY }

const PREP_SCENE := "res://scenes/prep_screen.tscn"
const PAGE_TITLES := {&"plants": "植物", &"monsters": "魔物", &"traps": "罠", &"relics": "遺物"}

var state: MatchingState
var rng := RandomNumberGenerator.new()

var _phase := Phase.REPORTING
var _entries: Array[NoteEntry] = []
var _entry_views: Dictionary = {}
var _selected_chip: KeywordChip

# 報告のタイプライター表示
var _report_nodes: Array[Dictionary] = []
var _chips: Array[KeywordChip] = []
var _total_chars := 0
var _revealed := 0.0

# UI 部品
var _name_label: Label
var _event_label: Label
var _reward_label: Label
var _timer_bar: ProgressBar
var _time_label: Label
var _log_box: VBoxContainer
var _tabs: TabContainer
var _stat_buttons: Dictionary = {}
var _line_label: Label
var _dice_label: Label
var _next_button: Button
var _overlay: Control
var _cmd_panel: PanelContainer
var _cmd_pulse: Tween
var _cmd_hint_active := false
var _tab_base_titles: Array[String] = []
var _last_whole_sec := 99
var _portrait_rect: TextureRect
## 冒険者のスケッチ（絵のファイルがあるときだけ）。文字送りが終わったら、ふわっと出る
var _sketch_frame: Control
var _sketch_shown := false
var _report_done := false
## チュートリアル（プロローグのあとの最初の冒険）の最中か。案内の吹き出しが出て、時間は止まる
var _guided := false
var _coach_row: PanelContainer
var _coach_label: Label
var _skip_adventure_button: Button
var _guided_chips: Array[KeywordChip] = []
var _guide_target_view: NoteEntryView
var _guide_target_slot: BlankSlot
var _guided_button: Button
## 初めての冒険の会話ボックス（出来事の前後）。出ている間は、文字送りが止まる
var _dialogue: DialogueBox
var _coach_name: Label
var _coach_face: TextureRect
var _guide_button_tween: Tween
var _log_scroll: ScrollContainer
var _mute_button: Button
## 探索終了時の精算の結果（GameSession.settle の戻り値）
var settlement: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	_guided = GameSession.first_adventure_active
	_build_ui()
	var entries := SampleData.entries()
	_entries = entries
	GameSession.load_notebook()
	if _guided:
		# 幼なじみとの初めての冒険。お金・日数には影響しないが、埋めた・直したノートは、そのまま本番のノートに残る
		var friend := SampleData.adventurer(SampleData.CHILDHOOD)
		state = MatchingState.new(friend, SampleData.events(SampleData.FIRST_ADVENTURE), entries, GameSession.filled_blanks)
		state.guided = true
		_start_guided_ui()
	else:
		var real := SampleData.adventurer(GameSession.adventurer_id)
		var real_events := SampleData.events(real.id)
		# 謎の遺物（冒険者ごとに別の断片を報告する）。まだ分かっていない断片だけ、最後に付く
		var relic := SampleData.relic_event(real.id, GameSession.filled_blanks)
		if relic != null:
			real_events.append(relic)
		state = MatchingState.new(real, real_events, entries, GameSession.filled_blanks)
		# 買った道具の効果
		if GameSession.has_item(&"hourglass"):
			state.time_scale = Rules.HOURGLASS_TIME_SCALE
		if GameSession.has_item(&"sticky"):
			state.penalty_scale = Rules.STICKY_PENALTY_SCALE
		# パニックになりやすい冒険者ほど、間違えたときに余計に時間を失う
		state.penalty_scale *= real.panic_factor
	var adventurer := state.adventurer
	_name_label.text = "通信中: %s" % state.adventurer.display_name
	var portrait := Illustrations.find("portraits", adventurer.id)
	if portrait != null:
		_portrait_rect.texture = portrait
		_portrait_rect.visible = true
	_build_notebook()
	_start_next_event()


func _process(delta: float) -> void:
	if _phase != Phase.REPORTING:
		return
	# 会話ボックスが出ている間は、文字送りも止める
	if _dialogue != null and is_instance_valid(_dialogue) and not _dialogue.done:
		return
	_advance_typewriter(delta)
	_warn_low_time()
	if state.tick(delta):
		_line_label.text = "（時間切れ…！ 指示が間に合わなかった）"
		_resolve(&"")
	_update_timer_ui()


# ---------------------------------------------------------------- 画面構築

func _build_ui() -> void:
	theme = Palette.make_theme()

	var desk := ColorRect.new()
	desk.color = Palette.DESK
	desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# 上部バー
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(44, 44)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.visible = false
	top.add_child(_portrait_rect)
	_name_label = _desk_label("")
	top.add_child(_name_label)
	_event_label = _desk_label("")
	top.add_child(_event_label)
	_reward_label = _desk_label("")
	top.add_child(_reward_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(360, 26)
	_timer_bar.show_percentage = false
	top.add_child(_timer_bar)
	_time_label = _desk_label("")
	_time_label.custom_minimum_size = Vector2(64, 0)
	top.add_child(_time_label)
	_skip_adventure_button = Button.new()
	_skip_adventure_button.text = "この冒険をとばす"
	_skip_adventure_button.custom_minimum_size = Vector2(170, 32)
	_skip_adventure_button.visible = false
	_skip_adventure_button.pressed.connect(_on_skip_adventure)
	top.add_child(_skip_adventure_button)
	_mute_button = Button.new()
	_mute_button.text = Sfx.mute_button_text()
	_mute_button.custom_minimum_size = Vector2(96, 32)
	_mute_button.pressed.connect(_on_mute_pressed)
	top.add_child(_mute_button)

	# チュートリアルの案内（チュートリアル中だけ見える）
	_coach_row = PanelContainer.new()
	_coach_row.visible = false
	_coach_row.add_theme_stylebox_override("panel", Palette.box(Color("fff3cf"), Color("e0a800"), 3, 10, 10.0))
	root.add_child(_coach_row)
	var coach_box := HBoxContainer.new()
	coach_box.add_theme_constant_override("separation", 12)
	_coach_row.add_child(coach_box)
	_coach_face = TextureRect.new()
	_coach_face.custom_minimum_size = Vector2(52, 52)
	_coach_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coach_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coach_face.visible = false
	coach_box.add_child(_coach_face)
	var coach_col := VBoxContainer.new()
	coach_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coach_col.add_theme_constant_override("separation", 2)
	coach_box.add_child(coach_col)
	_coach_name = Label.new()
	_coach_name.add_theme_font_size_override("font_size", 18)
	_coach_name.add_theme_color_override("font_color", Color("8a4a1a"))
	coach_col.add_child(_coach_name)
	_coach_label = Label.new()
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_coach_label.add_theme_font_size_override("font_size", 21)
	coach_col.add_child(_coach_label)

	# 中央: 通信ログ（左）とノート（右）
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 16)
	root.add_child(middle)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_stretch_ratio = 1.0
	log_panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER_DIM, Palette.INK_FAINT, 2, 4, 14.0))
	log_panel.gui_input.connect(_on_log_gui_input)
	middle.add_child(log_panel)
	var log_vbox := VBoxContainer.new()
	log_panel.add_child(log_vbox)
	var log_title := Label.new()
	log_title.text = "通信ログ"
	log_title.add_theme_color_override("font_color", Palette.INK_FAINT)
	log_vbox.add_child(log_title)
	# 長い報告でも、画面全体が押し広げられないように、ログはスクロールできる枠に入れる
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_vbox.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_scroll.add_child(_log_box)
	var hint := Label.new()
	hint.text = "黄色い語をノートへドラッグ（クリックで選んでノートをクリックでもOK）／ ログをクリックで文字送り"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Palette.INK_FAINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_vbox.add_child(hint)

	var book_panel := PanelContainer.new()
	book_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_panel.size_flags_stretch_ratio = 1.2
	book_panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER_DIM, Palette.INK_FAINT, 2, 4, 10.0))
	middle.add_child(book_panel)
	_tabs = TabContainer.new()
	_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	book_panel.add_child(_tabs)

	# 下部: 指示パネル
	var bottom := PanelContainer.new()
	_cmd_panel = bottom
	bottom.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK_FAINT, 2, 6, 12.0))
	root.add_child(bottom)
	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 8)
	bottom.add_child(bvbox)

	var cmd := HBoxContainer.new()
	cmd.add_theme_constant_override("separation", 10)
	bvbox.add_child(cmd)
	var cmd_label := Label.new()
	cmd_label.text = "指示（どうする？）:"
	cmd.add_child(cmd_label)
	for stat in Rules.STATS:
		var button := Button.new()
		button.text = Rules.STAT_LABELS[stat]
		button.custom_minimum_size = Vector2(96, 40)
		button.pressed.connect(_on_stat_chosen.bind(stat))
		cmd.add_child(button)
		_stat_buttons[stat] = button
	var cmd_spacer := Control.new()
	cmd_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd.add_child(cmd_spacer)
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(140, 40)
	_next_button.pressed.connect(_on_next_pressed)
	cmd.add_child(_next_button)

	_line_label = Label.new()
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(0, 30)
	bvbox.add_child(_line_label)
	_dice_label = Label.new()
	_dice_label.add_theme_color_override("font_color", Palette.INK_FAINT)
	bvbox.add_child(_dice_label)

	# 演出用の最前面レイヤ（入力は受けない）
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _desk_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.DESK_TEXT)
	return label


func _build_notebook() -> void:
	var pages: Dictionary = {}
	for entry in _entries:
		if not pages.has(entry.page):
			var scroll := ScrollContainer.new()
			scroll.name = PAGE_TITLES.get(entry.page, str(entry.page))
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var list := VBoxContainer.new()
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list.add_theme_constant_override("separation", 10)
			scroll.add_child(list)
			_tabs.add_child(scroll)
			pages[entry.page] = list
		var view := NoteEntryView.new()
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.setup(entry, state.filled_blanks)
		view.keyword_dropped.connect(_on_keyword_dropped)
		view.target_clicked.connect(_on_target_clicked)
		(pages[entry.page] as VBoxContainer).add_child(view)
		_entry_views[entry.id] = view
	for i in _tabs.get_tab_count():
		_tab_base_titles.append(_tabs.get_tab_title(i))


# ---------------------------------------------------------------- イベント進行

func _start_next_event() -> void:
	if not state.begin_next_event():
		_show_summary()
		return
	_phase = Phase.REPORTING
	_selected_chip = null
	_last_whole_sec = 99
	_set_command_hint(false)
	_clear_guides()
	for view: NoteEntryView in _entry_views.values():
		view.show_stamp(false)
	_build_report()
	_line_label.text = "（声に耳をすます…）"
	_dice_label.text = ""
	_next_button.visible = false
	_set_stat_buttons_enabled(true)
	_event_label.text = "%s %d / %d" % ["第1層・入口" if _guided else "イベント", state.event_index + 1, state.events.size()]
	_reward_label.text = "" if _guided else "持ち帰り報酬: %d" % int(state.reward)
	_timer_bar.max_value = state.event_time_limit
	_update_timer_ui()
	_refresh_suspects()
	if _guided:
		# 初めての冒険: 出来事の前の会話が先。終わったら、案内（物語のセリフ）が始まる
		_coach_label.text = ""
		_coach_name.text = ""
		_coach_face.visible = false
		_play_dialogue(state.current.before_lines, func() -> void: _coach("report"))
	if state.auto_matched:
		_announce_known_note()


func _build_report() -> void:
	for child in _log_box.get_children():
		_log_box.remove_child(child)
		child.queue_free()
	_report_nodes.clear()
	_chips.clear()
	_revealed = 0.0
	_total_chars = 0
	_sketch_frame = null
	_sketch_shown = false
	_report_done = false

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 0)
	flow.add_theme_constant_override("v_separation", 8)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.add_child(flow)

	for seg in ReportParser.parse(state.current.report):
		var text: String = seg["text"]
		if seg["kw"] != &"":
			var chip := KeywordChip.new()
			chip.setup(seg["kw"], text)
			chip.chip_clicked.connect(_on_chip_clicked)
			chip.modulate.a = 0.0
			flow.add_child(chip)
			_chips.append(chip)
			_report_nodes.append({"node": chip, "offset": _total_chars})
			_total_chars += text.length()
		else:
			for ch in text:
				var label := Label.new()
				label.text = ch
				label.modulate.a = 0.0
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				flow.add_child(label)
				_report_nodes.append({"node": label, "offset": _total_chars})
				_total_chars += 1

	# 冒険者のスケッチ（絵のファイルがあれば）
	var sketch := Illustrations.find("sketches", state.current.sketch, state.adventurer.id)
	if sketch != null:
		_sketch_frame = _make_sketch_frame(sketch)
		_sketch_frame.modulate.a = 0.0
		_log_box.add_child(_sketch_frame)


func _advance_typewriter(delta: float) -> void:
	if _revealed >= _total_chars:
		return
	var before := int(_revealed)
	_revealed = minf(float(_total_chars), _revealed + state.adventurer.chars_per_sec * delta)
	_apply_reveal()
	# 2文字ごとに、ごく小さな音を鳴らす
	if int(_revealed) / 2 > before / 2:
		Sfx.play(&"type")
	if _revealed >= _total_chars:
		_on_report_complete()


func _reveal_all() -> void:
	_revealed = float(_total_chars)
	_apply_reveal()
	_on_report_complete()


## 報告を読み終えた（文字送りが終わった）とき
func _on_report_complete() -> void:
	_show_sketch()
	if _report_done:
		return
	_report_done = true
	if _guided:
		_guide_drag()


## 冒険者の描いたスケッチを、紙に貼ったように見せる
func _make_sketch_frame(texture: Texture2D) -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", Palette.box(Color("fbf6e6"), Palette.INK_FAINT, 2, 4, 8.0))
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(vbox)
	var picture := TextureRect.new()
	picture.texture = texture
	# 長い報告のときは、スケッチを小さくして、ログに収まるようにする
	picture.custom_minimum_size = Vector2(160, 120) if _total_chars > 90 else Vector2(288, 216)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(picture)
	var caption := Label.new()
	caption.text = "%sのスケッチ" % state.adventurer.display_name
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Palette.INK_FAINT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(caption)
	return frame


func _show_sketch() -> void:
	if _sketch_frame == null or _sketch_shown:
		return
	_sketch_shown = true
	create_tween().tween_property(_sketch_frame, "modulate:a", 1.0, 0.5)



func _apply_reveal() -> void:
	var count := int(_revealed)
	for item in _report_nodes:
		var node: Control = item["node"]
		var shown := count > int(item["offset"])
		node.modulate.a = 1.0 if shown else 0.0
		if node is KeywordChip:
			# 表示された瞬間から掴める（読み切る前に判断する遊びにもなる）
			(node as KeywordChip).set_enabled(shown and _phase == Phase.REPORTING)


func _update_timer_ui() -> void:
	if _guided:
		_timer_bar.max_value = 1.0
		_timer_bar.value = 1.0
		_timer_bar.modulate = Color.WHITE
		_time_label.text = "練習"
		return
	_timer_bar.value = state.time_left
	_time_label.text = "%.1f" % state.time_left
	var low := state.time_left < state.event_time_limit * 0.3
	_timer_bar.modulate = Color(1.0, 0.55, 0.5) if low else Color.WHITE


## ノートと報告が食い違っていて訂正できる箇所を、オレンジに脈打たせる。
## 別のタブにあるときは、タブ名に「●」を付けて場所を知らせる。
func _refresh_suspects() -> void:
	_clear_suspects()
	if state.current == null or state.resolved:
		return
	for target in state.current.keyword_targets.values():
		var target_id := StringName(target)
		if not state.is_fix(target_id) or state.is_blank_filled(target_id):
			continue
		var view := _view_for_target(target_id)
		if view == null or not view.slots.has(target_id):
			continue
		(view.slots[target_id] as BlankSlot).set_suspect(true)
		for i in _tabs.get_tab_count():
			if _tabs.get_tab_control(i).is_ancestor_of(view):
				_tabs.set_tab_title(i, _tab_base_titles[i] + " ●")


func _clear_suspects() -> void:
	for i in _tabs.get_tab_count():
		_tabs.set_tab_title(i, _tab_base_titles[i])
	for view: NoteEntryView in _entry_views.values():
		for slot: BlankSlot in view.slots.values():
			slot.set_suspect(false)


func _default_known_line(target_id: StringName) -> String:
	var text: String = state.fill_texts.get(target_id, "")
	if state.is_fix(target_id):
		return "（ノートは前に直してある。「%s」と分かっている）" % text
	return "（ノートに「%s」と書いてある。これなら、指示が出せる）" % text


## 以前に埋めた虫食いのおかげで、照合済みで始まったとき: 該当の項目を見せて、すぐ指示へ誘導する
func _announce_known_note() -> void:
	var blank_id := state.auto_target
	var view := _view_for_target(blank_id)
	if view == null:
		return
	# 該当ページへ自動で切り替える（ノートが効いたことを見せる）
	for i in _tabs.get_tab_count():
		if _tabs.get_tab_control(i).is_ancestor_of(view):
			_tabs.current_tab = i
	_line_label.text = state.current.known_line if state.current.known_line != "" else _default_known_line(blank_id)
	_set_command_hint(true)
	await get_tree().process_frame
	await get_tree().process_frame
	if _phase != Phase.REPORTING or view == null or not is_instance_valid(view):
		return
	view.show_stamp(true, true)
	view.flash(Color(0.7, 1.0, 0.75))
	view.pop()
	Sfx.play(&"stamp")
	Sfx.play(&"known")
	var slot_at := view.get_global_rect().get_center()
	if view.slots.has(blank_id):
		var slot := view.slots[blank_id] as BlankSlot
		slot.pop()
		slot_at = slot.get_global_rect().get_center()
	Effects.burst(_overlay, slot_at, Palette.HILITE_BG, 32)
	Effects.float_text(_overlay, "ノートが役に立った！", slot_at + Vector2(0, -34), Palette.OK, 28)


## 照合に成功したあと、「次は下の指示を選ぶ」と分かるように、指示パネルを光らせる（文字は出さない）
func _set_command_hint(active: bool) -> void:
	if _cmd_pulse != null:
		_cmd_pulse.kill()
		_cmd_pulse = null
	var was_active := _cmd_hint_active
	_cmd_hint_active = active
	if active and not was_active:
		Sfx.play_later(self, &"ting", 0.3)
	if active:
		var sb := Palette.box(Palette.PAPER, Color("e0a800"), 4, 6, 12.0)
		sb.shadow_color = Color(1.0, 0.85, 0.2, 0.85)
		sb.shadow_size = 6
		_cmd_panel.add_theme_stylebox_override("panel", sb)
		_cmd_pulse = create_tween().set_loops()
		_cmd_pulse.tween_property(sb, "shadow_size", 20, 0.55).set_trans(Tween.TRANS_SINE)
		_cmd_pulse.tween_property(sb, "shadow_size", 6, 0.55).set_trans(Tween.TRANS_SINE)
		for button: Button in _stat_buttons.values():
			button.add_theme_stylebox_override("normal", Palette.box(Palette.INK, Color("e0a800"), 3, 6, 8.0))
	else:
		_cmd_panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK_FAINT, 2, 6, 12.0))
		for button: Button in _stat_buttons.values():
			button.remove_theme_stylebox_override("normal")


func _set_stat_buttons_enabled(value: bool) -> void:
	for button: Button in _stat_buttons.values():
		button.disabled = not value


# ---------------------------------------------------------------- 入力

func _on_log_gui_input(event: InputEvent) -> void:
	if _phase == Phase.REPORTING and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_reveal_all()


func _on_chip_clicked(chip: KeywordChip) -> void:
	if _phase != Phase.REPORTING:
		return
	Sfx.play(&"grab")
	var was_selected := chip == _selected_chip
	_deselect_chip()
	if not was_selected:
		_selected_chip = chip
		chip.selected = true


func _deselect_chip() -> void:
	if _selected_chip != null:
		_selected_chip.selected = false
		_selected_chip = null


func _on_target_clicked(target_id: StringName) -> void:
	if _selected_chip == null:
		return
	_on_keyword_dropped(_selected_chip.keyword_id, target_id)


func _on_keyword_dropped(keyword_id: StringName, target_id: StringName) -> void:
	if _phase != Phase.REPORTING:
		return
	_deselect_chip()
	var view := _view_for_target(target_id)
	match state.drop(keyword_id, target_id):
		MatchingState.DropResult.MATCHED:
			_line_label.text = state.current.correct_line
			var at := get_global_mouse_position()
			if view != null:
				view.show_stamp(true, true, "訂正済" if state.is_fix(target_id) else "照合済")
				view.flash(Color(0.7, 1.0, 0.75))
				view.pop()
				if state.is_blank(target_id) and view.slots.has(target_id):
					var slot := view.slots[target_id] as BlankSlot
					slot.set_filled(true)
					slot.pop()
					at = slot.get_global_rect().get_center()
			Sfx.play(&"stamp")
			Sfx.play(&"fix" if state.is_fix(target_id) else &"match")
			Effects.burst(_overlay, at, Palette.HILITE_BG, 32)
			Effects.burst(_overlay, at, Palette.OK, 14)
			Effects.float_text(_overlay, "訂正！" if state.is_fix(target_id) else "照合！", at + Vector2(0, -24), Palette.OK)
			_set_command_hint(true)
			_refresh_suspects()
			GameSession.save_notebook()
			if _guided:
				_clear_guides()
				_coach_matched()
		MatchingState.DropResult.MISMATCH:
			if _guided:
				_line_label.text = "うーん、ここじゃないみたい。"
				_coach("wrong_drop")
			else:
				_line_label.text = "うーん、ここじゃない気がする…（時間が %.1f 秒減った）" % (Rules.MISMATCH_PENALTY_SEC * state.penalty_scale)
			var at := get_global_mouse_position()
			if view != null:
				view.flash(Color(1.0, 0.6, 0.6))
				view.wobble()
			Sfx.play(&"mismatch")
			Effects.burst(_overlay, at, Palette.NG, 12, false)
			Effects.float_text(_overlay, "ちがう…", at + Vector2(0, -24), Palette.NG, 26)
			if not _guided:
				var bar_end := _timer_bar.get_global_rect().get_center()
				Effects.float_text(_overlay, "-%.1f秒" % (Rules.MISMATCH_PENALTY_SEC * state.penalty_scale), bar_end + Vector2(0, 36), Palette.NG, 26)
				_update_timer_ui()


func _view_for_target(target_id: StringName) -> NoteEntryView:
	var entry_id: StringName = state.blank_owner.get(target_id, target_id)
	return _entry_views.get(entry_id, null)


func _on_stat_chosen(stat: StringName) -> void:
	if _phase == Phase.REPORTING:
		Sfx.play(&"click")
		# チュートリアルでは、手順どおりに進める（先に照合する、正しい指示を選ぶ）
		if _guided:
			if not state.matched:
				Sfx.play(&"mismatch")
				_coach_say("", "……まず、黄色くハイライトされた言葉を、ノートに運ぼう。指示を伝えるのは、そのあとだ。")
				return
			if stat != state.current.required_stat:
				Sfx.play(&"mismatch")
				_coach("wrong_command")
				return
	_resolve(stat)


func _on_next_pressed() -> void:
	Sfx.play(&"click")
	_start_next_event()


func _on_mute_pressed() -> void:
	Sfx.set_muted(not Sfx.muted)
	_mute_button.text = Sfx.mute_button_text()
	Sfx.play(&"click")


## 残り5秒を切ったら、1秒ごとに小さく知らせる
func _warn_low_time() -> void:
	if state.resolved:
		return
	var whole := int(ceil(state.time_left))
	if whole != _last_whole_sec:
		_last_whole_sec = whole
		if whole <= 5 and whole > 0:
			Sfx.play(&"warn")


# ---------------------------------------------------------------- 判定

func _resolve(chosen: StringName) -> void:
	if _phase != Phase.REPORTING:
		return
	_phase = Phase.ROLLING
	_set_command_hint(false)
	_clear_suspects()
	_reveal_all()
	_deselect_chip()
	for chip in _chips:
		chip.set_enabled(false)
	_set_stat_buttons_enabled(false)
	var res := state.resolve(chosen, rng)
	for i in 10:
		_dice_label.text = "d20 ... %d" % rng.randi_range(1, Rules.DICE_SIDES)
		Sfx.play(&"tick", 0.8 + 0.06 * i)
		await get_tree().create_timer(0.06).timeout
	_dice_label.text = _format_result(res)
	var dice_at := _dice_label.get_global_rect().get_center()
	if res["success"]:
		Sfx.play(&"success")
		Effects.burst(_overlay, dice_at, Palette.HILITE_BG, 36)
		Effects.float_text(_overlay, "成功！", dice_at + Vector2(0, -40), Palette.OK, 36)
	else:
		Sfx.play(&"crit_fail" if res["crit_fail"] else &"fail")
		Effects.burst(_overlay, dice_at, Palette.NG, 16, false)
		Effects.float_text(_overlay, "大失敗…！" if res["crit_fail"] else "失敗…", dice_at + Vector2(0, -40), Palette.NG, 36)
	_line_label.text = state.current.success_text if res["success"] else state.current.fail_text
	if res["crit_fail"]:
		_line_label.text += "（大失敗…！）"
	_reward_label.text = "持ち帰り報酬: %d" % int(state.reward)
	_next_button.text = "次へ" if state.has_next() else "探索を終える"
	_phase = Phase.RESULT
	if _guided:
		# 初めての冒険: 結果のあとの会話が流れて、次の出来事（最後は、冒険の終わり）へ進む
		_clear_guides()
		_coach("result")
		_next_button.visible = false
		_play_dialogue(state.current.after_lines, _after_guided_event)
		return
	_next_button.visible = true


func _format_result(res: Dictionary) -> String:
	var stat_name: String = Rules.STAT_LABELS.get(res["chosen"], "無指示")
	return "判定: d20=%d + %s%d = %d  /  目標 %d（基準%d %+d）→ %s" % [
		res["roll"], stat_name, res["stat_value"], res["total"],
		res["target"], res["base_target"], res["modifier"],
		"成功！" if res["success"] else "失敗…",
	]


func _show_summary() -> void:
	_phase = Phase.SUMMARY
	if _guided:
		_finish_first_adventure()
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK, 3, 8, 24.0))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "探索終了"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	for i in state.results.size():
		var res := state.results[i]
		var line := Label.new()
		line.text = "%d. %s（d20=%d）" % [i + 1, "成功" if res["success"] else "失敗", res["roll"]]
		vbox.add_child(line)
	if not state.learned.is_empty():
		var learned_label := Label.new()
		var texts: Array[String] = []
		var spots := SampleData.growth_spots()
		for id in state.learned:
			texts.append(str(spots.get(id, "?")))
		learned_label.text = "ノートに書けたこと: " + "、".join(texts)
		learned_label.add_theme_color_override("font_color", Palette.OK)
		vbox.add_child(learned_label)
	var total := Label.new()
	total.text = "持ち帰り報酬: %d / %d" % [int(state.reward), int(Rules.INITIAL_REWARD)]
	total.add_theme_font_size_override("font_size", 26)
	vbox.add_child(total)

	# 精算: 報酬を受け取り、生活費を払う
	settlement = GameSession.settle(int(state.reward))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_settle_line("報酬を受け取った", "+%d 銀貨" % settlement["reward"], Palette.OK))
	vbox.add_child(_settle_line("生活費（%d日目）" % settlement["day"], "-%d 銀貨" % settlement["living"], Palette.NG))
	var after := _settle_line("残りの資金", "%d 銀貨" % settlement["funds_after"], Palette.INK)
	after.add_theme_font_size_override("font_size", 26)
	vbox.add_child(after)
	if settlement["bankrupt"]:
		var over := Label.new()
		over.text = "資金が尽きて、生活できなくなってしまった…"
		over.add_theme_color_override("font_color", Palette.NG)
		vbox.add_child(over)

	var next := Button.new()
	next.text = "最初からやり直す" if settlement["bankrupt"] else "準備に戻る"
	next.custom_minimum_size = Vector2(0, 48)
	next.pressed.connect(func() -> void:
		Sfx.play(&"click")
		if settlement["bankrupt"]:
			GameSession.reset_all()
		get_tree().change_scene_to_file(PREP_SCENE))
	vbox.add_child(next)


func _settle_line(left: String, right: String, color: Color) -> Label:
	var label := Label.new()
	label.text = "%s　　%s" % [left, right]
	label.add_theme_color_override("font_color", color)
	return label


# ---------------------------------------------------------------- 幼なじみとの初めての冒険

## 初めての冒険の見た目にする（案内を出し、お金や時間の表示を隠す）
func _start_guided_ui() -> void:
	_coach_row.visible = true
	_skip_adventure_button.visible = true
	_reward_label.visible = false
	_timer_bar.visible = false
	_time_label.visible = false


## 案内を出す。キーは EventDef.coach のもの。値は {"speaker": 名前（空なら語り）, "text": 文}
func _coach(key: String) -> void:
	if not _guided or state == null or state.current == null:
		return
	var entry: Dictionary = state.current.coach.get(key, {})
	if not entry.is_empty():
		_coach_say(String(entry["speaker"]), String(entry["text"]))


## 案内の1文を、物語のセリフとして出す。セリフなら「」と顔つき、語りなら地の文
func _coach_say(speaker: String, text: String) -> void:
	if not _guided:
		return
	_coach_name.text = speaker
	_coach_name.visible = speaker != ""
	var face: Texture2D = null
	if speaker == "幼なじみ":
		face = Illustrations.find("portraits", SampleData.CHILDHOOD)
	_coach_face.texture = face
	_coach_face.visible = face != null
	_coach_label.text = "「%s」" % text if speaker != "" else text
	_coach_row.modulate = Color(1.0, 1.0, 0.7)
	create_tween().tween_property(_coach_row, "modulate", Color.WHITE, 0.5)


## 会話ボックスを出す。読み終えたら done を呼ぶ（行が無ければ、すぐに呼ぶ）
func _play_dialogue(lines: Array[Dictionary], done: Callable) -> void:
	if lines.is_empty():
		done.call()
		return
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(done)
	_dialogue.setup(lines)


## 結果のあとの会話が終わったら、次の出来事へ。最後なら、冒険を終える
func _after_guided_event() -> void:
	if state.has_next():
		_start_next_event()
	else:
		_finish_first_adventure()


## 報告を読み終えたら、運ぶ言葉と、行き先を、金色に光らせて示す
func _guide_drag() -> void:
	if state.matched or state.current == null:
		return
	_coach("drag")
	var target_id: StringName = &""
	var keyword_id: StringName = &""
	for kw in state.current.keyword_targets:
		keyword_id = StringName(kw)
		target_id = StringName(state.current.keyword_targets[kw])
	for chip in _chips:
		if chip.keyword_id == keyword_id:
			chip.set_guide(true)
			_guided_chips.append(chip)
	var view := _view_for_target(target_id)
	if view == null:
		return
	# 行き先のページを、自動で開く
	for i in _tabs.get_tab_count():
		if _tabs.get_tab_control(i).is_ancestor_of(view):
			_tabs.current_tab = i
	if view.slots.has(target_id):
		_guide_target_slot = view.slots[target_id]
		_guide_target_slot.set_guide(true)
	else:
		_guide_target_view = view
		view.set_guide(true)


## 照合できたとき: ノートの内容を伝え、選ぶ指示を光らせる
func _coach_matched() -> void:
	var matched_entry: Dictionary = state.current.coach.get("matched", {})
	var command_entry: Dictionary = state.current.coach.get("command", {})
	var text := (String(matched_entry.get("text", "")) + "\n" + String(command_entry.get("text", ""))).strip_edges()
	_coach_say(String(matched_entry.get("speaker", "")), text)
	var button := _stat_buttons.get(state.current.required_stat) as Button
	if button != null:
		_guided_button = button
		button.pivot_offset = button.size / 2.0
		_guide_button_tween = create_tween().set_loops()
		_guide_button_tween.tween_property(button, "scale", Vector2(1.14, 1.14), 0.45).set_trans(Tween.TRANS_SINE)
		_guide_button_tween.tween_property(button, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func _clear_guides() -> void:
	for chip in _guided_chips:
		if is_instance_valid(chip):
			chip.set_guide(false)
	_guided_chips.clear()
	if _guide_target_view != null and is_instance_valid(_guide_target_view):
		_guide_target_view.set_guide(false)
	if _guide_target_slot != null and is_instance_valid(_guide_target_slot):
		_guide_target_slot.set_guide(false)
	_guide_target_view = null
	_guide_target_slot = null
	if _guide_button_tween != null:
		_guide_button_tween.kill()
		_guide_button_tween = null
	if _guided_button != null and is_instance_valid(_guided_button):
		_guided_button.scale = Vector2.ONE
	_guided_button = null


func _on_skip_adventure() -> void:
	Sfx.play(&"click")
	_finish_first_adventure()


## 初めての冒険を終えて、続きの場面（プロローグのつづき）へ
func _finish_first_adventure() -> void:
	GameSession.mark_seen(&"first_adventure")
	GameSession.first_adventure_active = false
	GameSession.go_to(get_tree(), PREP_SCENE)
