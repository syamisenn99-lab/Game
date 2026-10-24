extends Control
## 画面と流れ。タイトル → 序 → 陳情を順に（訴え → 御沙汰の刻 → 宣言 → その後 → 振り返り）→ まとめ。
## 操作は扇（Fan）だけ。文章は扇を動かすと進み、決定は「開く」、戻る（構え直し）は「閉じる」。

const StageView := preload("res://scripts/ui/stage_view.gd")
const LOG_PATH := "user://playtest_log.json"

signal _judgment_finished

## false にすると、_ready で流れを始めない（テスト用）
var autostart := true

var stage: StageView
var split: BoxContainer
var text_panel: PanelContainer
var speaker_label: Label
var body: RichTextLabel
var notes_label: Label
var prompt_label: Label

## 女房帖: 女房 id → これまでに見えた所見（note）の一覧
var notebook: Dictionary = {}
var results: Array = []

var _typing := false
var _typed := 0.0
var _judging := false
var _judge_start_us := 0
var _judge_times: Array = []
var _toggle_serial := 0


func _ready() -> void:
	theme = UiTheme.make()
	_build()
	Fan.toggled.connect(_on_fan_toggled)
	Fan.synced.connect(func(open: bool) -> void: stage.snap_fan(open))
	stage.snap_fan(Fan.is_open)
	resized.connect(_relayout)
	_relayout()
	if autostart:
		run_forever()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	split = BoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	margin.add_child(split)

	stage = StageView.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(stage)

	text_panel = PanelContainer.new()
	text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(text_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	text_panel.add_child(v)

	speaker_label = Label.new()
	speaker_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	speaker_label.add_theme_font_size_override("font_size", 24)
	v.add_child(speaker_label)

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 120)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)

	notes_label = Label.new()
	notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes_label.add_theme_font_size_override("font_size", 18)
	notes_label.add_theme_color_override("font_color", UiTheme.INK_FAINT)
	notes_label.visible = false
	v.add_child(notes_label)

	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.6)
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)

	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", UiTheme.INK_FAINT)
	v.add_child(prompt_label)


## 縦長なら上下（御簾が上）、横長なら左右（御簾が左）に並べる
func _relayout() -> void:
	var portrait := size.y >= size.x
	split.vertical = portrait
	stage.size_flags_stretch_ratio = 0.8 if portrait else 0.9
	text_panel.size_flags_stretch_ratio = 1.2 if portrait else 1.1


func _process(delta: float) -> void:
	if _typing:
		_typed += float(GameData.cfg("text_chars_per_sec", 40)) * delta
		body.visible_characters = int(_typed)
		if body.visible_characters >= body.get_total_character_count():
			_finish_typing()
	if _judging:
		var window := float(GameData.cfg("judgment_window_sec", 6.0))
		var elapsed := _judge_elapsed()
		stage.incense = 1.0 - elapsed / window
		if elapsed >= window:
			_judging = false
			_judgment_finished.emit()


func _on_fan_toggled(open: bool) -> void:
	_toggle_serial += 1
	stage.animate_fan(open)
	if _judging:
		_judge_times.append(_judge_elapsed())


func _judge_elapsed() -> float:
	return (Time.get_ticks_usec() - _judge_start_us) / 1000000.0


# ---- 文章の表示 ----

func _show(speaker: String, bbcode: String, typewriter := true) -> void:
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	body.text = bbcode
	body.scroll_to_line(0)
	if typewriter and float(GameData.cfg("text_chars_per_sec", 40)) > 0.0:
		_typed = 0.0
		body.visible_characters = 0
		_typing = true
	else:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	body.visible_characters = -1


## 文章を出し、扇が動くまで待つ。文字送りの途中なら、まず全部を出す。
func say(speaker: String, bbcode: String) -> void:
	_show(speaker, bbcode)
	prompt_label.text = GameData.t("advance_prompt")
	while true:
		await Fan.toggled
		if _typing:
			_finish_typing()
			continue
		break


## 「開く」で決定するまで待つ。閉じたら構え直し（何も起きない）。
func wait_decision(prompt_closed: String, prompt_open: String) -> void:
	while true:
		prompt_label.text = prompt_open if Fan.is_open else prompt_closed
		var opened: bool = await Fan.toggled
		if opened and not _typing:
			return
		if _typing:
			_finish_typing()


func _wait_seconds(sec: float) -> void:
	if sec > 0.0:
		await get_tree().create_timer(sec).timeout


# ---- 流れ ----

func run_forever() -> void:
	while is_inside_tree():
		await title()
		await play_session()
		await summary()


