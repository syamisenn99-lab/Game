class_name Effects
extends RefCounted
## ドラッグ結果などの小さな演出。overlay は画面全体を覆う、入力を受けない Control。


## 火花のように飛び散る粒（成功: 上向きに広がる／失敗: 下へ落ちる塵）
static func burst(overlay: Control, at: Vector2, color: Color, amount: int = 28, upward: bool = true) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1) if upward else Vector2(0, 1)
	p.spread = 180.0 if upward else 60.0
	p.gravity = Vector2(0, 700) if upward else Vector2(0, 200)
	p.initial_velocity_min = 140.0 if upward else 40.0
	p.initial_velocity_max = 340.0 if upward else 120.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0 if upward else 5.0
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	overlay.add_child(p)
	p.global_position = at
	p.emitting = true
	overlay.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


## ふわっと浮かんで消える文字
static func float_text(overlay: Control, text: String, at: Vector2, color: Color, font_size: int = 30) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(label)
	label.reset_size()
	var viewport_size := overlay.get_viewport_rect().size
	var pos := at - label.size / 2.0
	label.global_position = Vector2(
		clampf(pos.x, 8.0, maxf(8.0, viewport_size.x - label.size.x - 8.0)),
		clampf(pos.y, 8.0, maxf(8.0, viewport_size.y - label.size.y - 8.0)))
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.6, 0.6)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - 46.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


## ぽんっと弾む（ドロップ成功）
static func pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.05, 1.05), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## ぷるぷる揺れる（ドロップ失敗）
static func wobble(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	for angle in [-0.025, 0.025, -0.018, 0.018, -0.008, 0.0]:
		tw.tween_property(node, "rotation", angle, 0.045)


## ハンコを押す（大きく出て、ぎゅっと収まる）
static func stamp_slam(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.modulate.a = 0.0
	node.scale = Vector2(1.9, 1.9)
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "modulate:a", 1.0, 0.1)
