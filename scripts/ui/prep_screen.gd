class_name PrepScreen
extends Control
## 準備フェーズ: 誰をガイドするか選び、情報や道具を買って、探索に出発する（ゲームの入口）。

const MATCHING_SCENE := "res://scenes/matching_screen.tscn"
const PREP_SCENE := "res://scenes/prep_screen.tscn"
const STAT_ORDER: Array[StringName] = [&"battle", &"explore", &"evade"]
const GOLD := Color("e0a800")
## 能力ごとのバーの色（戦闘＝赤、探索＝青、回避＝緑）
const STAT_COLORS := {
	&"battle": Color("c0392b"),
	&"explore": Color("2f6fb5"),
	&"evade": Color("3c8d5a"),
}
const STAT_MAX := 5

var cards: Dictionary = {}
var select_buttons: Dictionary = {}
## 冒険者id -> {能力 -> 塗られたマスの数}（テスト用）
var stat_values: Dictionary = {}
## ShopItem.id -> {"panel": PanelContainer, "button": Button}
var shop_rows: Dictionary = {}
var day_label: Label
var funds_label: Label
var living_label: Label
var notebook_label: Label
var warning_label: Label
var depart_button: Button
var reset_button: Button
var mute_button: Button
var clue_button: Button
## 手がかり帳（開いているときだけ）
var clue_book: Control
var _reset_armed := false
var _offers: Array[ShopItem] = []
var _items: Array[ShopItem] = []


func _ready() -> void:
	GameSession.load_notebook()
	# 出す場面があれば（初回のプロローグ、探索のあとの手がかりなど）、先にそちらへ
	if _maybe_play_story():
		return
	theme = Palette.make_theme()
	_offers = SampleData.info_offers()
	_items = SampleData.items()
	_build_ui()
	_refresh()


# ---------------------------------------------------------------- 画面構築

func _build_ui() -> void:
	var desk := ColorRect.new()
	desk.color = Palette.DESK
	desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# 上部: 日数と資金
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	root.add_child(top)
	var title := _desk_label("準備", 36)
	top.add_child(title)
	day_label = _desk_label("", 24)
	top.add_child(day_label)
	funds_label = _desk_label("", 24)
	funds_label.add_theme_color_override("font_color", GOLD)
	top.add_child(funds_label)
	living_label = _desk_label("", 20)
	top.add_child(living_label)

	# 中央: 3つの棚
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	root.add_child(middle)

	var guide_box := _shelf("ガイドする人", 1.7)
	middle.add_child(guide_box["panel"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	(guide_box["list"] as VBoxContainer).add_child(grid)
	for adventurer in SampleData.adventurers():
		var card := _build_adventurer_card(adventurer)
		grid.add_child(card)
		cards[adventurer.id] = card

	var info_box := _shelf("情報を買う", 1.0)
	middle.add_child(info_box["panel"])
	for offer in _offers:
		(info_box["list"] as VBoxContainer).add_child(_build_shop_row(offer))

	var item_box := _shelf("道具を買う", 0.8)
	middle.add_child(item_box["panel"])
	for item in _items:
		(item_box["list"] as VBoxContainer).add_child(_build_shop_row(item))
	notebook_label = Label.new()
	notebook_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	notebook_label.add_theme_font_size_override("font_size", 18)
	notebook_label.add_theme_color_override("font_color", Palette.INK_FAINT)
	(item_box["list"] as VBoxContainer).add_child(notebook_label)

	# 下部: 注意書き・設定・出発
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	warning_label = _desk_label("", 18)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	warning_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning_label.add_theme_color_override("font_color", Color("ffb3a6"))
	bottom.add_child(warning_label)
	clue_button = Button.new()
	clue_button.custom_minimum_size = Vector2(200, 48)
	clue_button.pressed.connect(open_clue_book)
	bottom.add_child(clue_button)
	reset_button = Button.new()
	reset_button.custom_minimum_size = Vector2(260, 48)
	reset_button.pressed.connect(request_reset)
	bottom.add_child(reset_button)
	mute_button = Button.new()
	mute_button.text = Sfx.mute_button_text()
	mute_button.custom_minimum_size = Vector2(96, 48)
	mute_button.pressed.connect(func() -> void:
		Sfx.set_muted(not Sfx.muted)
		mute_button.text = Sfx.mute_button_text()
		Sfx.play(&"click"))
	bottom.add_child(mute_button)
	depart_button = Button.new()
	depart_button.text = "探索に出発"
	depart_button.custom_minimum_size = Vector2(220, 52)
	depart_button.add_theme_font_size_override("font_size", 26)
	depart_button.pressed.connect(depart)
	bottom.add_child(depart_button)


func _desk_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Palette.DESK_TEXT)
	return label


## 見出しつきの紙の棚。{"panel": 外枠, "list": 中身を並べる VBox}
func _shelf(heading: String, stretch: float) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER_DIM, Palette.INK_FAINT, 2, 6, 12.0))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 24)
	vbox.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return {"panel": panel, "list": list}


