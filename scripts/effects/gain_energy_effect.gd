class_name GainEnergyEffect
extends EffectData
## エネルギーを得る（プレイヤーのみ）。

@export var amount: int = 1


func apply(battle: BattleState, source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	if source == battle.player:
		battle.gain_energy(amount)


func describe() -> String:
	return "エネルギー%dを得る" % amount


func set_value(value: int) -> void:
	amount = value
