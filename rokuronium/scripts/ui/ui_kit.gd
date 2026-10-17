class_name UIKit
extends RefCounted
## 画面で共通に使う、見た目の部品（コードで組み立てる）。

const COLOR_PANEL := Color(0.08, 0.09, 0.13, 0.88)
const COLOR_BORDER := Color(0.78, 0.68, 0.45, 0.9)
const COLOR_TEXT := Color(0.95, 0.94, 0.9)
const COLOR_NOTICE := "#e8c26a"


static func box(bg: Color = COLOR_PANEL, border: Color = COLOR_BORDER, radius: int = 10, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func style_button(b: Button, font_size: int = 22) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	b.add_theme_stylebox_override("normal", box(Color(0.12, 0.14, 0.2, 0.92), Color(0.55, 0.5, 0.38, 0.9)))
	b.add_theme_stylebox_override("hover", box(Color(0.2, 0.22, 0.32, 0.96), COLOR_BORDER))
	b.add_theme_stylebox_override("pressed", box(Color(0.28, 0.26, 0.2, 0.98), COLOR_BORDER))
	b.add_theme_stylebox_override("disabled", box(Color(0.1, 0.1, 0.12, 0.7), Color(0.3, 0.3, 0.3, 0.7)))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), Color(1, 0.9, 0.5), 10, 3))


static func make_button(text: String, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, font_size)
	return b


static func make_label(text: String, font_size: int = 20, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## フォールバック用の仮背景色。config の background_colors に無い場合は名前から決める。
static func background_color(db: GameDB, bg_id: String) -> Color:
	var table: Dictionary = db.config.get("background_colors", {})
	if table.has(bg_id) and str(table[bg_id]).is_valid_html_color():
		return Color(str(table[bg_id]))
	var h := float(absi(bg_id.hash()) % 360) / 360.0
	return Color.from_hsv(h, 0.3, 0.3)


## 立ち絵ID "ayaka_shy" → テクスチャ。assets/characters/ に ayaka_shy.png が無ければ
## ayaka_normal.png、それも無ければ null（呼び出し側で仮素材を出す）。
static func load_portrait_texture(portrait_id: String) -> Texture2D:
	var base := "res://assets/characters/"
	for p in [base + portrait_id + ".png", base + portrait_id.split("_")[0] + "_normal.png"]:
		if ResourceLoader.exists(p):
			return load(p)
	return null


static func load_background_texture(bg_id: String) -> Texture2D:
	var p := "res://assets/backgrounds/%s.png" % bg_id
	if ResourceLoader.exists(p):
		return load(p)
	return null
