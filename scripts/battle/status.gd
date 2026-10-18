class_name Status
extends RefCounted
## 状態異常の種類（MVPは4種類）。効果の計算は BattleState が行う。

const POISON := &"poison"
const STRENGTH := &"strength"
const VULNERABLE := &"vulnerable"
const WEAK := &"weak"
const ALL: Array[StringName] = [POISON, STRENGTH, VULNERABLE, WEAK]


static func label(id: StringName) -> String:
	match id:
		POISON: return "毒"
		STRENGTH: return "筋力"
		VULNERABLE: return "脆弱"
		WEAK: return "弱体"
	return String(id)
