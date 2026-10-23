extends Control
## 週の終わりの結果レポート。出目と補正の内訳まで見せる。

signal closed

var _title: Label
var _list: VBoxContainer
var _summary: Label
var next_button: Button


func _ready() -> void:
	visible = false
	var body := UiKit.make_modal(self, Vector2(900, 600))
	_title = UiKit.bold("", 26)
	body.add_child(_title)
	body.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_summary = UiKit.bold("", 17)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_summary)
	next_button = UiKit.button("次へ", 18)
	next_button.custom_minimum_size = Vector2(180, 46)
	next_button.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	footer.add_child(next_button)


func open(c: GameController, report: WeekReport) -> void:
	_title.text = "第%d週の結果" % report.week
	UiKit.clear_children(_list)
	if report.entries.is_empty():
		_list.add_child(UiKit.label("今週、完了した依頼はない。", UiKit.SIZE_HEADING, UiKit.INK_SOFT))
	for entry: QuestReportEntry in report.entries:
		_list.add_child(_entry_panel(c, entry))
	var running: Array[String] = []
	for q: QuestState in c.quests:
		if q.status == QuestState.Status.IN_PROGRESS:
			running.append("%s（残り%d週）" % [q.def.name, q.weeks_left])
	if not running.is_empty():
		_list.add_child(UiKit.bold("進行中：" + "、".join(running), UiKit.SIZE_SMALL, UiKit.INFO, true))
	for event: Dictionary in report.events:
		_list.add_child(UiKit.label(str(event.get("text", event)), 15, UiKit.INK, true))
	_summary.text = "所持金 %dG ／ 評判 %d" % [c.gold, c.reputation]
	next_button.text = "負傷者の対応へ" if not report.injuries.is_empty() else "次へ"
	visible = true


func _entry_panel(c: GameController, e: QuestReportEntry) -> Control:
	var check := e.check
	var color := UiKit.outcome_color(check.outcome.id)
	var panel := PanelContainer.new()
	var style := UiKit.box(Color("fbf5e6"), color, 2, 6, 12)
	style.border_width_left = 8
	panel.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)

	# 見出し：依頼名と結果
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var name_label := UiKit.bold(e.quest_name, 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiKit.chip(check.outcome.name, color, Color.WHITE, 22))
	v.add_child(UiKit.label("パーティ：%s　支度金 %dG" % ["、".join(e.party_names), e.supply_cost], UiKit.SIZE_SMALL, UiKit.INK_SOFT))

	# 計算：出目 ＋ 補正 ＝ 判定値 ／ 難易度 → 差
	var calc := HBoxContainer.new()
	calc.add_theme_constant_override("separation", 10)
	v.add_child(calc)
	var die_text := str(check.used_die)
	if check.dice.size() > 1:
		var dice: Array[String] = []
		for d: int in check.dice:
			dice.append(str(d))
		die_text = "%d（%s の高い方）" % [check.used_die, "・".join(dice)]
	for part: Array in [["出目", die_text, UiKit.INK], ["＋", "", UiKit.INK_SOFT], ["補正", UiKit.signed(check.bonus), UiKit.INK],
			["＝", "", UiKit.INK_SOFT], ["判定値", str(check.total), UiKit.INK], ["／", "", UiKit.INK_SOFT],
			["難易度", str(check.difficulty), UiKit.INK], ["→", "", UiKit.INK_SOFT], ["差", UiKit.signed(check.diff), color]]:
		if part[1] == "":
			var op := UiKit.bold(str(part[0]), UiKit.SIZE_HEADING, part[2])
			op.size_flags_vertical = Control.SIZE_SHRINK_END
			calc.add_child(op)
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		calc.add_child(cell)
		cell.add_child(UiKit.label(str(part[0]), UiKit.SIZE_TINY, UiKit.INK_SOFT))
		cell.add_child(UiKit.bold(str(part[1]), 20, part[2]))
	if check.floored:
		var floored := UiKit.bold("（差では%s → %s止まり）" % [check.raw_outcome.name, check.outcome.name], UiKit.SIZE_SMALL, UiKit.INFO)
		floored.size_flags_vertical = Control.SIZE_SHRINK_END
		calc.add_child(floored)

	# 補正の内訳（小さく）
	var parts: Array[String] = []
	for item: Dictionary in check.modifiers.items:
		parts.append("%s %s" % [item["label"], UiKit.signed(int(item["value"]))])
	var detail := "補正の内訳：" + ("、".join(parts) if not parts.is_empty() else "なし")
	for note: String in check.modifiers.notes:
		detail += "\n" + note
	var detail_label := UiKit.label(detail, UiKit.SIZE_TINY, UiKit.INK_SOFT, true)
	detail_label.custom_minimum_size = Vector2(820, 0)
	v.add_child(detail_label)

	# お金と評判
	var money := HFlowContainer.new()
	money.add_theme_constant_override("h_separation", 8)
	money.add_theme_constant_override("v_separation", 4)
	v.add_child(money)
	var reward_text := "報酬 %dG" % e.reward
	if e.reward > 0:
		reward_text += "（%dG×%d%%）" % [e.base_reward, roundi(check.outcome.reward_rate * 100)]
	money.add_child(UiKit.chip(reward_text, UiKit.GOOD if e.reward > 0 else Color("8a7f70")))
	for one: Dictionary in e.commissions:
		money.add_child(UiKit.chip("歩合 %s −%dG" % [one["name"], int(one["amount"])], UiKit.WARN))
	if not e.commissions.is_empty():
		money.add_child(UiKit.chip("会社の取り分 %dG" % e.company_income, UiKit.GOLD))
	var rep_text := "評判 %s" % UiKit.signed(e.reputation_delta)
	if e.reputation_capped:
		rep_text += "（上限%d）" % c.quest(e.quest_id).def.reputation_cap
	money.add_child(UiKit.chip(rep_text, UiKit.INFO if e.reputation_delta >= 0 else UiKit.BAD))
	if e.injury != null:
		money.add_child(UiKit.chip("%sが%s（休養%d週）" % [e.injury.adventurer_name, e.injury.injury_name, e.injury.rest_weeks], UiKit.BAD))
	return panel
