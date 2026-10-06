class_name MatchingState
extends RefCounted
## 探索フェーズの進行状態と照合ロジック。UI に依存しない（ヘッドレスでテスト可能）。

enum DropResult { MATCHED, MISMATCH, IGNORED }

var adventurer: Adventurer
var events: Array[EventDef] = []
var event_index := -1
var current: EventDef
var time_left := 0.0
var matched := false
## 以前の探索で埋めた（訂正した）ノートのおかげで、照合済みで始まったイベントか
var auto_matched := false
## そのときの、すでに埋まっていた箇所の id
var auto_target: StringName = &""
var resolved := false
## 埋まった穴・訂正した箇所の id（探索をまたいで保持される = ノートの成長）。GameSession と同じ辞書を共有できる
var filled_blanks: Dictionary = {}
## 埋まった（訂正された）ときに表示する語。id -> 語
var fill_texts: Dictionary = {}
## この探索で新しくノートに書けた箇所（id の並び）
var learned: Array[StringName] = []
## 穴 id -> それを持つノート項目 id
var blank_owner: Dictionary = {}
## 訂正箇所（ノートの記述が間違っているかもしれない場所）の id
var fix_ids: Dictionary = {}
var reward := Rules.INITIAL_REWARD
var results: Array[Dictionary] = []


func _init(p_adventurer: Adventurer, p_events: Array[EventDef], p_entries: Array[NoteEntry],
		p_filled: Dictionary = {}) -> void:
	adventurer = p_adventurer
	events = p_events
	filled_blanks = p_filled
	for entry in p_entries:
		for blank_id in entry.blank_fills:
			blank_owner[StringName(blank_id)] = entry.id
			fill_texts[StringName(blank_id)] = str(entry.blank_fills[blank_id])
		for fix_id in entry.fix_olds:
			fix_ids[StringName(fix_id)] = true


func has_next() -> bool:
	return event_index + 1 < events.size()


func begin_next_event() -> bool:
	if not has_next():
		return false
	event_index += 1
	current = events[event_index]
	time_left = current.time_limit
	matched = false
	auto_matched = false
	auto_target = &""
	resolved = false
	# このイベントの正解が、以前の探索で埋めた（訂正した）箇所なら、照合済みで始まる
	for target in current.keyword_targets.values():
		var target_id := StringName(target)
		if is_blank(target_id) and is_blank_filled(target_id):
			matched = true
			auto_matched = true
			auto_target = target_id
			break
	return true


## 時間を進める。ちょうど時間切れになった瞬間だけ true を返す。
func tick(delta: float) -> bool:
	if current == null or resolved or time_left <= 0.0:
		return false
	time_left = maxf(0.0, time_left - delta)
	return time_left <= 0.0


func is_blank(target_id: StringName) -> bool:
	return blank_owner.has(target_id)


func is_fix(target_id: StringName) -> bool:
	return fix_ids.has(target_id)


func is_blank_filled(blank_id: StringName) -> bool:
	return filled_blanks.has(blank_id)


## キーワードをドロップ先へ運んだときの判定。
func drop(keyword_id: StringName, target_id: StringName) -> DropResult:
	if current == null or resolved or matched:
		return DropResult.IGNORED
	if is_blank(target_id) and is_blank_filled(target_id):
		return DropResult.IGNORED
	var correct: StringName = current.keyword_targets.get(keyword_id, &"")
	if correct != &"" and correct == target_id:
		matched = true
		if is_blank(target_id):
			filled_blanks[target_id] = true
			learned.append(target_id)
		return DropResult.MATCHED
	time_left = maxf(0.0, time_left - Rules.MISMATCH_PENALTY_SEC)
	return DropResult.MISMATCH


## 能力値を選んで判定する。chosen が空なら無指示（時間切れ）。
func resolve(chosen: StringName, rng: RandomNumberGenerator) -> Dictionary:
	if current == null or resolved:
		return {}
	resolved = true
	var mod := Judge.modifier(matched, chosen, current.required_stat)
	var stat_value := adventurer.stat_for(chosen)
	var roll := rng.randi_range(1, Rules.DICE_SIDES)
	var res := Judge.resolve(current.base_target, mod, stat_value, roll)
	var loss := 0.0
	if res["crit_fail"]:
		loss = Rules.CRIT_FAIL_REWARD_LOSS
	elif not res["success"]:
		loss = Rules.FAIL_REWARD_LOSS
	reward = floorf(reward * (1.0 - loss))
	res["chosen"] = chosen
	res["matched"] = matched
	res["modifier"] = mod
	res["base_target"] = current.base_target
	res["stat_value"] = stat_value
	res["loss_rate"] = loss
	results.append(res)
	return res
