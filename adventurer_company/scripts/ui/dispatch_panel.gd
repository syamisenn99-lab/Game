extends Control
## 派遣パネル。冒険者のポートレートをパーティ枠へドラッグ（またはクリック）し、支度金を選ぶ。
## 選ぶたびに、成功率と5段階の内訳をその場で計算し直す。
## 表示する確率は GameController.preview_modifiers と CheckRules.probabilities から出す（実判定と同じ計算）。

signal dispatched(quest_id: String)
signal closed

const BAR_WIDTH := 170.0
## 右側（成功率の欄）の中身の幅
const RIGHT_WIDTH := 370.0
const Portrait := preload("res://scripts/ui/portrait.gd")
const DropTarget := preload("res://scripts/ui/drop_target.gd")

var controller: GameController
var quest_id: String = ""
## パーティ枠（空きは ""）。selected_ids はこれを左から詰めたもの
var slots: Array[String] = []
var selected_ids: Array[String] = []
var supply_tier: int = 0

var _title: Label
var _subtitle: Label
var _slot_box: HBoxContainer
var _pool_box: HBoxContainer
var _hint_label: Label
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
	left.add_child(UiKit.label("パーティ（ポートレートをここへドラッグ・1〜3人）", 17))
	_slot_box = HBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 10)
	left.add_child(_slot_box)
	left.add_child(UiKit.label("冒険者（待機中の人をドラッグ、またはクリックで出し入れ）", 15, UiKit.INK_SOFT))
	var pool: Control = DropTarget.new()
	pool.setup(UiKit.box(Color("efe5cc"), Color("d8c8a6"), 1, 6, 6), UiKit.box(Color("f6edd6"), Color("c9a24a"), 2, 6, 6),
		func(data: Variant) -> bool: return Portrait.is_adventurer_drag(data) and data["source"] == "slot",
		func(data: Variant) -> void: remove_adventurer(str(data["id"])))
	left.add_child(pool)
	_pool_box = HBoxContainer.new()
	_pool_box.add_theme_constant_override("separation", 8)
	pool.add_child(_pool_box)
	_hint_label = UiKit.label("", 13, UiKit.INK_SOFT, true)
	_hint_label.custom_minimum_size = Vector2(600, 36)
	left.add_child(_hint_label)
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


func open(id: String, preset_ids: Array[String] = []) -> void:
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

	slots.clear()
	for i in c.config.party_max:
		slots.append("")
	_hint_label.text = "ポートレートにマウスを乗せると、スキルの説明が出る。"
	_rebuild_party()

	for tier in _supply_buttons.size():
		var b := _supply_buttons[tier]
		var visible_tier := tier < c.config.supply_tier_count()
		b.visible = visible_tier
		if visible_tier:
			b.text = "%dG（+%d）" % [c.config.supply_cost(tier), c.config.supply_bonus(tier)]
			b.disabled = c.config.supply_cost(tier) > c.gold
			b.set_pressed_no_signal(tier == 0)
	for adventurer_id: String in preset_ids:
		add_adventurer(adventurer_id)
	visible = true
	update_preview()


func close() -> void:
	visible = false
	closed.emit()


## 冒険者を選ぶ・外す（テストなどからも呼べる）
func set_adventurer(adventurer_id: String, on: bool) -> void:
	if on:
		add_adventurer(adventurer_id)
	else:
		remove_adventurer(adventurer_id)


func set_supply(tier: int) -> void:
	_supply_buttons[tier].button_pressed = true
	_on_supply_pressed(tier)


## 空いている枠に入れる。入れられなければ false
func add_adventurer(adventurer_id: String) -> bool:
	if slots.has(adventurer_id):
		return true
	var index := slots.find("")
	if index < 0:
		return false
	return place_adventurer(adventurer_id, index)


## 指定の枠に置く。枠に別の人がいれば、パーティ内の移動なら入れ替え、外から来たならその人を外す
func place_adventurer(adventurer_id: String, index: int) -> bool:
	if not can_place(adventurer_id) or index < 0 or index >= slots.size():
		return false
	var from := slots.find(adventurer_id)
	if from == index:
		return true
	if from >= 0:
		slots[from] = slots[index]
	slots[index] = adventurer_id
	_rebuild_party()
	update_preview()
	return true


