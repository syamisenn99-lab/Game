class_name MatchingScreen
extends Control
## 探索フェーズの照合画面。報告（タイプライター表示）→ 照合ドロップ → 能力値を選んで指示 → ダイス判定。
## ロジックは MatchingState に任せ、ここは表示と入力の橋渡しだけを行う。

enum Phase { REPORTING, ROLLING, RESULT, SUMMARY }

const PAGE_TITLES := {&"plants": "植物", &"monsters": "魔物", &"traps": "罠"}

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


func _ready() -> void:
	rng.randomize()
	_build_ui()
	var entries := SampleData.entries()
	_entries = entries
	state = MatchingState.new(SampleData.adventurer(), SampleData.events(), entries)
	_name_label.text = "通信中: %s" % state.adventurer.display_name
	_build_notebook()
	_start_next_event()


func _process(delta: float) -> void:
	if _phase != Phase.REPORTING:
		return
	_advance_typewriter(delta)
	if state.tick(delta):
		_line_label.text = "（時間切れ…！ 指示が間に合わなかった）"
		_resolve(&"")
	_update_timer_ui()


# ---------------------------------------------------------------- 画面構築

func _build_ui() -> void:
	var th := Theme.new()
	th.default_font_size = 22
	th.set_color("font_color", "Label", Palette.INK)
	# 机の上の道具らしい配色（コントラストを確保する）
	th.set_stylebox("normal", "Button", Palette.box(Palette.INK, Palette.INK, 0, 6, 8.0))
	th.set_stylebox("hover", "Button", Palette.box(Color("4a3a2c"), Palette.HILITE_BG, 2, 6, 8.0))
	th.set_stylebox("pressed", "Button", Palette.box(Color("1c150f"), Palette.HILITE_BG, 2, 6, 8.0))
	th.set_stylebox("disabled", "Button", Palette.box(Palette.PAPER_DIM, Palette.INK_FAINT, 1, 6, 8.0))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(key, "Button", Palette.DESK_TEXT)
	th.set_color("font_disabled_color", "Button", Palette.INK_FAINT)
	th.set_stylebox("background", "ProgressBar", Palette.box(Color("24190f"), Color.TRANSPARENT, 0, 6, 0.0))
	th.set_stylebox("fill", "ProgressBar", Palette.box(Palette.HILITE_BG, Color.TRANSPARENT, 0, 6, 0.0))
	theme = th

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
	log_title.text = "通信ログ（声だけが届く）"
	log_title.add_theme_color_override("font_color", Palette.INK_FAINT)
	log_vbox.add_child(log_title)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_vbox.add_child(_log_box)
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
	bottom.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK_FAINT, 2, 6, 12.0))
	root.add_child(bottom)
	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 8)
	bottom.add_child(bvbox)

	var cmd := HBoxContainer.new()
	cmd.add_theme_constant_override("separation", 10)
	bvbox.add_child(cmd)
	var cmd_label := Label.new()
	cmd_label.text = "指示（どの力で切り抜ける？）:"
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
	_next_button.pressed.connect(_start_next_event)
	cmd.add_child(_next_button)

	_line_label = Label.new()
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(0, 30)
	bvbox.add_child(_line_label)
	_dice_label = Label.new()
	_dice_label.add_theme_color_override("font_color", Palette.INK_FAINT)
	bvbox.add_child(_dice_label)


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


# ---------------------------------------------------------------- イベント進行

func _start_next_event() -> void:
	if not state.begin_next_event():
		_show_summary()
		return
	_phase = Phase.REPORTING
	_selected_chip = null
	for view: NoteEntryView in _entry_views.values():
		view.show_stamp(false)
	_build_report()
	_line_label.text = "（声に耳をすます…）"
	_dice_label.text = ""
	_next_button.visible = false
	_set_stat_buttons_enabled(true)
	_event_label.text = "イベント %d / %d" % [state.event_index + 1, state.events.size()]
	_reward_label.text = "持ち帰り報酬: %d" % int(state.reward)
	_timer_bar.max_value = state.current.time_limit
	_update_timer_ui()


func _build_report() -> void:
	for child in _log_box.get_children():
		_log_box.remove_child(child)
		child.queue_free()
	_report_nodes.clear()
	_chips.clear()
	_revealed = 0.0
	_total_chars = 0

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


func _advance_typewriter(delta: float) -> void:
	if _revealed >= _total_chars:
		return
	_revealed = minf(float(_total_chars), _revealed + Rules.CHARS_PER_SEC * delta)
	_apply_reveal()


func _reveal_all() -> void:
	_revealed = float(_total_chars)
	_apply_reveal()


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
	_timer_bar.value = state.time_left
	_time_label.text = "%.1f" % state.time_left
	var low := state.time_left < state.current.time_limit * 0.3
	_timer_bar.modulate = Color(1.0, 0.55, 0.5) if low else Color.WHITE


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
			if view != null:
				view.show_stamp(true)
				view.flash(Color(0.7, 1.0, 0.75))
				if state.is_blank(target_id) and view.slots.has(target_id):
					(view.slots[target_id] as BlankSlot).set_filled(true)
		MatchingState.DropResult.MISMATCH:
			_line_label.text = "うーん、ここじゃない気がする…（時間が %.1f 秒減った）" % Rules.MISMATCH_PENALTY_SEC
			if view != null:
				view.flash(Color(1.0, 0.6, 0.6))
			_update_timer_ui()


func _view_for_target(target_id: StringName) -> NoteEntryView:
	var entry_id: StringName = state.blank_owner.get(target_id, target_id)
	return _entry_views.get(entry_id, null)


func _on_stat_chosen(stat: StringName) -> void:
	_resolve(stat)


# ---------------------------------------------------------------- 判定

func _resolve(chosen: StringName) -> void:
	if _phase != Phase.REPORTING:
		return
	_phase = Phase.ROLLING
	_reveal_all()
	_deselect_chip()
	for chip in _chips:
		chip.set_enabled(false)
	_set_stat_buttons_enabled(false)
	var res := state.resolve(chosen, rng)
	for i in 10:
		_dice_label.text = "d20 ... %d" % rng.randi_range(1, Rules.DICE_SIDES)
		await get_tree().create_timer(0.06).timeout
	_dice_label.text = _format_result(res)
	_line_label.text = state.current.success_text if res["success"] else state.current.fail_text
	if res["crit_fail"]:
		_line_label.text += "（大失敗…！）"
	_reward_label.text = "持ち帰り報酬: %d" % int(state.reward)
	_next_button.text = "次へ" if state.has_next() else "探索を終える"
	_next_button.visible = true
	_phase = Phase.RESULT


func _format_result(res: Dictionary) -> String:
	var stat_name: String = Rules.STAT_LABELS.get(res["chosen"], "無指示")
	return "判定: d20=%d + %s%d = %d  /  目標 %d（基準%d %+d）→ %s" % [
		res["roll"], stat_name, res["stat_value"], res["total"],
		res["target"], res["base_target"], res["modifier"],
		"成功！" if res["success"] else "失敗…",
	]


func _show_summary() -> void:
	_phase = Phase.SUMMARY
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
	var total := Label.new()
	total.text = "持ち帰り報酬: %d / %d" % [int(state.reward), int(Rules.INITIAL_REWARD)]
	total.add_theme_font_size_override("font_size", 26)
	vbox.add_child(total)
	var again := Button.new()
	again.text = "もう一度"
	again.custom_minimum_size = Vector2(0, 44)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vbox.add_child(again)
