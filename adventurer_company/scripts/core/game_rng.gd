class_name GameRng
extends RefCounted
## ゲーム中の乱数の唯一の入口。シードを固定すれば同じ展開を再現できる。

var _rng := RandomNumberGenerator.new()
var seed_value: int = 0


func _init(new_seed: int = 0) -> void:
	set_seed(new_seed)


func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	_rng.seed = new_seed


## 1〜sides の目
func roll(sides: int) -> int:
	return _rng.randi_range(1, sides)


## 0〜size-1 の添字
func pick_index(size: int) -> int:
	return _rng.randi_range(0, size - 1)