func _build_adventurer_card(adventurer: Adventurer) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vbox.add_child(head)
	var portrait := Illustrations.find("portraits", adventurer.id)
	if portrait != null:
		var face := TextureRect.new()
		face.texture = portrait
		face.custom_minimum_size = Vector2(56, 56)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(face)
	var name_label := Label.new()
	name_label.text = adventurer.display_name
	name_label.add_theme_font_size_override("font_size", 22)
	head.add_child(name_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var button := Button.new()
	button.custom_minimum_size = Vector2(80, 36)
	button.pressed.connect(choose.bind(adventurer.id))
	head.add_child(button)
	select_buttons[adventurer.id] = button
	vbox.add_child(_build_stat_bars(adventurer))
	vbox.add_child(_small(adventurer.tagline, Palette.INK))
	vbox.add_child(_small("報告のクセ: " + adventurer.report_style, Palette.INK_FAINT))
	return card


## 戦闘・探索・回避の能力を、色分けした5マスのバーで見せる。いちばん高い能力の名前は太字にする
func _build_stat_bars(adventurer: Adventurer) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var best := 0
	for stat in STAT_ORDER:
		best = maxi(best, adventurer.stat_for(stat))
	stat_values[adventurer.id] = {}
	for stat in STAT_ORDER:
		var value := adventurer.stat_for(stat)
		stat_values[adventurer.id][stat] = value
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var name_label := Label.new()
		name_label.text = Rules.STAT_LABELS[stat]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", STAT_COLORS[stat] if value == best else Palette.INK_FAINT)
		cell.add_child(name_label)
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 2)
		cell.add_child(bar)
		for i in STAT_MAX:
			var segment := ColorRect.new()
			segment.custom_minimum_size = Vector2(13, 13)
			segment.color = STAT_COLORS[stat] if i < value else Color(0.78, 0.72, 0.58)
			bar.add_child(segment)
	return row


