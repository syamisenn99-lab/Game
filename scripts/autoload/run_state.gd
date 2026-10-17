extends Node
## ラン全体の状態（オートロード）。今は「シードと乱数」だけ。
## 乱数はすべてここの rng から作り、同じシードで同じ展開を再現できるようにする。

var run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func start_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		seed_value = picker.randi() % 1000000
	run_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed
	print("[RunState] ラン開始 シード=%d" % run_seed)
