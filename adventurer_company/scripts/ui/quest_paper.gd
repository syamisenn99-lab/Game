extends Control
## 掲示板に貼られた依頼の紙1枚。少し傾いた紙に、名前・報酬・期間を書く。受注中はスタンプを押す。

signal pressed(quest_id: String)

const SLOT_SIZE := Vector2(240, 150)
const PAPER_SIZE := Vector2(214, 128)
## 常設依頼の紙の色（ギルドが貼りっぱなしにしている少し古びた紙）
const STANDING_PAPER := Color("dfe3cf")

var quest_id: String = ""
var _paper: Panel
var _stamp: Label
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(c: GameController, q: QuestState, selected: bool) -> void:
	quest_id = q.def.id
	var locked := q.status == QuestState.Status.POSTED and not c.is_unlocked(q)
	var in_progress := q.status == QuestState.Status.IN_PROGRESS

	_paper = Panel.new()
	_paper.size = PAPER_SIZE
	_paper.position = (SLOT_SIZE - PAPER_SIZE) / 2
	_paper.pivot_offset = PAPER_SIZE / 2
	_paper.rotation_degrees = float(hash(quest_id) % 7 - 3) * 0.9
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = UiKit.box(STANDING_PAPER if q.def.repeatable else UiKit.PAPER, Color("b89f6e"), 1, 2, 0)
	_style.shadow_color = Color(0, 0, 0, 0.35)
	_style.shadow_size = 4
	_style.shadow_offset = Vector2(2, 3)
	if selected:
		_style.border_color = Color("e0b84f")
		_style.set_border_width_all(4)
	_paper.add_theme_stylebox_override("panel", _style)
	add_child(_paper)

	var pin := Panel.new()
	pin.size = Vector2(12, 12)
	pin.position = Vector2(PAPER_SIZE.x / 2 - 6, 4)
	pin.add_theme_stylebox_override("panel", UiKit.box(Color("a3302a"), Color("5a1410"), 1, 6, 0))
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(pin)

	var text := VBoxContainer.new()
	text.position = Vector2(12, 18)
	text.size = PAPER_SIZE - Vector2(24, 24)
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(text)
	var title := UiKit.label(q.def.name, 16, UiKit.INK, true)
	title.custom_minimum_size = Vector2(PAPER_SIZE.x - 24, 0)
	text.add_child(title)
	text.add_child(UiKit.label("報酬 %dG　期間 %d週" % [q.def.reward, q.def.weeks], 14, UiKit.INK_SOFT))
	text.add_child(UiKit.label("推奨：%s　難易度 %d" % [c.config.job_name(q.def.job), q.def.difficulty], 13, UiKit.INK_SOFT))
	if locked:
		text.add_child(UiKit.label("評判%dで受注可" % q.def.required_reputation, 14, UiKit.BAD))
	elif in_progress:
		text.add_child(UiKit.label("残り%d週" % q.weeks_left, 14, UiKit.INFO))
	elif q.def.repeatable:
		var cap_text := "評判は%dまで上がる" % q.def.reputation_cap if q.def.reputation_cap >= 0 else "何度でも受けられる"
		text.add_child(UiKit.label(cap_text, 13, UiKit.INK_SOFT))
	else:
		var left := c.last_listed_week(q) - c.week
		text.add_child(UiKit.label("掲示は今週まで" if left == 0 else "掲示あと%d週" % (left + 1), 13, UiKit.INK_SOFT))

	if q.def.repeatable:
		var badge := UiKit.label("常設", 12, UiKit.CREAM)
		badge.add_theme_stylebox_override("normal", UiKit.box(Color("4f6b3a"), Color("2f4520"), 1, 3, 3))
		badge.position = Vector2(PAPER_SIZE.x - 44, 6)
		_paper.add_child(badge)

	if locked:
		_paper.modulate = Color(0.62, 0.62, 0.62)
	if in_progress:
		_stamp = UiKit.label("受注中", 26, UiKit.STAMP_RED)
		var stamp_box := UiKit.box(Color(1, 1, 1, 0), UiKit.STAMP_RED, 3, 4, 4)
		stamp_box.content_margin_left = 8
		stamp_box.content_margin_right = 8
		_stamp.add_theme_stylebox_override("normal", stamp_box)
		_stamp.modulate = Color(1, 1, 1, 0.85)
		_stamp.position = Vector2(PAPER_SIZE.x - 108, PAPER_SIZE.y - 50)
		_stamp.rotation_degrees = -14
		_paper.add_child(_stamp)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(quest_id)
		accept_event()
