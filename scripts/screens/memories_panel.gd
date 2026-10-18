class_name MemoriesPanel
extends Control
## 記憶の一覧。見るだけのモードと、あふれたときに1つ忘れるモードがある。

signal closed
signal forgot(memory: MemoryInstance)


## memories: 表示する記憶。forget_mode が true なら「忘れる」ボタンを出す
func setup(memories: Array[MemoryInstance], forget_mode: bool, slots: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := "記憶一覧（%d / %d）" % [mini(memories.size(), slots), slots]
	if forget_mode:
		title = "記憶があふれた！ 1つ選んで、完全に忘れよう（ラン中は戻らない）"
	box.add_child(UIKit.label(title, 22))
	if memories.is_empty():
		box.add_child(UIKit.label("まだ記憶はない。カードを手放すと、記憶になるよ。", 16))
	for m in memories:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var info := UIKit.label(_memory_text(m), 15)
		info.custom_minimum_size = Vector2(700, 0)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		if forget_mode:
			var forget := UIKit.button("これを忘れる", func() -> void:
				forgot.emit(m)
				queue_free())
			row.add_child(forget)
	if not forget_mode:
		box.add_child(UIKit.button("閉じる", func() -> void:
			closed.emit()
			queue_free(), Vector2(120, 40)))


func _memory_text(m: MemoryInstance) -> String:
	var text := "【%s】%s　元のカード：%s\n　%s" % [m.data.display_name, m.tier_label(), m.source_name, m.describe()]
	if m.sealed_turns > 0:
		text += "　（封印中：あと%dターン）" % m.sealed_turns
	return text
