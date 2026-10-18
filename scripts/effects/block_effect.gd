class_name BlockEffect
extends EffectData
## ブロックを得る。

@export var amount: int = 0


func apply(battle: BattleState, source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	battle.gain_block(source, amount)


func describe() -> String:
	return "ブロック%d" % amount


func intent_text(_battle: BattleState, _source: Combatant) -> String:
	return "防御 %d" % amount


func set_value(value: int) -> void:
	amount = value
