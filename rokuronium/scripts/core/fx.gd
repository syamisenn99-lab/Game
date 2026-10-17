class_name Fx
extends RefCounted
## 効果（effects）の実行。シナリオ JSON の { "op": "...", ... } を状態に反映する。
##
## どの効果にも "if": "条件式" を付けられる（条件を満たすときだけ実行）。
## "silent": true を付けると、本文冒頭の通知（〔入手：…〕など）を出さない。

## 使える op と必須キー。DataValidator もこの表を見て検査する。
const OP_SPECS := {
	"set_flag": ["key", "value"],
	"add_flag": ["key", "value"],        # 数値フラグの加算
	"add_money": ["value"],              # 銅貨(整数)または "3銀" のような文字列。負で支払い
	"add_item": ["id"],                  # count 省略時 1
	"remove_item": ["id"],
	"add_hp": ["who", "value"],
	"add_mp": ["who", "value"],
	"add_exp": ["value"],
	"add_affinity": ["who", "value"],    # 出会っていなければ自動で出会い扱い
	"meet": ["who"],                     # ヒロインと出会う。value で初期親密度
	"advance_time": [],                  # "slot": "昼" または "steps": 1
	"set_time": [],                      # "day" / "slot"
	"set_location": ["value"],
}

## 仕様にあるが、後のフェーズで実装する op（使われたら実行せず警告する）。
const RESERVED_OPS: Array[String] = ["start_battle", "accept_quest", "complete_quest", "open_shop"]


## effects を順に適用する。通知用の文字列は notices に追加される。
static func apply(effects: Array, state: GameState, db: GameDB, notices: Array) -> void:
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if e.has("if") and not Cond.test(str(e["if"]), state):
			continue
		_apply_one(e, state, db, notices)


static func _note(e: Dictionary, notices: Array, text: String) -> void:
	if not e.get("silent", false):
		notices.append("〔%s〕" % text)


static func _signed(n: int) -> String:
	return "+%d" % n if n >= 0 else "%d" % n


static func _apply_one(e: Dictionary, state: GameState, db: GameDB, notices: Array) -> void:
	var op := str(e.get("op", ""))
	match op:
		"set_flag":
			state.flags[str(e["key"])] = e["value"]
		"add_flag":
			var k := str(e["key"])
			state.flags[k] = int(state.flags.get(k, 0)) + int(e["value"])
		"add_money":
			var v := Money.parse(e["value"])
			state.money = maxi(state.money + v, 0)
			var m := Money.format(absi(v))
			_note(e, notices, "所持金 %s%s" % ["+" if v >= 0 else "-", m])
		"add_item":
			var id := str(e["id"])
			var n := int(e.get("count", 1))
			state.inventory[id] = state.item_count(id) + n
			_note(e, notices, "入手：%s ×%d" % [db.item_name(id), n])
		"remove_item":
			var id := str(e["id"])
			var n := int(e.get("count", 1))
			var left := state.item_count(id) - n
			if left > 0:
				state.inventory[id] = left
			else:
				state.inventory.erase(id)
			_note(e, notices, "使用：%s ×%d" % [db.item_name(id), n])
		"add_hp", "add_mp":
			var who := str(e["who"])
			if not state.party.has(who):
				return
			var m: Dictionary = state.party[who]
			var key := "hp" if op == "add_hp" else "mp"
			var v := int(e["value"])
			# 戦闘以外の効果ではHPを0にしない（敗北は戦闘側のイベントで扱う）
			var floor_v := 1 if key == "hp" else 0
			m[key] = clampi(int(m[key]) + v, floor_v, int(m["max_" + key]))
			_note(e, notices, "%s %s %s" % [m["name"], key.to_upper(), _signed(v)])
		"add_exp":
			state.total_exp += int(e["value"])
			_note(e, notices, "経験値 +%d" % int(e["value"]))
		"add_affinity":
			var who := str(e["who"])
			if not state.affinity.has(who):
				state.affinity[who] = int((db.characters.get(who, {}) as Dictionary).get("affinity", 0))
			state.affinity[who] = clampi(int(state.affinity[who]) + int(e["value"]), 0, 100)
		"meet":
			var who := str(e["who"])
			if not state.affinity.has(who):
				var base := int((db.characters.get(who, {}) as Dictionary).get("affinity", 0))
				state.affinity[who] = int(e.get("value", base))
		"advance_time":
			if e.has("slot"):
				state.advance_to_slot(str(e["slot"]))
			else:
				state.advance_steps(int(e.get("steps", 1)))
		"set_time":
			if e.has("day"):
				state.day = int(e["day"])
			if e.has("slot"):
				state.slot = str(e["slot"])
		"set_location":
			state.location = str(e["value"])
		_:
			if op in RESERVED_OPS:
				push_warning("op '%s' はまだ実装されていません（フェーズ2以降）" % op)
			else:
				push_error("未知の op: '%s'" % op)
