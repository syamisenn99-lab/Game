class_name ApplyStatusEffect
extends EffectData
## 状態異常（毒・筋力・脆弱・弱体）を付ける。

@export var status: StringName = &"poison"
@export var stacks: int = 1
@export var target: EffectData.Target = EffectData.Target.OPPONENT


func apply(battle: BattleState, source: Combatant, chosen: Combatant, _card: CardInstance) -> void:
	for t in battle.resolve_targets(source, target, chosen):
		battle.add_status(t, status, stacks)


func needs_target() -> bool:
	return target == EffectData.Target.OPPONENT


func describe() -> String:
	return "%s%s%d" % [target_prefix(target), Status.label(status), stacks]


func intent_text(_battle: BattleState, _source: Combatant) -> String:
	if target == EffectData.Target.SELF:
		return "%s+%d" % [Status.label(status), stacks]
	return "%s%dを付与" % [Status.label(status), stacks]
