class_name AttackBonusEffect
extends EffectData
## 今使っている攻撃カードのダメージを増やす（記憶「研ぎ澄まし」用）。

@export var amount: int = 0


func apply(battle: BattleState, _source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	battle.attack_bonus += amount


func describe() -> String:
	return "その攻撃に＋%dダメージ" % amount


func set_value(value: int) -> void:
	amount = value
