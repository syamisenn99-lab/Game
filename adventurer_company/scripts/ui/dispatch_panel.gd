extends Control
## 派遣パネル。冒険者と支度金を選ぶたびに、成功率と5段階の内訳をその場で計算し直す。
## 表示する確率は GameController.preview_modifiers と CheckRules.probabilities から出す（実判定と同じ計算）。

signal dispatched(quest_id: String)
signal closed

const BAR_WIDTH := 170.0
## 右側（成功率の欄）の中身の幅
const RIGHT_WIDTH := 370.0

var controller: GameController
var quest_id: String = ""
var selected_ids: Array[String] = []
var supply_tier: int = 0

var _title: Label
var _subtitle: Label
var _adventurer_box: VBoxContainer
var _checks: Dictionary = {}
var _supply_box: HBoxContainer
var _supply_buttons: Array[Button] = []
var rate_label: Label
var _outcome_rows: Dictionary = {}
var _notes_label: Label
var _modifier_box: VBoxContainer
var _need_label: Label
var _expected_label: Label
var _gold_label: Label
var _error_label: Label
var confirm_button: Button
var cancel_button: Button


func _ready() -> void:
	visible = false
	var body := UiKit.make_modal(self, Vector2(1060, 640))
	_title = UiKit.label("", 24)
	body.add_child(_title)
	_subtitle = UiKit.label("", 16, UiKit.INK_SOFT)
	body.add_child(_subtitle)
	body.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(UiKit.label("冒険者を選ぶ（待機中のみ・1〜3人）", 17))
	_adventurer_box = VBoxContainer.new()
	_adventurer_box.add_theme_constant_override("separation", 4)
	left.add_child(_adventurer_box)
	left.add_child(HSeparator.new())
	left.add_child(UiKit.label("支度金（派遣時に支払う。失敗しても戻らない）", 17))
	_supply_box = HBoxContainer.new()
	_supply_box.add_theme_constant_override("separation", 8)
	left.add_child(_supply_box)
	var group := ButtonGroup.new()
	for tier in 4:
		var b := UiKit.button("", 16)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(130, 44)
		b.pressed.connect(_on_supply_pressed.bind(tier))
		_supply_box.add_child(b)
		_supply_buttons.append(b)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UiKit.box(Color("fbf5e6"), Color("b89f6e"), 2, 6, 14))
	cols.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	right.add_child(rv)
	rv.add_child(UiKit.label("成功率（辛勝以上）", 16, UiKit.INK_SOFT))
	rate_label = UiKit.label("—", 54)
	rv.add_child(rate_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	rv.add_child(grid)
	_notes_label = UiKit.label("", 13, UiKit.INFO, true)
	_notes_label.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	rv.add_child(_notes_label)
	rv.add_child(HSeparator.new())
	rv.add_child(UiKit.label("補正の内訳", 15, UiKit.INK_SOFT))
	_modifier_box = VBoxContainer.new()
	_modifier_box.add_theme_constant_override("separation", 0)
	rv.add_child(_modifier_box)
	_need_label = UiKit.label("", 14, UiKit.INK, true)
	_need_label.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	rv.add_child(_need_label)
	_expected_label = UiKit.label("", 14, UiKit.INK_SOFT, true)
	_expected_label.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	rv.add_child(_expected_label)
	# 5段階の行は setup のあと（設定から段階を読む）に作るので、grid を覚えておく
	set_meta("outcome_grid", grid)

	body.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	_gold_label = UiKit.label("", 17)
	footer.add_child(_gold_label)
	_error_label = UiKit.label("", 15, UiKit.BAD)
	_error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_error_label)
	cancel_button = UiKit.button("キャンセル", 18)
	cancel_button.custom_minimum_size = Vector2(140, 46)
	cancel_button.pressed.connect(close)
	footer.add_child(cancel_button)
	confirm_button = UiKit.button("派遣決定", 18)
	confirm_button.custom_minimum_size = Vector2(160, 46)
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(confirm_button)


