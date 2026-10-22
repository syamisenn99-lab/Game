extends Control
## 契約の見直し（月の最初の週だけ）。冒険者ごとに専属／歩合を切り替える。

signal closed

const Portrait := preload("res://scripts/ui/portrait.gd")

var controller: GameController
var _title: Label
var _rows: VBoxContainer
var _summary: Label
var _error_label: Label
var close_button: Button
## 冒険者ID → {"regular": Button, "commission": Button}
var buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	var body := UiKit.make_modal(self, Vector2(940, 600))
	_title = UiKit.label("", 24)
	body.add_child(_title)
	var note := UiKit.label("専属は給料日に月給を払う代わりに、報酬は全部会社のもの。歩合は月給なしで、依頼の報酬から本人の取り分を払う。\n"
		+ "歩合の人は、その月の稼ぎが月給の半分に届かないと不満がたまり、2か月続くと辞める。専属から歩合に切り替えた人は、最初から不満を1つ抱える。",
		14, UiKit.INK_SOFT, true)
	note.custom_minimum_size = Vector2(900, 0)
	body.add_child(note)
	body.add_child(HSeparator.new())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_rows)
	body.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	_summary = UiKit.label("", 17)
	footer.add_child(_summary)
	_error_label = UiKit.label("", 15, UiKit.BAD)
	_error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_error_label)
	close_button = UiKit.button("閉じる", 18)
	close_button.custom_minimum_size = Vector2(160, 46)
	close_button.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	footer.add_child(close_button)


func setup(c: GameController) -> void:
	controller = c


func open() -> void:
	_error_label.text = ""
	_rebuild()
	visible = true


## 雇用形態を変える（テストからも呼べる）
func set_contract(adventurer_id: String, type_id: String) -> void:
	_error_label.text = controller.change_contract(adventurer_id, type_id)
	_rebuild()


func _rebuild() -> void:
	var c := controller
	_title.text = "契約の見直し（%d月目）" % c.month()
	UiKit.clear_children(_rows)
	buttons.clear()
	for a: AdventurerState in c.adventurers:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.box(Color("fbf5e6"), Color("d8c8a6"), 1, 4, 6))
		_rows.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var portrait: Control = Portrait.new()
		portrait.custom_minimum_size = Vector2(48, 58)
		portrait.setup(a.def, c.config.job_name(a.def.job), false, "")
		if a.left:
			portrait.modulate = Color(1, 1, 1, 0.4)
		h.add_child(portrait)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(180, 0)
		h.add_child(info)
		info.add_child(UiKit.label(a.def.name, 17))
		info.add_child(UiKit.label("%s・腕前%d" % [c.config.job_name(a.def.job), a.def.ability], 13, UiKit.INK_SOFT))
		var group := ButtonGroup.new()
		var pair := {}
		for type_id: String in ["regular", "commission"]:
			var text := "専属（月給 %dG）" % a.def.salary if type_id == "regular" else "歩合（取り分 %d%%）" % roundi(a.def.commission_rate * 100)
			var b := UiKit.button(text, 15)
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(190, 44)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.set_pressed_no_signal(a.employment_type == type_id)
			b.disabled = c.contract_error(a.def.id, type_id) != ""
			b.pressed.connect(set_contract.bind(a.def.id, type_id))
			h.add_child(b)
			pair[type_id] = b
		buttons[a.def.id] = pair
		var status := UiKit.label(_status(a), 13, UiKit.BAD if a.left or a.discontent > 0 else UiKit.INK_SOFT, true)
		status.custom_minimum_size = Vector2(240, 0)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(status)
	_summary.text = "次の給料日の支払予定 %dG ／ 所持金 %dG" % [c.payroll(), c.gold]


func _status(a: AdventurerState) -> String:
	var c := controller
	if a.left:
		return "退職した"
	var lines: Array[String] = []
	if a.mission_id != "":
		lines.append("派遣中なので、いまは変えられない")
	if a.is_commission():
		lines.append("今月の稼ぎ %dG（%dG に届かないと不満）" % [a.earned_this_month, c.discontent_threshold(a)])
		if a.discontent > 0:
			lines.append("⚠ 不満 %d／%d（%d になると辞める）" % [a.discontent, c.config.leave_after_months, c.config.leave_after_months])
	elif c.config.discontent_on_switch > 0:
		lines.append("歩合にすると、不満 %d から始まる" % c.config.discontent_on_switch)
	return "\n".join(lines)
