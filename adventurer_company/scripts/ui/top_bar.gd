extends PanelContainer
## 上部バー：週・所持金・評判・次の給料日・「週を終える」ボタン。

signal end_week_pressed

var controller: GameController

var _week_label: Label
var _gold_label: Label
var _reputation_label: Label
var _payday_label: Label
var end_week_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box(UiKit.BAR, UiKit.WOOD_DARK, 0, 0, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)
	_week_label = UiKit.label("", 22, UiKit.CREAM)
	_gold_label = UiKit.label("", 20, Color("ffd76a"))
	_reputation_label = UiKit.label("", 20, UiKit.CREAM)
	_payday_label = UiKit.label("", 16, UiKit.CREAM_SOFT)
	for l: Label in [_week_label, _gold_label, _reputation_label, _payday_label]:
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	end_week_button = UiKit.button("週を終える ▶", 18)
	end_week_button.custom_minimum_size = Vector2(150, 0)
	end_week_button.pressed.connect(func() -> void: end_week_pressed.emit())
	row.add_child(end_week_button)


func setup(c: GameController) -> void:
	controller = c


func refresh() -> void:
	var c := controller
	_week_label.text = "第%d週（%d月目）" % [c.week, c.month()]
	_gold_label.text = "所持金 %dG" % c.gold
	_reputation_label.text = "評判 %d" % c.reputation
	var until := c.weeks_until_payday()
	var payroll := c.payroll()
	if until < 0:
		_payday_label.text = "給料日はもうない"
	else:
		var when := "今週末" if until == 0 else "あと%d週" % until
		_payday_label.text = "次の給料日：%s（第%d週末）／支払予定 %dG" % [when, c.next_payday_week(), payroll]
	var short := until >= 0 and c.gold < payroll
	_payday_label.add_theme_color_override("font_color", Color("ff8a7a") if short else UiKit.CREAM_SOFT)
	if short:
		_payday_label.text += "　⚠ 不足 %dG" % (payroll - c.gold)
	end_week_button.disabled = c.phase != GameController.Phase.PLANNING
