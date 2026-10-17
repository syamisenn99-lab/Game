class_name StoryEngine
extends RefCounted
## シナリオ進行の中核。UI には依存せず、「いまのシーンの本文・選択肢」を返し、
## 「選択」を受けて判定・効果の適用・次シーンへの遷移を行う。

const DEFAULT_WHO := "kazuki"
const CONTINUE_TEXT := "続ける"

var db: GameDB
var state: GameState
var scene: Dictionary = {}
## 次に表示する本文の冒頭に出す通知（判定結果・入手通知など）。UI が take_notices() で受け取る。
var notices: Array = []
## 画面に出している順に並んだ選択肢（条件で非表示のものは除く）
var shown_choices: Array = []
## true なら判定結果に出目などの内訳も添える（設定で切り替え）
var show_roll_detail := false
var last_check: Dictionary = {}
## テスト用: 0以上なら、判定の出目をこの値に固定する
var forced_roll := -1


func _init(p_db: GameDB, p_state: GameState) -> void:
	db = p_db
	state = p_state


func start_new_game() -> void:
	state.new_game(db)
	notices.clear()
	enter(str(db.config["start_scene"]))


## シーンに入る。run_effects=false は、セーブからの復帰用（on_enter を再実行しない）。
func enter(scene_id: String, run_effects: bool = true) -> void:
	scene = db.scenes[scene_id]
	state.current_scene = scene_id
	if scene.has("location"):
		state.location = str(scene["location"])
	var t: Variant = scene.get("time")
	if typeof(t) == TYPE_DICTIONARY:
		if t.has("day"):
			state.day = int(t["day"])
		if t.has("slot"):
			state.slot = str(t["slot"])
	if run_effects:
		Fx.apply(scene.get("on_enter", []), state, db, notices)
	_build_choices()


func is_end() -> bool:
	return bool(scene.get("end", false))


func take_notices() -> Array:
	var n := notices.duplicate()
	notices.clear()
	return n


## 条件を満たす本文行だけを返す。
func get_lines() -> Array[String]:
	var out: Array[String] = []
	for line in scene.get("text", []):
		if typeof(line) == TYPE_DICTIONARY:
			if line.has("if") and not Cond.test(str(line["if"]), state):
				continue
			out.append(str(line.get("text", "")))
		else:
			out.append(str(line))
	return out


## シーンの選択肢（生データ）。choices が無ければ auto / next から「続ける」を作る。
static func raw_choices(sc: Dictionary) -> Array:
	var cs: Variant = sc.get("choices")
	if typeof(cs) == TYPE_ARRAY and not (cs as Array).is_empty():
		return cs
	if sc.has("auto"):
		var a: Dictionary = (sc["auto"] as Dictionary).duplicate(true)
		if not a.has("text"):
			a["text"] = CONTINUE_TEXT
		a["fixed"] = true
		return [a]
	if sc.has("next"):
		return [{"text": sc.get("continue_text", CONTINUE_TEXT), "next": sc["next"], "fixed": true}]
	return []


## 選択肢を並べ直す。表示のたびにランダム順（fixed: true のものは末尾に固定）。
func _build_choices() -> void:
	var shuffled: Array = []
	var fixed: Array = []
	for ch in raw_choices(scene):
		if ch.has("condition") and not Cond.test(str(ch["condition"]), state):
			continue
		if ch.get("fixed", false):
			fixed.append(ch)
		else:
			shuffled.append(ch)
	for i in range(shuffled.size() - 1, 0, -1):
		var j := state.rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	shown_choices = shuffled + fixed


## 表示中の index 番目の選択肢を選ぶ。次のシーンへ進む。
func choose(index: int) -> void:
	var ch: Dictionary = shown_choices[index]
	Fx.apply(ch.get("effects", []), state, db, notices)
	var next_id := str(ch.get("next", ""))
	if ch.has("check"):
		var r := roll_check(ch["check"])
		last_check = r
		notices.append(check_notice(ch["check"], r))
		var outcome: String = r["outcome"]
		var effect_key := "effects_" + outcome
		if outcome == Rules.OUTCOME_CRITICAL and not ch.has("effects_critical"):
			effect_key = "effects_success"
		Fx.apply(ch.get(effect_key, []), state, db, notices)
		var next_key := "next_" + outcome
		if outcome == Rules.OUTCOME_CRITICAL and not ch.has("next_critical"):
			next_key = "next_success"
		next_id = str(ch.get(next_key, ""))
	if next_id.is_empty():
		push_error("選択肢 '%s' の遷移先がありません" % str(ch.get("text", "")))
		return
	enter(next_id)


## 判定を行う。chk は選択肢の "check" 定義。
func roll_check(chk: Dictionary, roll_override: int = -1) -> Dictionary:
	var who := str(chk.get("who", DEFAULT_WHO))
	var mod := int(chk.get("mod", 0))
	for m in chk.get("mods", []):
		if Cond.test(str(m.get("if", "")), state):
			mod += int(m.get("value", 0))
	var roll := roll_override if roll_override >= 0 else (forced_roll if forced_roll >= 0 else Rules.roll_dice(state.rng))
	return Rules.evaluate(roll, state.stat_of(who, str(chk["stat"])),
		state.skill_of(who, str(chk.get("skill", ""))), mod, int(chk["difficulty"]))


func check_notice(chk: Dictionary, r: Dictionary) -> String:
	var label: String = Rules.OUTCOME_LABEL[r["outcome"]]
	var s := "〔判定：%s → %s" % [chk["stat"], label]
	if show_roll_detail:
		s += "（出目%d + 能力%d + スキル%d + 補正%d = %d／難易度%d）" % [
			r["roll"], r["stat"], r["skill_lv"] * Rules.SKILL_WEIGHT, r["mod"], r["total"], r["difficulty"]]
	return s + "〕"
