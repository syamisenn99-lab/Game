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
	# 行が多い依頼でもボタンが押し出されないよう、中身はスクロールできるようにする
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_status_label = UiKit.bold("", UiKit.SIZE_BODY, UiKit.BAD, true)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)
	dispatch_button = UiKit.button("冒険者を派遣する", 21)
	dispatch_button.custom_minimum_size = Vector2(0, 52)
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
		_content.add_child(UiKit.bold("依頼の詳細", UiKit.SIZE_TITLE))
		_content.add_child(UiKit.label("左の掲示板から依頼の紙をクリックすると、ここに詳しい内容が出る。", UiKit.SIZE_BODY, UiKit.INK_SOFT, true))
		_status_label.text = ""
		dispatch_button.visible = false
		return
	var c := controller
	var d := q.def
	var rep_ok := c.is_unlocked(q)
	_content.add_child(UiKit.bold(d.name, UiKit.SIZE_TITLE, UiKit.INK, true))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	_content.add_child(chips)
	chips.add_child(UiKit.job_chip(c.config, d.job))
	if d.repeatable:
		chips.add_child(UiKit.chip("常設", Color("4f6b3a")))
	if q.status == QuestState.Status.IN_PROGRESS:
		chips.add_child(UiKit.chip("受注中・残り%d週" % q.weeks_left, UiKit.INFO))
	elif not rep_ok:
		chips.add_child(UiKit.chip("評判不足", UiKit.BAD))

	# 大事な数字を大きく
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	_content.add_child(stats)
	for stat: Array in [["報酬", "%dG" % d.reward, UiKit.GOLD], ["期間", "%d週" % d.weeks, UiKit.INK], ["難易度", str(d.difficulty), UiKit.INK]]:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", UiKit.box(Color("fbf5e6"), Color("d8c8a6"), 1, 6, 8))
		stats.add_child(cell)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		cell.add_child(v)
		v.add_child(UiKit.label(str(stat[0]), UiKit.SIZE_TINY, UiKit.INK_SOFT))
		v.add_child(UiKit.bold(str(stat[1]), 22, stat[2]))

	_content.add_child(UiKit.heading("依頼文"))
	_content.add_child(UiKit.label(d.description, UiKit.SIZE_BODY, UiKit.INK, true))
	_content.add_child(UiKit.heading("条件"))
	var rows := [["必要評判", "%d（いまの評判 %d）" % [d.required_reputation, c.reputation], UiKit.INK if rep_ok else UiKit.BAD]]
	if q.status == QuestState.Status.IN_PROGRESS:
		var names: Array[String] = []
		for id: String in q.party_ids:
			names.append(c.adventurer(id).def.name)
		rows.append(["パーティ", "、".join(names)])
		rows.append(["支度金", "%dG" % c.config.supply_cost(q.supply_tier)])
	elif d.repeatable:
		rows.append(["掲示期限", "なし（常設）"])
	else:
		var left := c.last_listed_week(q) - c.week
		rows.append(["掲示期限", "今週まで" if left == 0 else "第%d週まで" % c.last_listed_week(q), UiKit.WARN if left == 0 else UiKit.INK])
	if d.reputation_cap >= 0:
		var room := maxi(0, d.reputation_cap - c.reputation)
		rows.append(["評判の上限", "%dまで（いまなら最大 +%d）" % [d.reputation_cap, room], UiKit.INK if room > 0 else UiKit.WARN])
	if d.repeatable and q.times_completed > 0:
		rows.append(["完了した回数", "%d回" % q.times_completed])
	_content.add_child(UiKit.info_grid(rows))
	if d.repeatable:
		_content.add_child(UiKit.label("完了しても掲示板に残り、次の週からまた受けられる（同時に受けられるのは1組だけ）。", UiKit.SIZE_SMALL, UiKit.INFO, true))

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