func remove_adventurer(adventurer_id: String) -> void:
	var index := slots.find(adventurer_id)
	if index < 0:
		return
	slots[index] = ""
	_rebuild_party()
	update_preview()


## 派遣パネルに置ける冒険者か（待機中のみ）
func can_place(adventurer_id: String) -> bool:
	var a := controller.adventurer(adventurer_id)
	return a != null and a.is_idle()


func _toggle(adventurer_id: String) -> void:
	if slots.has(adventurer_id):
		remove_adventurer(adventurer_id)
	else:
		add_adventurer(adventurer_id)


func _show_hint(adventurer_id: String) -> void:
	var d := controller.adventurer(adventurer_id).def
	_hint_label.text = "%s（%s・腕前%d・月給%dG）　%s：%s" % [
		d.name, controller.config.job_name(d.job), d.ability, d.salary, d.skill_name, d.skill_description]


func _make_portrait(a: AdventurerState, size: Vector2, can_drag: bool, from: String) -> Control:
	var p: Control = Portrait.new()
	p.custom_minimum_size = size
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.setup(a.def, controller.config.job_name(a.def.job), can_drag, from)
	p.hovered.connect(_show_hint)
	return p


## パーティ枠と冒険者一覧を作り直す
func _rebuild_party() -> void:
	var c := controller
	var q := c.quest(quest_id)
	selected_ids.clear()
	for id: String in slots:
		if id != "":
			selected_ids.append(id)

	UiKit.clear_children(_slot_box)
	for i in slots.size():
		var slot: Control = DropTarget.new()
		slot.custom_minimum_size = Vector2(186, 104)
		slot.setup(UiKit.box(Color("fbf5e6"), Color("b89f6e"), 2, 6, 8), UiKit.box(Color("fff6dc"), Color("c9a24a"), 3, 6, 8),
			func(data: Variant) -> bool: return Portrait.is_adventurer_drag(data) and can_place(str(data["id"])),
			func(data: Variant) -> void: place_adventurer(str(data["id"]), i))
		_slot_box.add_child(slot)
		if slots[i] == "":
			var empty := UiKit.label("空き\nここにドラッグ", 14, Color("a8987a"))
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(empty)
			continue
		var a := c.adventurer(slots[i])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(h)
		var p := _make_portrait(a, Vector2(66, 80), true, "slot")
		p.clicked.connect(remove_adventurer)
		h.add_child(p)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		v.add_child(UiKit.label(a.def.name, 16))
		var job_match := a.def.job == q.def.job
		v.add_child(UiKit.label("%s%s・腕前%d" % [c.config.job_name(a.def.job), "★" if job_match else "", a.def.ability], 13, UiKit.INK))
		v.add_child(UiKit.label(a.def.skill_name, 13, UiKit.INFO))

	UiKit.clear_children(_pool_box)
	for a: AdventurerState in c.adventurers:
		var in_party := slots.has(a.def.id)
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(108, 0)
		card.add_theme_constant_override("separation", 0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pool_box.add_child(card)
		var p := _make_portrait(a, Vector2(76, 88), a.is_idle() and not in_party, "pool")
		p.clicked.connect(func(id: String) -> void:
			if can_place(id):
				_toggle(id))
		card.add_child(p)
		var name_label := UiKit.label(a.def.name, 15)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_label)
		var job_match := a.def.job == q.def.job
		var job_label := UiKit.label("%s%s・腕前%d" % [c.config.job_name(a.def.job), "★" if job_match else "", a.def.ability], 12, UiKit.INK)
		job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(job_label)
		var status: Array = ["パーティにいる", UiKit.INFO] if in_party else preload("res://scripts/ui/roster_panel.gd").status_text(c, a)
		var status_label := UiKit.label(status[0], 12, status[1])
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(status_label)
		if in_party or not a.is_idle():
			p.modulate = Color(1, 1, 1, 0.45)


func _on_supply_pressed(tier: int) -> void:
	supply_tier = tier
	update_preview()


func update_preview() -> void:
	var c := controller
	var q := c.quest(quest_id)
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
