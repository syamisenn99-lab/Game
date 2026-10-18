class_name MemoryInstance
extends RefCounted
## ラン中の記憶1つ。手放した瞬間の思い出で段階が決まり、以降は変わらない。

static var _next_uid: int = 1

var uid: int
var data: MemoryData
var tier: int = 0
var source_name: String = ""
## 封印されている残りターン数（0なら発動できる）
var sealed_turns: int = 0


func _init(p_data: MemoryData, p_tier: int, p_source_name: String) -> void:
	data = p_data
	tier = p_tier
	source_name = p_source_name
	uid = _next_uid
	_next_uid += 1


static func reset_uids() -> void:
	_next_uid = 1


func tier_label() -> String:
	return MemoryData.TIER_LABELS[tier]


func describe() -> String:
	return data.describe(tier)