func setup(c: GameController) -> void:
	controller = c
	var grid: GridContainer = get_meta("outcome_grid")
	for o: OutcomeDef in c.config.outcomes:
		grid.add_child(UiKit.label(o.name, 15, UiKit.outcome_color(o.id)))
		var track := ColorRect.new()
		track.color = Color("e6dcc4")
		track.custom_minimum_size = Vector2(BAR_WIDTH, 14)
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := ColorRect.new()
		fill.color = UiKit.outcome_color(o.id)
		fill.size = Vector2(0, 14)
		track.add_child(fill)
		grid.add_child(track)
		var pct := UiKit.label("", 15)
		pct.custom_minimum_size = Vector2(70, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(pct)
		_outcome_rows[o.id] = {"fill": fill, "pct": pct}


func open(id: String) -> void:
	quest_id = id
	selected_ids.clear()
	supply_tier = 0
	var c := controller
	var q := c.quest(id)
	_title.text = "派遣：%s" % q.def.name
	_subtitle.text = "難易度 %d ／ 推奨職業 %s ／ 期間 %d週 ／ 報酬 %dG" % [
		q.def.difficulty, c.config.job_name(q.def.job), q.def.weeks, q.def.reward]
	if q.def.reputation_cap >= 0:
		_subtitle.text += " ／ 評判は%dまで（いま %d）" % [q.def.reputation_cap, c.reputation]

	UiKit.clear_children(_adventurer_box)
	_checks.clear()
	for a: AdventurerState in c.adventurers:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.box(Color("fbf5e6"), Color("d8c8a6"), 1, 4, 6))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var check := CheckBox.new()
		check.text = a.def.name
		check.focus_mode = Control.FOCUS_NONE
		check.custom_minimum_size = Vector2(118, 0)
		check.add_theme_font_size_override("font_size", 17)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			check.add_theme_color_override(key, UiKit.INK)
		check.add_theme_color_override("font_disabled_color", Color("9a8f80"))
		check.disabled = not a.is_idle()
		check.toggled.connect(_on_adventurer_toggled.bind(a.def.id))
		h.add_child(check)
		var job_match := a.def.job == q.def.job
		var info := UiKit.label("%s%s・腕前%d" % [c.config.job_name(a.def.job), "★" if job_match else "", a.def.ability], 15, UiKit.INK)
		info.custom_minimum_size = Vector2(118, 0)
		h.add_child(info)
		var skill := UiKit.label("%s：%s" % [a.def.skill_name, a.def.skill_description], 13, UiKit.INK_SOFT, true)
		skill.custom_minimum_size = Vector2(200, 0)
		skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(skill)
		var status: Array = preload("res://scripts/ui/roster_panel.gd").status_text(c, a)
		var status_label := UiKit.label(status[0], 14, status[1])
		status_label.custom_minimum_size = Vector2(120, 0)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(status_label)
		if not a.is_idle():
			row.modulate = Color(1, 1, 1, 0.6)
		_adventurer_box.add_child(row)
		_checks[a.def.id] = check

	for tier in _supply_buttons.size():
		var b := _supply_buttons[tier]
		var visible_tier := tier < c.config.supply_tier_count()
		b.visible = visible_tier
		if visible_tier:
			b.text = "%dG（+%d）" % [c.config.supply_cost(tier), c.config.supply_bonus(tier)]
			b.disabled = c.config.supply_cost(tier) > c.gold
			b.set_pressed_no_signal(tier == 0)
	visible = true
	update_preview()


func close() -> void:
	visible = false
	closed.emit()


## 冒険者を選ぶ（テストやキーボード操作からも呼べる）
func set_adventurer(adventurer_id: String, on: bool) -> void:
	var check: CheckBox = _checks[adventurer_id]
	check.button_pressed = on


func set_supply(tier: int) -> void:
	_supply_buttons[tier].button_pressed = true
	_on_supply_pressed(tier)


func _on_adventurer_toggled(on: bool, adventurer_id: String) -> void:
	if on and not selected_ids.has(adventurer_id):
		if not controller.adventurer(adventurer_id).is_idle() or selected_ids.size() >= controller.config.party_max:
			(_checks[adventurer_id] as CheckBox).set_pressed_no_signal(false)
			return
		selected_ids.append(adventurer_id)
	elif not on:
		selected_ids.erase(adventurer_id)
	update_preview()


