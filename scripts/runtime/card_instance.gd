class_name CardInstance
extends RefCounted
## ラン中のカード1枚（実体）。同じ定義のカードでも1枚ずつ別物として扱う。

static var _next_uid: int = 1

var uid: int
var data: CardData
## 思い出（0〜上限）。戦闘中にこのカードを使うたびに増える
var omoide: int = 0


func _init(p_data: CardData) -> void:
	data = p_data
	uid = _next_uid
	_next_uid += 1


static func reset_uids() -> void:
	_next_uid = 1


func has_keyword(keyword: String) -> bool:
	return data.keywords.has(keyword)
