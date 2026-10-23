extends Control
## ゲームの結果画面（クリア／倒産）。

signal restart_requested

var _title: Label
var _reason: Label
var _stats: VBoxContainer
var restart_button: Button


func _ready() -> void:
	visible = false
	var body := UiKit.make_modal(self, Vector2(620, 420))
	_title = UiKit.bold("", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_title)
	_reason = UiKit.label("", 17, UiKit.INK, true)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_reason)
	body.add_child(HSeparator.new())
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 8)
	_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_stats)
	restart_button = UiKit.button("もう一度遊ぶ", 20)
	restart_button.custom_minimum_size = Vector2(220, 50)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(func() -> void:
		visible = false
		restart_requested.emit())
	body.add_child(restart_button)


func open(c: GameController) -> void:
	var cleared := c.phase == GameController.Phase.CLEARED
	var goal := c.goal_reached()
	_title.text = "経営達成！" if goal else ("経営継続（目標未達）" if cleared else "倒産……")
	_title.add_theme_color_override("font_color", UiKit.GOOD if goal else (UiKit.WARN if cleared else UiKit.BAD))
	if goal:
		_reason.text = "%d週を乗り切り、目標の %dG 以上を残した。" % [c.config.total_weeks, c.config.goal_gold]
	elif cleared:
		_reason.text = "%d週を乗り切ったが、所持金は目標の %dG に %dG 届かなかった。" % [c.config.total_weeks, c.config.goal_gold, c.config.goal_gold - c.gold]
	else:
		_reason.text = "第%d週の給料日に、月給 %dG を払えなかった（所持金 %dG）。" % [c.bankrupt_week, c.payroll(), c.gold]
	UiKit.clear_children(_stats)
	for row: Array in [
		["最終所持金", "%dG（目標 %dG）" % [c.gold, c.config.goal_gold]],
		["評判", str(c.reputation)],
		["成功数", "%d件（完了 %d件）" % [c.success_count, c.completed_count]],
		["退職した冒険者", "%d人" % _departed(c)],
	]:
		var h := HBoxContainer.new()
		var name_label := UiKit.label(str(row[0]), 22, UiKit.INK_SOFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_label)
		h.add_child(UiKit.bold(str(row[1]), 26))
		_stats.add_child(h)
	visible = true


func _departed(c: GameController) -> int:
	var n := 0
	for a: AdventurerState in c.adventurers:
		if a.left:
			n += 1
	return n
