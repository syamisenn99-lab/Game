extends Control
## 負傷者が出たときの選択：医療費を負担するか。

signal closed

var controller: GameController
var _case: InjuryCase
var _text: Label
var _note: Label
var pay_button: Button
var skip_button: Button


func _ready() -> void:
	visible = false
	var body := UiKit.make_modal(self, Vector2(640, 300))
	body.add_child(UiKit.bold("負傷者が出た", UiKit.SIZE_TITLE, UiKit.BAD))
	body.add_child(HSeparator.new())
	_text = UiKit.bold("", 18, UiKit.INK, true)
	body.add_child(_text)
	_note = UiKit.label("", UiKit.SIZE_BODY, UiKit.INK_SOFT, true)
	body.add_child(_note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	pay_button = UiKit.button("", 17)
	pay_button.custom_minimum_size = Vector2(330, 52)
	pay_button.pressed.connect(_decide.bind(true))
	row.add_child(pay_button)
	skip_button = UiKit.button("負担しない", 17)
	skip_button.custom_minimum_size = Vector2(180, 52)
	skip_button.pressed.connect(_decide.bind(false))
	row.add_child(skip_button)


func setup(c: GameController) -> void:
	controller = c


func open(case: InjuryCase) -> void:
	_case = case
	var cfg := controller.config
	_text.text = "%sが「%s」で%sを負った。休養%d週（そのあいだ派遣できない）。" % [
		case.adventurer_name, case.quest_name, case.injury_name, case.rest_weeks]
	pay_button.text = "医療費 %dG を負担する（休養 −%d週・評判 +%d）" % [
		cfg.medical_cost, cfg.medical_rest_reduction, cfg.medical_reputation]
	pay_button.disabled = not controller.can_pay_medical()
	var note := "所持金 %dG ／ 次の給料日の支払予定 %dG" % [controller.gold, controller.payroll()]
	if pay_button.disabled:
		note += "\n所持金が足りないので、医療費は払えない。"
	_note.text = note
	visible = true


func _decide(pay: bool) -> void:
	if controller.decide_injury(_case, pay) != "":
		return
	visible = false
	closed.emit()
