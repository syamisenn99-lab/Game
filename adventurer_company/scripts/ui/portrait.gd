extends Control
## 冒険者のポートレート。ドラッグして派遣パネルの枠や掲示板の依頼に置ける。
## res://assets/portraits/<冒険者ID>.png（または .svg）があればその絵を使う。なければ職業ごとのシルエットを描く。

signal clicked(adventurer_id: String)
signal hovered(adventurer_id: String)

const IMAGE_DIR := "res://assets/portraits"
## 職業ID → [背景色, 服の色, かぶり物の色]
const JOB_COLORS := {
	"warrior": [Color("c98f7a"), Color("8c3b2e"), Color("8e939a")],
	"scout": [Color("9fbf8f"), Color("3f6b3a"), Color("2f4f2a")],
	"mage": [Color("9aa6d6"), Color("3b4f8c"), Color("2c2f6b")],
}
const DEFAULT_COLORS := [Color("c8b89a"), Color("6b5640"), Color("4a3a2a")]

var def: AdventurerDef
## ドラッグできるか（待機中の冒険者だけ）
var draggable: bool = false
## ドラッグのデータに入れる出どころ（"pool" / "slot" / "roster"）
var source: String = ""

var _press_inside := false


func setup(adventurer: AdventurerDef, job_name: String, can_drag: bool, from: String) -> void:
	def = adventurer
	draggable = can_drag
	source = from
	# ポートレートの上に落とされたドロップは、下の枠（パーティ枠・一覧）に渡す
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "%s（%s・腕前%d）\n%s：%s" % [def.name, job_name, def.ability, def.skill_name, def.skill_description]
	mouse_default_cursor_shape = Control.CURSOR_DRAG if can_drag else Control.CURSOR_ARROW
	var image := _find_image()
	if image != null:
		var tex := TextureRect.new()
		tex.texture = image
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex)
	mouse_entered.connect(func() -> void: hovered.emit(def.id))
	queue_redraw()


func _find_image() -> Texture2D:
	for ext in ["png", "svg", "webp"]:
		var path := "%s/%s.%s" % [IMAGE_DIR, def.id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


# ---- ドラッグ＆ドロップ ----

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or def == null:
		return null
	var preview := Control.new()
	var copy: Control = load("res://scripts/ui/portrait.gd").new()
	copy.size = size
	copy.position = -size / 2
	copy.modulate = Color(1, 1, 1, 0.85)
	copy.setup(def, "", false, source)
	copy.tooltip_text = ""
	preview.add_child(copy)
	set_drag_preview(preview)
	_press_inside = false
	return {"kind": "adventurer", "id": def.id, "source": source}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_inside = true
		elif _press_inside:
			_press_inside = false
			if def != null:
				clicked.emit(def.id)


static func is_adventurer_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "adventurer"


# ---- 描画（絵がないときのシルエット） ----

func _draw() -> void:
	if def == null or get_child_count() > 0:
		return
	var w := size.x
	var h := size.y
	var colors: Array = JOB_COLORS.get(def.job, DEFAULT_COLORS)
	var look: Dictionary = def.portrait
	var skin := Color(str(look.get("skin", "e8c4a0")))
	var hair := Color(str(look.get("hair", "5a3a22")))

	draw_rect(Rect2(Vector2.ZERO, size), colors[0])
	var cx := w * 0.5
	var head_c := Vector2(cx, h * 0.42)
	var r := minf(w, h) * 0.2

	# かぶり物の後ろ側（フード）
	if def.job == "scout":
		draw_circle(head_c + Vector2(0, -r * 0.1), r * 1.45, colors[2])
	# 髪（後ろ）
	elif def.job != "warrior":
		draw_circle(head_c + Vector2(0, -r * 0.15), r * 1.12, hair)

	# 体
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.08, h), Vector2(w * 0.2, h * 0.72), Vector2(w * 0.8, h * 0.72), Vector2(w * 0.92, h),
	]), colors[1])
	draw_rect(Rect2(cx - r * 0.35, head_c.y + r * 0.8, r * 0.7, r * 0.6), skin.darkened(0.1))
	# 頭
	draw_circle(head_c, r, skin)
	# 目
	var eye := Color("2a1d14")
	draw_circle(head_c + Vector2(-r * 0.38, r * 0.05), maxf(1.2, r * 0.1), eye)
	draw_circle(head_c + Vector2(r * 0.38, r * 0.05), maxf(1.2, r * 0.1), eye)
	if bool(look.get("beard", false)):
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-r * 0.85, r * 0.3), head_c + Vector2(r * 0.85, r * 0.3), head_c + Vector2(0, r * 1.7),
		]), hair)

	match def.job:
		"warrior":
			# 兜
			draw_colored_polygon(PackedVector2Array([
				head_c + Vector2(-r * 1.1, r * 0.05), head_c + Vector2(-r * 1.0, -r * 0.8),
				head_c + Vector2(0, -r * 1.25), head_c + Vector2(r * 1.0, -r * 0.8), head_c + Vector2(r * 1.1, r * 0.05),
				head_c + Vector2(r * 0.75, -r * 0.25), head_c + Vector2(-r * 0.75, -r * 0.25),
			]), colors[2])
			draw_rect(Rect2(head_c + Vector2(-r * 0.1, -r * 0.3), Vector2(r * 0.2, r * 0.75)), colors[2])
		"scout":
			# 前髪
			draw_colored_polygon(PackedVector2Array([
				head_c + Vector2(-r * 0.95, -r * 0.1), head_c + Vector2(-r * 0.6, -r * 0.85),
				head_c + Vector2(r * 0.6, -r * 0.85), head_c + Vector2(r * 0.95, -r * 0.1), head_c + Vector2(0, -r * 0.45),
			]), hair)
		"mage":
			# とんがり帽子
			draw_colored_polygon(PackedVector2Array([
				head_c + Vector2(-r * 0.95, -r * 0.55), head_c + Vector2(r * 0.15, -r * 2.6), head_c + Vector2(r * 0.95, -r * 0.55),
			]), colors[2])
			draw_rect(Rect2(head_c + Vector2(-r * 1.45, -r * 0.7), Vector2(r * 2.9, r * 0.32)), colors[2])
		_:
			pass
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), false, 2.0)
