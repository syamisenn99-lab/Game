extends PanelContainer
## 画面下部の会社の名簿。冒険者全員の状態を常に見せる。

var controller: GameController
var _title: Label
var _cards: HBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box(UiKit.BAR, UiKit.WOOD_DARK, 0, 0, 8))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	_title = UiKit.label("", 16, UiKit.CREAM)
	root.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cards)


func setup(c: GameController) -> void:
	controller = c


func refresh() -> void:
	var c := controller
	_title.text = "会社の名簿　（%d人／月給の合計 %dG）" % [c.adventurers.size(), c.payroll()]
	UiKit.clear_children(_cards)
	for a: AdventurerState in c.adventurers:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.WOOD_DARK, 2, 4, 8))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		card.add_child(v)
		var head := HBoxContainer.new()
		head.add_child(UiKit.label(a.def.name, 17))
		head.add_child(UiKit.label("%s　腕前%d" % [c.config.job_name(a.def.job), a.def.ability], 14, UiKit.INK_SOFT))
		v.add_child(head)
		v.add_child(UiKit.label("月給 %dG" % c.salary_for(a), 13, UiKit.INK_SOFT))
		var skill := UiKit.label("%s：%s" % [a.def.skill_name, a.def.skill_description], 12, UiKit.INK, true)
		skill.custom_minimum_size = Vector2(220, 0)
		v.add_child(skill)
		var status := status_text(c, a)
		v.add_child(UiKit.label(status[0], 14, status[1]))
		_cards.add_child(card)


## [表示文, 色]
static func status_text(c: GameController, a: AdventurerState) -> Array:
	match a.status():
		AdventurerState.Status.ON_MISSION:
			var q := c.quest(a.mission_id)
			return ["派遣中（残り%d週）" % q.weeks_left, UiKit.INFO]
		AdventurerState.Status.RESTING:
			return ["休養中（残り%d週）" % a.rest_weeks, UiKit.WARN]
		_:
			return ["待機中", UiKit.GOOD]
