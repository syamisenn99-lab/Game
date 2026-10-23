extends PanelContainer
## 上部バー：週・所持金・評判・次の給料日・「週を終える」ボタン。

signal end_week_pressed
signal contract_pressed

var controller: GameController

var _week_caption: Label
var _week_value: Label
var _gold_value: Label
var _reputation_value: Label
var _payday_caption: Label
var _payday_value: Label
var _goal_box: Control
var _goal_value: Label
var contract_button: Button
var end_week_button: Button


func _ready() -> void:
	var bar := UiKit.box(UiKit.BAR, UiKit.WOOD_DARK, 0, 0, 4)
	bar.content_margin_left = 14
	bar.content_margin_right = 10
	add_theme_stylebox_override("panel", bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	var week := _stat(row, "")
	_week_caption = week[0]
	_week_value = week[1]
	_gold_value = _stat(row, "所持金", UiKit.GOLD_BRIGHT)[1]
	_reputation_value = _stat(row, "評判")[1]
	var payday := _stat(row, "")
	_payday_caption = payday[0]
	_payday_value = payday[1]
	var goal := _stat(row, "経営目標")
	_goal_value = goal[1]
	_goal_box = goal[2]
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	contract_button = UiKit.button("契約の見直し", UiKit.SIZE_BODY)
	contract_button.custom_minimum_size = Vector2(140, 44)
	contract_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contract_button.pressed.connect(func() -> void: contract_pressed.emit())
	row.add_child(contract_button)
	end_week_button = UiKit.button("週を終える ▶", UiKit.SIZE_HEADING)
	end_week_button.custom_minimum_size = Vector2(170, 44)
	end_week_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	end_week_button.pressed.connect(func() -> void: end_week_pressed.emit())
	row.add_child(end_week_button)


## 小さな見出しと大きな値の組を作る。[見出し, 値, 箱] を返す
func _stat(row: HBoxContainer, caption: String, color: Color = UiKit.CREAM) -> Array:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	var c := UiKit.label(caption, UiKit.SIZE_TINY, UiKit.CREAM_SOFT)
	v.add_child(c)
	var value := UiKit.bold("", 20, color)
	v.add_child(value)
	return [c, value, v]


func setup(c: GameController) -> void:
	controller = c


func refresh() -> void:
	var c := controller
	_week_caption.text = "%d月目" % c.month()
	_week_value.text = "第%d週" % c.week
	_gold_value.text = "%dG" % c.gold
	_reputation_value.text = str(c.reputation)
	var until := c.weeks_until_payday()
	var payroll := c.payroll()
	if until < 0:
		_payday_caption.text = "給料日"
		_payday_value.text = "もうない"
		_payday_value.add_theme_color_override("font_color", UiKit.CREAM)
	else:
		_payday_caption.text = "次の給料日（第%d週末）" % c.next_payday_week()
		var when := "今週末" if until == 0 else "あと%d週" % until
		var short := c.gold < payroll
		_payday_value.text = "%s・%dG" % [when, payroll] + ("（不足 %dG）" % (payroll - c.gold) if short else "")
		_payday_value.add_theme_color_override("font_color", Color("ff9a8a") if short else UiKit.CREAM)
	_goal_box.visible = c.config.goal_gold > 0
	var rest := c.config.goal_gold - c.gold
	_goal_value.text = "%dG" % c.config.goal_gold + ("（あと%dG）" % rest if rest > 0 else "（達成中）")
	_goal_value.add_theme_color_override("font_color", UiKit.CREAM if rest > 0 else Color("a6e3a1"))
	end_week_button.disabled = c.phase != GameController.Phase.PLANNING
	contract_button.disabled = not c.is_contract_week()
	contract_button.tooltip_text = "月の最初の週だけ見直せる" if contract_button.disabled else "今週は、専属／歩合を切り替えられる"
