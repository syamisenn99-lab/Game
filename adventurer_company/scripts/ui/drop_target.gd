extends PanelContainer
## ドロップを受ける枠。受けるかどうかと、受けたときの処理は Callable で渡す。

## func(data: Variant) -> bool
var accept: Callable
## func(data: Variant) -> void
var on_drop: Callable

var _normal_style: StyleBox
var _hover_style: StyleBox


func setup(normal: StyleBox, hover: StyleBox, accept_func: Callable, drop_func: Callable) -> void:
	_normal_style = normal
	_hover_style = hover
	accept = accept_func
	on_drop = drop_func
	add_theme_stylebox_override("panel", normal)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = accept.is_valid() and accept.call(data)
	add_theme_stylebox_override("panel", _hover_style if ok else _normal_style)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	add_theme_stylebox_override("panel", _normal_style)
	on_drop.call(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _normal_style != null:
			add_theme_stylebox_override("panel", _normal_style)
