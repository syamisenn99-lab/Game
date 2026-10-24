extends Node
## 扇。入力はこれひとつ（スペースキー・マウス左クリック・画面タップ）。
## 押すたびに「開く ⇄ 閉じる」が切り替わる。自動読み込み（Fan）。

signal toggled(is_open: bool)
## 演出のため、切り替えずに状態だけ合わせたとき
signal synced(is_open: bool)

var is_open := false
## true のあいだは入力を受け付けない（御沙汰の刻の直前・直後の誤操作よけ）
var locked := false
var _last_us := -1000000000


func _input(event: InputEvent) -> void:
	if is_fan_event(event):
		get_viewport().set_input_as_handled()
		press()


static func is_fan_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == KEY_SPACE
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


## 扇を切り替える。切り替えたら true
func press(ignore_cooldown := false) -> bool:
	if locked:
		return false
	var now := Time.get_ticks_usec()
	var cooldown := float(GameData.cfg("input_cooldown_sec", 0.08))
	if not ignore_cooldown and now - _last_us < int(cooldown * 1000000.0):
		return false
	_last_us = now
	is_open = not is_open
	toggled.emit(is_open)
	return true


func set_state(open: bool) -> void:
	is_open = open
	synced.emit(is_open)
