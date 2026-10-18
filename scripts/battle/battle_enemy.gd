class_name BattleEnemy
extends Combatant
## 戦闘中の敵1体（定義データ EnemyData から作る）。次の行動は先に決めておき、予告に使う。

var data: EnemyData
var action_index: int = 0
var next_action: EnemyAction


func _init(p_data: EnemyData, p_name: String) -> void:
	data = p_data
	display_name = p_name
	max_hp = p_data.max_hp
	hp = max_hp


func choose_next(rng: RandomNumberGenerator, first: bool = false) -> void:
	var actions := data.actions
	if actions.is_empty():
		return
	if data.pattern == EnemyData.Pattern.SEQUENCE:
		action_index = 0 if first else (action_index + 1) % actions.size()
	else:
		var total := 0.0
		for a in actions:
			total += a.weight
		var roll := rng.randf() * total
		for i in actions.size():
			roll -= actions[i].weight
			if roll <= 0.0 or i == actions.size() - 1:
				action_index = i
				break
	next_action = actions[action_index]


## 「カウントダウン」付きの大技まで、あと何ターンか（0=今回、-1=なし）。順番どおりの敵だけ対応。
func turns_until_countdown() -> int:
	if data.pattern != EnemyData.Pattern.SEQUENCE:
		return -1
	var n := data.actions.size()
	for k in n:
		if data.actions[(action_index + k) % n].countdown:
			return k
	return -1
