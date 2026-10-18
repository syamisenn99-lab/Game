class_name DrawEffect
extends EffectData
## カードを引く（プレイヤーのみ）。

@export var count: int = 1


func apply(battle: BattleState, source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	if source == battle.player:
		battle.draw_cards(count)


func describe() -> String:
	return "%d枚引く" % count
