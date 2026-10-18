class_name HealEffect
extends EffectData
## HPを回復する（上限まで）。

@export var amount: int = 0
@export var target: EffectData.Target = EffectData.Target.SELF


func apply(battle: BattleState, source: Combatant, chosen: Combatant, _card: CardInstance) -> void:
	for t in battle.resolve_targets(source, target, chosen):
		battle.heal(t, amount)


func describe() -> String:
	return "HPを%d回復する" % amount


func set_value(value: int) -> void:
	amount = value
