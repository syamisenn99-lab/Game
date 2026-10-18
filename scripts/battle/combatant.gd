class_name Combatant
extends RefCounted
## 戦う側（プレイヤーも敵も）に共通のHP・ブロック・状態異常。

var display_name: String = ""
var hp: int = 1
var max_hp: int = 1
var block: int = 0
var statuses: Dictionary = {}  # StringName -> int


func is_alive() -> bool:
	return hp > 0


func stacks(id: StringName) -> int:
	return int(statuses.get(id, 0))


func add_stacks(id: StringName, amount: int) -> void:
	var total := stacks(id) + amount
	if total <= 0:
		statuses.erase(id)
	else:
		statuses[id] = total


func status_text() -> String:
	var parts: Array[String] = []
	for id in Status.ALL:
		if stacks(id) > 0:
			parts.append("%s%d" % [Status.label(id), stacks(id)])
	return " ".join(parts)