func _small(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	return label


func _build_shop_row(item: ShopItem) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.PAPER_DIM, 2, 6, 8.0))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_box)
	var name_label := Label.new()
	name_label.text = item.title
	name_label.add_theme_font_size_override("font_size", 19)
	text_box.add_child(name_label)
	text_box.add_child(_small(item.description, Palette.INK_FAINT))
	var button := Button.new()
	button.custom_minimum_size = Vector2(92, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(buy.bind(item.id))
	hbox.add_child(button)
	shop_rows[item.id] = {"panel": panel, "button": button, "item": item}
	return panel


# ---------------------------------------------------------------- 表示の更新

func _refresh() -> void:
	day_label.text = "%d日目" % GameSession.day
	funds_label.text = "資金 %d 銀貨" % GameSession.funds
	living_label.text = "（生活費 1日 %d 銀貨）" % Rules.LIVING_COST

	for id in cards:
		var selected: bool = id == GameSession.adventurer_id
		(cards[id] as PanelContainer).add_theme_stylebox_override("panel",
			Palette.box(Color("fff6d6") if selected else Palette.PAPER, GOLD if selected else Palette.PAPER_DIM, 4 if selected else 2, 8, 10.0))
		var button := select_buttons[id] as Button
		button.text = "選択中" if selected else "選ぶ"
		button.disabled = selected

	for id in shop_rows:
		var row: Dictionary = shop_rows[id]
		var item: ShopItem = row["item"]
		var button: Button = row["button"]
		if GameSession.is_owned(item):
			button.text = "購入済"
			button.disabled = true
		else:
			button.text = "%d 銀貨" % item.price
			button.disabled = GameSession.funds < item.price

	var spots := SampleData.growth_spots()
	var learned: Array[String] = []
	for id in spots:
		if GameSession.filled_blanks.has(id):
			learned.append(spots[id])
	notebook_label.text = "ノートの育ち %d / %d" % [learned.size(), spots.size()]
	if not learned.is_empty():
		notebook_label.text += "　書けたこと: " + "、".join(learned)

	warning_label.text = ""
	if GameSession.funds < Rules.LIVING_COST:
		warning_label.text = "資金が生活費（%d）より少ない。探索の報酬で足りないと、暮らしていけなくなる…" % Rules.LIVING_COST
	reset_button.text = "本当に消す？ もう一度押すとリセット" if _reset_armed else "最初からやり直す"
	var unlocked := 0
	for scene in StoryData.clues():
		if GameSession.has_seen(scene.id):
			unlocked += 1
	clue_button.text = "姉の手がかり %d/%d" % [unlocked, StoryData.clues().size()]


# ---------------------------------------------------------------- 操作

func choose(id: StringName) -> void:
	GameSession.adventurer_id = id
	Sfx.play(&"click")
	_refresh()


## 買う（情報・道具）。買えたら true
func buy(item_id: StringName) -> bool:
	if not shop_rows.has(item_id):
		return false
	var item: ShopItem = shop_rows[item_id]["item"]
	var ok := GameSession.buy(item)
	Sfx.play(&"coin" if ok else &"mismatch")
	_refresh()
	return ok


## 探索に出発。テストでは go=false にしてシーン遷移を避ける。
func depart(go: bool = true) -> void:
	Sfx.play(&"select")
	if not go:
		return
	# 初めてその冒険者と出発するときは、紹介の場面を先に見せる
	var intro: StoryScene = StoryDirector.intro_for_depart(GameSession.adventurer_id) if GameSession.story_enabled else null
	if intro != null:
		StoryDirector.play(get_tree(), intro.id, MATCHING_SCENE)
	else:
		GameSession.go_to(get_tree(), MATCHING_SCENE)


## 出す場面があれば、そちらへ移る（準備画面に戻ってくる）。移ったら true
func _maybe_play_story() -> bool:
	if not GameSession.story_enabled:
		return false
	var scene := StoryDirector.next_for_prep()
	if scene == null:
		return false
	StoryDirector.play.call_deferred(get_tree(), scene.id, PREP_SCENE)
	return true


## 姉の手がかり帳を開く。見つけた手がかりを読み返せる
func open_clue_book() -> void:
	if clue_book != null:
		return
	Sfx.play(&"click")
	clue_book = Control.new()
	clue_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(clue_book)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	clue_book.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	clue_book.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 560)
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, Palette.INK, 3, 10, 20.0))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "姉の手がかり"
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.add_child(_clue_row("はじまりの物語", "プロローグを読み返す。", &"prologue", GameSession.has_seen(&"prologue")))
	var number := 1
	for scene in StoryData.clues():
		var unlocked := GameSession.has_seen(scene.id)
		list.add_child(_clue_row("手がかり %d　%s" % [number, scene.clue_title if unlocked else "？？？"],
			scene.clue_summary if unlocked else _clue_hint(scene), scene.id, unlocked))
		number += 1
	var close := Button.new()
	close.text = "閉じる"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(close_clue_book)
	vbox.add_child(close)


func close_clue_book() -> void:
	if clue_book != null:
		clue_book.queue_free()
		clue_book = null
		Sfx.play(&"click")


## 解放されていない手がかりの、ヒント（どうすれば見つかるか）
func _clue_hint(scene: StoryScene) -> String:
	if not scene.requires_seen.is_empty():
		return "ほかの手がかりが、すべて揃うと…"
	for adventurer_id in scene.after_runs:
		var adventurer := SampleData.adventurer(StringName(adventurer_id))
		return "%sと探索を重ねると、何か話してくれるかもしれない。" % adventurer.display_name
	return "まだ、見つかっていない。"


func _clue_row(heading: String, body: String, scene_id: StringName, unlocked: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER if unlocked else Palette.PAPER_DIM, Palette.PAPER_DIM, 2, 6, 10.0))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_box)
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 21)
	if not unlocked:
		head.add_theme_color_override("font_color", Palette.INK_FAINT)
	text_box.add_child(head)
	text_box.add_child(_small(body, Palette.INK if unlocked else Palette.INK_FAINT))
	if unlocked:
		var button := Button.new()
		button.text = "読み返す"
		button.custom_minimum_size = Vector2(120, 40)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(replay_scene.bind(scene_id))
		hbox.add_child(button)
	return row


## 見た場面を、もう一度読む（読み終わったら準備画面に戻る）
func replay_scene(scene_id: StringName) -> void:
	Sfx.play(&"click")
	StoryDirector.play(get_tree(), scene_id, PREP_SCENE)


## 全部を最初に戻す（ノート・資金・日数・道具）。誤って消さないよう、2回押して確定する。
func request_reset() -> void:
	Sfx.play(&"click")
	if not _reset_armed:
		_reset_armed = true
	else:
		_reset_armed = false
		GameSession.reset_all()
		_refresh()
		# 最初からやり直すと、プロローグがまた出る
		_maybe_play_story()
		return
	_refresh()
