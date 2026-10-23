extends Control
## 掲示板に貼られた依頼の紙1枚。少し傾いた紙に、名前・報酬・期間を書く。受注中はスタンプを押す。

signal pressed(quest_id: String)
## 名簿のポートレートがこの紙に落とされた
signal adventurer_dropped(quest_id: String, adventurer_id: String)

const Portrait := preload("res://scripts/ui/portrait.gd")

const SLOT_SIZE := Vector2(240, 146)
const PAPER_SIZE := Vector2(216, 134)
## 常設依頼の紙の色（ギルドが貼りっぱなしにしている少し古びた紙）
const STANDING_PAPER := Color("dfe3cf")
## 評判が足りない依頼の紙の色
const LOCKED_PAPER := Color("cfc8ba")

var quest_id: String = ""
var _controller: GameController
var _border_color: Color
var _border_width: int
var _paper: Panel
var _stamp: Label
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(c: GameController, q: QuestState, selected: bool) -> void:
	quest_id = q.def.id
	_controller = c
	var locked := q.status == QuestState.Status.POSTED and not c.is_unlocked(q)
	var in_progress := q.status == QuestState.Status.IN_PROGRESS

	_paper = Panel.new()
	_paper.size = PAPER_SIZE
	_paper.position = (SLOT_SIZE - PAPER_SIZE) / 2
	_paper.pivot_offset = PAPER_SIZE / 2
	_paper.rotation_degrees = float(hash(quest_id) % 7 - 3) * 0.9
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_color := STANDING_PAPER if q.def.repeatable else UiKit.PAPER
	if locked:
		paper_color = LOCKED_PAPER
	_style = UiKit.box(paper_color, Color("b89f6e"), 1, 2, 0)
	_style.shadow_color = Color(0, 0, 0, 0.35)
	_style.shadow_size = 4
	_style.shadow_offset = Vector2(2, 3)
	if selected:
		_style.border_color = Color("e0b84f")
		_style.set_border_width_all(4)
	_paper.add_theme_stylebox_override("panel", _style)
	_border_color = _style.border_color
	_border_width = _style.border_width_left
	add_child(_paper)

	var pin := Panel.new()
	pin.size = Vector2(12, 12)
	pin.position = Vector2(PAPER_SIZE.x / 2 - 6, 4)
	pin.add_theme_stylebox_override("panel", UiKit.box(Color("a3302a"), Color("5a1410"), 1, 6, 0))
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(pin)

	var text := VBoxContainer.new()
	text.position = Vector2(12, 16)
	text.size = PAPER_SIZE - Vector2(24, 22)
	text.add_theme_constant_override("separation", 3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(text)
	var title := UiKit.bold(q.def.name, 17, UiKit.INK_SOFT if locked else UiKit.INK, true)
	title.custom_minimum_size = Vector2(PAPER_SIZE.x - 24 - (40 if q.def.repeatable else 0), 0)
	text.add_child(title)

	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 8)
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(money)
	money.add_child(UiKit.bold("%dG" % q.def.reward, UiKit.SIZE_HEADING, UiKit.GOLD))
	var weeks := UiKit.label("%d週" % q.def.weeks, UiKit.SIZE_SMALL, UiKit.INK_SOFT)
	weeks.size_flags_vertical = Control.SIZE_SHRINK_END
	money.add_child(weeks)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(info)
	info.add_child(UiKit.job_chip(c.config, q.def.job, false, UiKit.SIZE_TINY))
	info.add_child(UiKit.label("難易度 %d" % q.def.difficulty, UiKit.SIZE_SMALL, UiKit.INK))

	if locked:
		text.add_child(UiKit.bold("評判%dで受注可" % q.def.required_reputation, UiKit.SIZE_SMALL, UiKit.BAD))
	elif in_progress:
		text.add_child(UiKit.bold("残り%d週" % q.weeks_left, UiKit.SIZE_SMALL, UiKit.INFO))
	elif q.def.repeatable:
		var cap_text := "評判は%dまで上がる" % q.def.reputation_cap if q.def.reputation_cap >= 0 else "何度でも受けられる"
		text.add_child(UiKit.label(cap_text, UiKit.SIZE_TINY, UiKit.INK_SOFT))
	else:
		var left := c.last_listed_week(q) - c.week
		var last := left == 0
		if last:
			text.add_child(UiKit.bold("掲示は今週まで", UiKit.SIZE_TINY, UiKit.WARN))
		else:
			text.add_child(UiKit.label("掲示あと%d週" % (left + 1), UiKit.SIZE_TINY, UiKit.INK_SOFT))

	if q.def.repeatable:
		var badge := UiKit.chip("常設", Color("4f6b3a"), Color.WHITE, UiKit.SIZE_TINY)
		badge.position = Vector2(PAPER_SIZE.x - 50, 8)
		_paper.add_child(badge)

	if in_progress:
		_stamp = UiKit.bold("受注中", 24, UiKit.STAMP_RED)
		var stamp_box := UiKit.box(Color(1, 1, 1, 0), UiKit.STAMP_RED, 3, 4, 4)
		stamp_box.content_margin_left = 8
		stamp_box.content_margin_right = 8
		_stamp.add_theme_stylebox_override("normal", stamp_box)
		_stamp.modulate = Color(1, 1, 1, 0.8)
		_stamp.position = Vector2(PAPER_SIZE.x - 104, PAPER_SIZE.y - 46)
		_stamp.rotation_degrees = -14
		_paper.add_child(_stamp)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = Portrait.is_adventurer_drag(data) and data["source"] == "roster" \
		and _controller.dispatch_error(_controller.quest(quest_id), [str(data["id"])] as Array[String], 0) == ""
	_set_highlight(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_highlight(false)
	adventurer_dropped.emit(quest_id, str(data["id"]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_set_highlight(false)


func _set_highlight(on: bool) -> void:
	if _style == null:
		return
	_style.border_color = Color("5f9e3a") if on else _border_color
	_style.set_border_width_all(4 if on else _border_width)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(quest_id)
		accept_event()