func title() -> void:
	stage.set_cast("", "")
	notes_label.visible = false
	_show("", "[center]\n[font_size=48]%s[/font_size]\n\n%s[/center]" % [GameData.t("title"), GameData.t("subtitle")], false)
	await wait_decision(GameData.t("title_prompt_closed"), GameData.t("title_prompt_open"))


func play_session() -> void:
	notebook.clear()
	results.clear()
	for line in GameData.text.get("prologue", []):
		await say(String(line.get("speaker", "")), GameData.fmt(String(line.get("text", "")), {"etiquette": GameData.etiquette_text()}))
	for i in GameData.cases.size():
		await play_case(GameData.cases[i], i + 1)


func play_case(c: Dictionary, number: int) -> void:
	var ny: Dictionary = GameData.nyobo.get(c.get("nyobo", ""), {})
	var ny_id := String(ny.get("id", ""))
	var ny_name := String(ny.get("name", ""))
	var rank := GameData.rank_name(String(c.get("rank", "")))
	stage.set_cast(GameData.t("stage_nyobo", {"name": "%s（%s）" % [ny_name, ny.get("title", "")]}),
		GameData.t("stage_petitioner", {"petitioner": "%s（%s）" % [c.get("petitioner", ""), rank]}))
	notes_label.visible = false
	await say("", "[center]%s[/center]" % GameData.t("case_heading", {
		"n": number, "petitioner": c.get("petitioner", ""), "rank": rank, "nyobo": ny_name}))

	# はじめて会う女房は、名乗りと噂から
	if not notebook.has(ny_id):
		notebook[ny_id] = []
		for line in ny.get("intro", []):
			await say(ny_name, String(line))
		await say("", GameData.t("rumor", {"name": ny_name, "hint": ny.get("hint", "")}))
	_refresh_notes(ny)

	for line in c.get("petition", []):
		await say(String(line.get("speaker", "")), String(line.get("text", "")))

	var f := await judge(ny_name)
	var ctx := f.duplicate()
	ctx["rank"] = c.get("rank", "")
	ctx.merge(c.get("attributes", {}), true)
	var standard := GameData.standard_verdict(String(f["gesture"]))
	var reading := Interpreter.interpret(ny, ctx, standard)
	var declared := String(reading["verdict"])
	var correct := String(c.get("correct", ""))
	var category := Interpreter.assess(standard, declared, correct)
	var outcome: Dictionary = c.get("outcomes", {}).get(declared, {})

	# 宣言とその後
	await say(ny_name, GameData.t("declare", {"verdict": GameData.verdict_name(declared), "decree": outcome.get("decree", "")}))
	await say(GameData.t("aftermath_speaker"), String(outcome.get("aftermath", "")))

	# 振り返り
	var cat: Dictionary = GameData.text.get("categories", {}).get(category, {})
	await say(GameData.t("reflection_title"), GameData.t("reflection", {
		"label": cat.get("label", category), "comment": cat.get("comment", ""),
		"gesture_desc": GameData.describe_gesture(f),
		"standard": GameData.verdict_name(standard), "nyobo": ny_name,
		"declared": GameData.verdict_name(declared), "reading": reading.get("reading", ""),
		"correct": GameData.verdict_name(correct),
	}))

	# 女房帖に書き加える
	var note := String(reading.get("note", ""))
	if note != "" and not notebook[ny_id].has(note):
		notebook[ny_id].append(note)
		_refresh_notes(ny)
		await say(GameData.t("notebook_title"), GameData.t("note_added", {"name": ny_name, "note": note}))

	var feeling := ""
	if GameData.cfg("ask_feeling", true) and category in ["lost", "astray"]:
		feeling = await ask_feeling()

	var times: Array = []
	for t in f.get("times", []):
		times.append(snappedf(float(t), 0.01))
	results.append({
		"case": c.get("id", ""), "petitioner": c.get("petitioner", ""), "nyobo": ny_id,
		"gesture": f["gesture"], "times": times, "hesitated": f["hesitated"], "quick": f["quick"],
		"long_hold": f["long_hold"], "standard": standard, "declared": declared, "correct": correct,
		"rule": reading.get("index", -1), "category": category, "feeling": feeling,
	})