func _on_supply_pressed(tier: int) -> void:
	supply_tier = tier
	update_preview()


func update_preview() -> void:
	var c := controller
	var q := c.quest(quest_id)
	var full := selected_ids.size() >= c.config.party_max
	for id: String in _checks:
		var check: CheckBox = _checks[id]
		check.disabled = not c.adventurer(id).is_idle() or (full and not selected_ids.has(id))

	UiKit.clear_children(_modifier_box)
	var cost := c.config.supply_cost(supply_tier)
	_gold_label.text = "所持金 %dG → 派遣後 %dG" % [c.gold, c.gold - cost]
	var error := c.dispatch_error(q, selected_ids, supply_tier)
	_error_label.text = error
	confirm_button.disabled = error != ""

	if selected_ids.is_empty():
		rate_label.text = "—"
		rate_label.add_theme_color_override("font_color", UiKit.INK_SOFT)
		for id: String in _outcome_rows:
			(_outcome_rows[id]["fill"] as ColorRect).size.x = 0
			(_outcome_rows[id]["pct"] as Label).text = "—"
		_notes_label.text = ""
		_modifier_box.add_child(UiKit.label("冒険者を選ぶと、ここに内訳が出る。", 14, UiKit.INK_SOFT))
		_need_label.text = ""
		_expected_label.text = ""
		return

	var mods := c.preview_modifiers(q, selected_ids, supply_tier)
	var table := CheckRules.probabilities(mods, c.config)
	var rate := table.success_rate()
	rate_label.text = UiKit.percent(rate)
	rate_label.add_theme_color_override("font_color", UiKit.rate_color(rate))
	for o: OutcomeDef in c.config.outcomes:
		var r := table.rate(o.id)
		(_outcome_rows[o.id]["fill"] as ColorRect).size.x = BAR_WIDTH * r
		(_outcome_rows[o.id]["pct"] as Label).text = UiKit.percent(r)
	_notes_label.text = "\n".join(mods.notes)

	for item: Dictionary in mods.items:
		var row := HBoxContainer.new()
		var name_label := UiKit.label(str(item["label"]), 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiKit.label(UiKit.signed(int(item["value"])), 14))
		_modifier_box.add_child(row)
	var total_row := HBoxContainer.new()
	var total_name := UiKit.label("合計", 15)
	total_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_name)
	total_row.add_child(UiKit.label(UiKit.signed(mods.total_bonus()), 15))
	_modifier_box.add_child(total_row)

	var success_def := c.config.outcome_by_id(c.config.success_outcome)
	var need := mods.difficulty + success_def.min_diff - mods.total_bonus()
	var die := "d%d" % mods.dice_sides if mods.dice_count == 1 else "d%d（%d回のうち高い方）" % [mods.dice_sides, mods.dice_count]
	if need <= 1:
		_need_label.text = "判定値 = %s %s ／ 難易度 %d → どの目でも%s以上" % [die, UiKit.signed(mods.total_bonus()), mods.difficulty, success_def.name]
	elif need > mods.dice_sides:
		_need_label.text = "判定値 = %s %s ／ 難易度 %d → どの目でも%sに届かない" % [die, UiKit.signed(mods.total_bonus()), mods.difficulty, success_def.name]
	else:
		_need_label.text = "判定値 = %s %s ／ 難易度 %d → 出目 %d 以上で%s以上" % [die, UiKit.signed(mods.total_bonus()), mods.difficulty, need, success_def.name]
	var expected := 0.0
	for o: OutcomeDef in c.config.outcomes:
		expected += table.rate(o.id) * roundi(q.def.reward * o.reward_rate)
	_expected_label.text = "報酬の期待値 約 %dG（支度金 %dG は別）" % [roundi(expected), cost]


func _on_confirm() -> void:
	var error := controller.dispatch(controller.quest(quest_id), selected_ids, supply_tier)
	if error != "":
		_error_label.text = error
		return
	visible = false
	dispatched.emit(quest_id)
	closed.emit()
