class_name EnemyAction
extends Resource
## 敵の1回の行動。効果の配列から予告の文を自動生成する。

@export var label: String = ""
@export var effects: Array[EffectData] = []
## 重み付きランダムの敵で使う重み
@export var weight: float = 1.0
## true なら、この行動までのカウントダウンを画面に出す
@export var countdown: bool = false


func intent_text(battle: BattleState, source: Combatant) -> String:
	var parts: Array[String] = []
	for e in effects:
		parts.append(e.intent_text(battle, source))
	return " + ".join(parts)
