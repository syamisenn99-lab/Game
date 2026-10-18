class_name DiscardHandEffect
extends EffectData
## 手札をすべて捨てさせる（敵の行動用。「保持」も捨てる）。

func apply(battle: BattleState, _source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	battle.discard_whole_hand()


func describe() -> String:
	return "手札をすべて捨てさせる"
