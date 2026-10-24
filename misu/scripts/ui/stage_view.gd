extends Control
## 御簾と、その奥の御方の影と、扇。御沙汰の刻には香が燃えていく。仮の絵（図形だけで描く）。

## 扇の開き具合（0 = 閉じ、1 = 開き）
var fan_open := 0.0:
	set(v):
		fan_open = v
		queue_redraw()
## 香の残り（1 → 0）
var incense := 1.0:
	set(v):
		incense = v
		queue_redraw()
const BOTTOM_SPACE := 62.0

var incense_visible := false:
	set(v):
		incense_visible = v
		queue_redraw()

## 下の2行（取り次ぎの女房と、陳情者）
var cast_label: Label
var _tween: Tween


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(240, 240)
	cast_label = Label.new()
	cast_label.add_theme_font_size_override("font_size", 20)
	cast_label.add_theme_color_override("font_color", UiTheme.LIGHT_TEXT)
	cast_label.add_theme_constant_override("line_spacing", 0)
	cast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cast_label.offset_top = -BOTTOM_SPACE
	cast_label.offset_left = 8.0
	add_child(cast_label)
	resized.connect(queue_redraw)


func set_cast(nyobo_text: String, petitioner_text: String) -> void:
	cast_label.text = "\n".join(PackedStringArray([nyobo_text, petitioner_text])).strip_edges()


func animate_fan(open: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var dur := float(GameData.cfg("fan_anim_sec", 0.18))
	_tween.tween_property(self, "fan_open", 1.0 if open else 0.0, dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func snap_fan(open: bool) -> void:
	if _tween:
		_tween.kill()
	fan_open = 1.0 if open else 0.0


func blind_rect() -> Rect2:
	var s := size
	return Rect2(s.x * 0.06, s.y * 0.04, s.x * 0.88, s.y * 0.96 - BOTTOM_SPACE - 6.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.WOOD)
	var b := blind_rect()
	var u := minf(b.size.x, b.size.y)
	# 御簾の奥（ほの明るい室内）
	draw_rect(b, Color("4a3524"))
	# 御方の影
	var cx := b.get_center().x
	var base_y := b.end.y
	var shadow := Color(0.08, 0.05, 0.03, 0.85)
	var bw := u * 0.62
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - bw * 0.5, base_y), Vector2(cx - bw * 0.2, base_y - u * 0.42),
		Vector2(cx + bw * 0.2, base_y - u * 0.42), Vector2(cx + bw * 0.5, base_y),
	]), shadow)
	draw_circle(Vector2(cx, base_y - u * 0.52), u * 0.11, shadow)
	# 扇（御方の手もと。御簾越しに透けて見える）
	_draw_fan(Vector2(cx + u * 0.08, base_y - u * 0.22), u * 0.36)
	# 御簾の簾（細い竹）
	var slat := Color(0.86, 0.72, 0.45, 0.5)
	var y := b.position.y + u * 0.07
	while y < b.end.y:
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), slat, 2.0)
		y += 6.0
	# 編み糸
	for i in range(1, 5):
		var x := b.position.x + b.size.x * i / 5.0
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), Color("6b1f1f", 0.8), 2.0)
	# 帽額（上の縁取り）
	draw_rect(Rect2(b.position, Vector2(b.size.x, u * 0.07)), Color("5a1e2a"))
	draw_rect(Rect2(b.position + Vector2(0, u * 0.07 - 3), Vector2(b.size.x, 3)), UiTheme.GOLD)
	draw_rect(b, UiTheme.GOLD, false, 2.0)
	if incense_visible:
		_draw_incense(b, u)


func _draw_fan(pivot: Vector2, r: float) -> void:
	var span := lerpf(deg_to_rad(9.0), deg_to_rad(160.0), clampf(fan_open, -0.1, 1.15))
	var start := -PI / 2.0 - span / 2.0
	var inner := r * 0.36
	var folds := 12
	for i in folds:
		var a0 := start + span * i / folds
		var a1 := start + span * (i + 1) / folds
		var col := Color("f4e6c6") if i % 2 == 0 else Color("dcc79c")
		draw_colored_polygon(PackedVector2Array([
			pivot + Vector2.from_angle(a0) * inner, pivot + Vector2.from_angle(a0) * r,
			pivot + Vector2.from_angle(a1) * r, pivot + Vector2.from_angle(a1) * inner,
		]), col)
	# 日の丸ふうの模様（開いたときだけ見える）
	if fan_open > 0.3:
		var mid := start + span / 2.0
		draw_circle(pivot + Vector2.from_angle(mid) * r * 0.7, r * 0.11 * clampf(fan_open, 0.0, 1.0), Color("b03a2e"))
	# 骨
	var rib := Color("6e4a2a")
	for i in folds + 1:
		var a := start + span * i / folds
		draw_line(pivot, pivot + Vector2.from_angle(a) * inner, rib, 3.0)
		draw_line(pivot + Vector2.from_angle(a) * inner, pivot + Vector2.from_angle(a) * r, Color(rib, 0.5), 1.0)
	draw_arc(pivot, r, start, start + span, 24, rib, 2.0)
	draw_circle(pivot, r * 0.05, UiTheme.GOLD)


func _draw_incense(b: Rect2, u: float) -> void:
	var foot := Vector2(b.end.x - u * 0.12, b.end.y - u * 0.04)
	var full := u * 0.5
	var h := full * clampf(incense, 0.0, 1.0)
	# 香炉
	draw_rect(Rect2(foot - Vector2(u * 0.06, 0), Vector2(u * 0.12, u * 0.035)), Color("7a6040"))
	# 線香
	draw_line(foot, foot - Vector2(0, full), Color(0.3, 0.25, 0.2, 0.4), 3.0)
	draw_line(foot, foot - Vector2(0, h), Color("3f5f3a"), 5.0)
	var tip := foot - Vector2(0, h)
	draw_circle(tip, 6.0, Color(1.0, 0.55, 0.2, 0.5))
	draw_circle(tip, 3.0, Color("ffb347"))
