class_name SealMemoryEffect
extends EffectData
## ランダムな記憶を数ターン封印する（敵の行動用）。

@export var turns: int = 2


func apply(battle: BattleState, _source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	battle.seal_random_memory(turns)


func describe() -> String:
	return "ランダムな記憶を%dターン封印" % turns


func intent_text(_battle: BattleState, _source: Combatant) -> String:
	return "記憶封印"
