class_name CheckModifiers
extends RefCounted
## 1回の判定にかかる補正の内訳。表示・確率計算・実判定のすべてがこれを使う。

var difficulty: int = 0
var dice_sides: int = 20
## 振るダイスの数（高い方を使う）。強運なら 2
var dice_count: int = 1
## この結果ID より悪くならない。空なら下限なし
var outcome_floor: String = ""
## {"label": String, "value": int}
var items: Array[Dictionary] = []
## 補正以外の効果の説明（強運・鉄壁など）
var notes: Array[String] = []


func add(label: String, value: int) -> void:
	items.append({"label": label, "value": value})


func total_bonus() -> int:
	var total := 0
	for item: Dictionary in items:
		total += int(item["value"])
	return total


## 確率表のキャッシュ用。判定結果を左右する値だけを並べる
func key() -> String:
	return "%d|%d|%d|%d|%s" % [difficulty, total_bonus(), dice_sides, dice_count, outcome_floor]