## 御沙汰の刻。扇を閉じた構えから、香が燃え尽きるまでの開閉を記録し、所作を読み取る。
func judge(ny_name: String) -> Dictionary:
	if Fan.is_open:
		_show(ny_name, GameData.t("close_fan_request"))
		prompt_label.text = GameData.t("close_fan_prompt")
		while Fan.is_open:
			await Fan.toggled
	var etiquette := GameData.etiquette_text()
	_show(GameData.t("judgment_title"), GameData.t("judgment_body", {"etiquette": etiquette}), false)
	prompt_label.text = GameData.t("judgment_ready")
	Fan.locked = true
	stage.incense = 1.0
	stage.incense_visible = true
	await _wait_seconds(float(GameData.cfg("judgment_grace_sec", 0.6)))
	Fan.locked = false
	prompt_label.text = GameData.t("judgment_prompt")
	_judge_times.clear()
	_judge_start_us = Time.get_ticks_usec()
	_judging = true
	await _judgment_finished
	stage.incense_visible = false
	var window := float(GameData.cfg("judgment_window_sec", 6.0))
	var f := Gesture.read(_judge_times, window, GameData.config)
	# 刻が終わった直後の押しすぎで、宣言を読み飛ばさないように
	Fan.locked = true
	await _wait_seconds(float(GameData.cfg("after_window_lock_sec", 0.6)))
	Fan.locked = false
	return f


## 伝わらなかったときの気持ちをたずねる。開けば「悔しい」、待てば「理不尽」。
func ask_feeling() -> String:
	_show("", GameData.t("feeling_question"), false)
	if Fan.is_open:
		prompt_label.text = GameData.t("feeling_prompt_open")
		while Fan.is_open:
			await Fan.toggled
	var sec := float(GameData.cfg("feeling_window_sec", 4.0))
	var start := Time.get_ticks_msec()
	var serial := _toggle_serial
	var answer := "unfair"
	while true:
		var left := sec - (Time.get_ticks_msec() - start) / 1000.0
		prompt_label.text = GameData.t("feeling_prompt_closed", {"sec": ceili(maxf(left, 0.0))})
		if _toggle_serial != serial:
			answer = "frustrated"
			break
		if left <= 0.0:
			break
		await get_tree().process_frame
	var word := GameData.t("feeling_" + answer)
	await say("", GameData.t("feeling_recorded", {"feeling": word}))
	return answer


func summary() -> void:
	stage.set_cast("", "")
	notes_label.visible = false
	for line in GameData.text.get("epilogue", []):
		await say(String(line.get("speaker", "")), String(line.get("text", "")))
	var counts := {"conveyed": 0, "read_quirk": 0, "lost": 0, "misjudged": 0, "astray": 0}
	var feelings := {"frustrated": 0, "unfair": 0}
	var lines: PackedStringArray = []
	for i in results.size():
		var r: Dictionary = results[i]
		counts[r["category"]] = int(counts.get(r["category"], 0)) + 1
		if feelings.has(r["feeling"]):
			feelings[r["feeling"]] += 1
		var cat: Dictionary = GameData.text.get("categories", {}).get(r["category"], {})
		lines.append(GameData.t("summary_line", {
			"n": i + 1, "petitioner": r["petitioner"], "gesture": GameData.gesture_name(r["gesture"]),
			"declared": GameData.verdict_name(r["declared"]), "correct": GameData.verdict_name(r["correct"]),
			"label": cat.get("label", r["category"]),
		}))
	var text := "[font_size=20]%s\n\n%s\n%s[/font_size]" % [
		"\n".join(lines), GameData.t("summary_counts", counts), GameData.t("summary_feelings", feelings)]
	save_log(counts, feelings)
	_show(GameData.t("summary_title"), text, false)
	await wait_decision(GameData.t("summary_prompt_closed"), GameData.t("summary_prompt_open"))


func _refresh_notes(ny: Dictionary) -> void:
	var lines: PackedStringArray = [
		GameData.t("notes_title", {"name": ny.get("name", "")}),
		GameData.t("notes_rumor", {"hint": ny.get("hint", "")}),
	]
	for n in notebook.get(ny.get("id", ""), []):
		lines.append("・" + String(n))
	notes_label.text = "\n".join(lines)
	notes_label.visible = true


## 試遊の記録を user://playtest_log.json に足していく（プロトタイプの検証用）
func save_log(counts: Dictionary, feelings: Dictionary) -> void:
	if not GameData.cfg("save_playtest_log", true):
		return
	var data: Dictionary = {"sessions": []}
	if FileAccess.file_exists(LOG_PATH):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
		if old is Dictionary and old.get("sessions") is Array:
			data = old
	data["sessions"].append({
		"finished_at": Time.get_datetime_string_from_system(),
		"config": GameData.config, "results": results.duplicate(true),
		"counts": counts, "feelings": feelings,
	})
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
