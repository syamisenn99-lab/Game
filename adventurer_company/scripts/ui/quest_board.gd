extends Control
## 左側の掲示板。木の板の上に依頼の紙を並べる。

signal quest_selected(quest_id: String)
signal adventurer_dropped(quest_id: String, adventurer_id: String)

const QuestPaper := preload("res://scripts/ui/quest_paper.gd")

var controller: GameController
var _grid: GridContainer
var _empty_label: Label


func _ready() -> void:
	clip_contents = true
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", UiKit.box(UiKit.WOOD, UiKit.WOOD_DARK, 8, 2, 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# 板の継ぎ目
	for i in range(1, 8):
		var seam := ColorRect.new()
		seam.color = Color("5f3f22")
		seam.set_anchors_preset(Control.PRESET_TOP_WIDE)
		seam.offset_left = 8
		seam.offset_right = -8
		seam.offset_top = i * 64
		seam.offset_bottom = i * 64 + 3
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(seam)

	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UiKit.box(UiKit.WOOD_DARK, Color("2e1d0e"), 2, 4, 6))
	plaque.position = Vector2(20, 12)
	plaque.add_child(UiKit.label("冒険者ギルド　依頼掲示板", 18, UiKit.CREAM))
	add_child(plaque)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 52
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)

	_empty_label = UiKit.label("いま掲示されている依頼はない。", 18, UiKit.CREAM)
	_empty_label.position = Vector2(40, 90)
	add_child(_empty_label)


func setup(c: GameController) -> void:
	controller = c


func refresh(selected_id: String) -> void:
	UiKit.clear_children(_grid)
	var list := controller.board_quests()
	_empty_label.visible = list.is_empty()
	for q: QuestState in list:
		var paper := QuestPaper.new()
		paper.setup(controller, q, q.def.id == selected_id)
		paper.pressed.connect(func(id: String) -> void: quest_selected.emit(id))
		paper.adventurer_dropped.connect(func(id: String, adventurer_id: String) -> void: adventurer_dropped.emit(id, adventurer_id))
		_grid.add_child(paper)
