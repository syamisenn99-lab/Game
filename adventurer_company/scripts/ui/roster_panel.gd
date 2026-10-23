extends PanelContainer
## 画面下部の会社の名簿。冒険者全員の状態を常に見せる。
## 待機中の冒険者のポートレートは、掲示板の依頼の紙へドラッグして派遣パネルを開ける。

const Portrait := preload("res://scripts/ui/portrait.gd")

var controller: GameController
var _title: Label
var _cards: HBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box(UiKit.BAR, UiKit.WOOD_DARK, 0, 0, 8))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	_title = UiKit.bold("", UiKit.SIZE_BODY, UiKit.CREAM)
	root.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cards)


func setup(c: GameController) -> void:
	controller = c


func refresh() -> void:
	var c := controller
	_title.text = "会社の名簿　%d人・給料日の支払い %dG　（名前にマウスを乗せるとスキルの説明、ポートレートは依頼の紙へドラッグできる）" % [c.adventurers.size(), c.payroll()]
	UiKit.clear_children(_cards)
	for a: AdventurerState in c.adventurers:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.WOOD_DARK, 2, 4, 6))
		card.tooltip_text = "%s：%s" % [a.def.skill_name, a.def.skill_description]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(h)
		var portrait: Control = Portrait.new()
		portrait.custom_minimum_size = Vector2(64, 80)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.setup(a.def, c.config.job_name(a.def.job), a.is_idle() and c.phase == GameController.Phase.PLANNING, "roster")
		h.add_child(portrait)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_row)
		name_row.add_child(UiKit.bold(a.def.name, 17))
		var job_row := HBoxContainer.new()
		job_row.add_theme_constant_override("separation", 6)
		job_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(job_row)
		job_row.add_child(UiKit.job_chip(c.config, a.def.job, false, UiKit.SIZE_TINY))
		job_row.add_child(UiKit.label("腕前%d・%s" % [a.def.ability, a.def.skill_name], UiKit.SIZE_SMALL, UiKit.INK))
		if a.is_commission():
			v.add_child(UiKit.bold(contract_text(c, a), UiKit.SIZE_SMALL, UiKit.INFO))
		else:
			v.add_child(UiKit.label(contract_text(c, a), UiKit.SIZE_SMALL, UiKit.INK_SOFT))
		var status := status_text(c, a)
		v.add_child(UiKit.chip(status[0], status[1], Color.WHITE, UiKit.SIZE_TINY))
		if a.is_commission() and a.discontent > 0 and not a.left:
			var last_chance := a.discontent + 1 >= c.config.leave_after_months
			name_row.add_child(UiKit.chip("⚠不満%d" % a.discontent, UiKit.BAD, Color.WHITE, UiKit.SIZE_TINY))
			card.tooltip_text += "\n不満%d：%s" % [a.discontent,
				"今月 %dG 稼げないと辞める" % c.discontent_threshold(a) if last_chance else "稼ぎが足りない月が続くと辞める"]
		if a.left:
			card.modulate = Color(1, 1, 1, 0.5)
		_cards.add_child(card)


## 契約の表示（例：「専属・月給90G」「歩合38%・今月30G」）
static func contract_text(c: GameController, a: AdventurerState) -> String:
	if a.is_commission():
		return "%s%d%%・今月%dG" % [c.config.employment_name("commission"), roundi(a.def.commission_rate * 100), a.earned_this_month]
	return "%s・月給%dG" % [c.config.employment_name("regular"), a.def.salary]


## [表示文, 色]
static func status_text(c: GameController, a: AdventurerState) -> Array:
	match a.status():
		AdventurerState.Status.LEFT:
			return ["退職", UiKit.BAD]
		AdventurerState.Status.ON_MISSION:
			var q := c.quest(a.mission_id)
			return ["派遣中・残り%d週" % q.weeks_left, UiKit.INFO]
		AdventurerState.Status.RESTING:
			return ["休養中・残り%d週" % a.rest_weeks, UiKit.WARN]
		_:
			return ["待機中", UiKit.GOOD]
