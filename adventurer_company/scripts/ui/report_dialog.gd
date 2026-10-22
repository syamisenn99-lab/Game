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
	_title = UiKit.label("", 26)
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
	_summary = UiKit.label("", 17)
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
		_list.add_child(UiKit.label("今週、完了した依頼はない。", 18, UiKit.INK_SOFT))
	for entry: QuestReportEntry in report.entries:
		_list.add_child(_entry_panel(c, entry))
	var running: Array[String] = []
	for q: QuestState in c.quests:
		if q.status == QuestState.Status.IN_PROGRESS:
			running.append("%s（残り%d週）" % [q.def.name, q.weeks_left])
	if not running.is_empty():
		_list.add_child(UiKit.label("進行中：" + "、".join(running), 15, UiKit.INFO, true))
	for event: Dictionary in report.events:
		_list.add_child(UiKit.label(str(event.get("text", event)), 15, UiKit.INK, true))
	_summary.text = "所持金 %dG ／ 評判 %d" % [c.gold, c.reputation]
	next_button.text = "負傷者の対応へ" if not report.injuries.is_empty() else "次へ"
	visible = true


func _entry_panel(c: GameController, e: QuestReportEntry) -> Control:
	var check := e.check
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color("fbf5e6"), UiKit.outcome_color(check.outcome.id), 2, 6, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)

	var head := HBoxContainer.new()
	var name_label := UiKit.label(e.quest_name, 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiKit.label(check.outcome.name, 26, UiKit.outcome_color(check.outcome.id)))
	v.add_child(head)
	v.add_child(UiKit.label("パーティ：%s ／ 支度金 %dG" % ["、".join(e.party_names), e.supply_cost], 15, UiKit.INK_SOFT))

	var dice_text := "出目：%d" % check.used_die
	if check.dice.size() > 1:
		var dice: Array[String] = []
		for d: int in check.dice:
			dice.append(str(d))
		dice_text = "出目：%s → 高い方の %d を採用" % [" と ".join(dice), check.used_die]
	v.add_child(UiKit.label(dice_text, 16))

	var parts: Array[String] = []
	for item: Dictionary in check.modifiers.items:
		parts.append("%s %s" % [item["label"], UiKit.signed(int(item["value"]))])
	v.add_child(UiKit.label("補正：%s ＝ %s" % ["、".join(parts) if not parts.is_empty() else "なし", UiKit.signed(check.bonus)], 15, UiKit.INK, true))
	for note: String in check.modifiers.notes:
		v.add_child(UiKit.label(note, 13, UiKit.INFO, true))

	var calc := "判定値 %d（%d %s）− 難易度 %d ＝ 差 %s → %s" % [
		check.total, check.used_die, UiKit.signed(check.bonus), check.difficulty, UiKit.signed(check.diff), check.raw_outcome.name]
	if check.floored:
		calc += " → %s止まり" % check.outcome.name
	v.add_child(UiKit.label(calc, 16))

	var money := "報酬 %dG" % e.reward
	if e.reward > 0:
		money += "（基本 %dG × %d%%）" % [e.base_reward, roundi(check.outcome.reward_rate * 100)]
	money += " ／ 評判 %s" % UiKit.signed(e.reputation_delta)
	v.add_child(UiKit.label(money, 17, UiKit.GOOD if e.reward > 0 else UiKit.BAD))
	if e.injury != null:
		v.add_child(UiKit.label("負傷：%sが%s（休養%d週）" % [e.injury.adventurer_name, e.injury.injury_name, e.injury.rest_weeks], 16, UiKit.WARN))
	return panel
