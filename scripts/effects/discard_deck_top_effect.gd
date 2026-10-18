class_name DiscardDeckTopEffect
extends EffectData
## 山札の上から数枚を捨て札へ送る（敵の行動用）。

@export var count: int = 1


func apply(battle: BattleState, _source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	battle.discard_deck_top(count)


func describe() -> String:
	return "山札の上から%d枚を捨て札へ送る" % count


func intent_text(_battle: BattleState, _source: Combatant) -> String:
	return "山札を%d枚捨てさせる" % count
