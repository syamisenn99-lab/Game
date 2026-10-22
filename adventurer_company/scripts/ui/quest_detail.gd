extends PanelContainer
## 右側の詳細パネル。選んだクエストの情報と「冒険者を派遣する」ボタン。

signal dispatch_requested(quest_id: String)

var controller: GameController
var quest_id: String = ""

var _content: VBoxContainer
var _status_label: Label
var dispatch_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.WOOD_DARK, 6, 2, 18))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content)
	_status_label = UiKit.label("", 15, UiKit.BAD, true)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)
	dispatch_button = UiKit.button("冒険者を派遣する", 20)
	dispatch_button.custom_minimum_size = Vector2(0, 48)
	dispatch_button.pressed.connect(func() -> void: dispatch_requested.emit(quest_id))
	root.add_child(dispatch_button)


func setup(c: GameController) -> void:
	controller = c


func show_quest(id: String) -> void:
	quest_id = id
	refresh()


func refresh() -> void:
	UiKit.clear_children(_content)
	var q := controller.quest(quest_id)
	if q == null or not controller.board_quests().has(q):
		quest_id = ""
		_content.add_child(UiKit.label("依頼の詳細", 22))
		_content.add_child(UiKit.label("左の掲示板から依頼の紙をクリックすると、ここに詳しい内容が出る。", 16, UiKit.INK_SOFT, true))
		_status_label.text = ""
		dispatch_button.visible = false
		return
	var c := controller
	var d := q.def
	_content.add_child(UiKit.label(d.name, 24))
	_content.add_child(HSeparator.new())
	_content.add_child(UiKit.label(d.description, 16, UiKit.INK, true))
	_content.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	var rep_ok := c.is_unlocked(q)
	var rows := [
		["難易度", str(d.difficulty), UiKit.INK],
		["期間", "%d週" % d.weeks, UiKit.INK],
		["報酬", "%dG" % d.reward, UiKit.INK],
		["推奨職業", c.config.job_name(d.job), UiKit.INK],
		["必要評判", "%d（現在 %d）" % [d.required_reputation, c.reputation], UiKit.INK if rep_ok else UiKit.BAD],
	]
	if q.status == QuestState.Status.IN_PROGRESS:
		var names: Array[String] = []
		for id: String in q.party_ids:
			names.append(c.adventurer(id).def.name)
		rows.append(["状態", "受注中（残り%d週）" % q.weeks_left, UiKit.INFO])
		rows.append(["パーティ", "、".join(names), UiKit.INK])
		rows.append(["支度金", "%dG" % c.config.supply_cost(q.supply_tier), UiKit.INK])
	else:
		var left := c.last_listed_week(q) - c.week
		rows.append(["掲示期限", "今週まで" if left == 0 else "第%d週まで" % c.last_listed_week(q), UiKit.INK])
	for row: Array in rows:
		grid.add_child(UiKit.label(str(row[0]), 16, UiKit.INK_SOFT))
		grid.add_child(UiKit.label(str(row[1]), 17, row[2]))

	dispatch_button.visible = q.status == QuestState.Status.POSTED
	var reason := ""
	if q.status == QuestState.Status.POSTED:
		if not rep_ok:
			reason = "評判%dで受注可" % d.required_reputation
		elif c.phase != GameController.Phase.PLANNING:
			reason = "いまは派遣できない"
		elif c.idle_adventurers().is_empty():
			reason = "待機中の冒険者がいない"
	_status_label.text = reason
	dispatch_button.disabled = reason != ""
