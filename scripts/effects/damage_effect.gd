class_name DamageEffect
extends EffectData
## ダメージ。筋力・弱体・脆弱はここで計算される。

@export var amount: int = 0
@export var hits: int = 1
@export var target: EffectData.Target = EffectData.Target.OPPONENT
## このカードの思い出1つにつき追加されるダメージ（決別の一閃など）
@export var omoide_bonus_per: int = 0


func apply(battle: BattleState, source: Combatant, chosen: Combatant, card: CardInstance) -> void:
	var base := amount
	if card != null:
		base += card.omoide * omoide_bonus_per
	for t in battle.resolve_targets(source, target, chosen):
		for i in hits:
			if not t.is_alive():
				break
			battle.hit(source, t, base)


func needs_target() -> bool:
	return target == EffectData.Target.OPPONENT


func describe() -> String:
	var text := ""
	if target == EffectData.Target.ALL_OPPONENTS:
		text = "敵全体に"
	text += "%dダメージ" % amount
	if hits > 1:
		text += "×%d回" % hits
	if omoide_bonus_per > 0:
		text += "＋このカードの思い出×%dダメージ" % omoide_bonus_per
	return text


func intent_text(battle: BattleState, source: Combatant) -> String:
	var per_hit := battle.calc_damage(amount, source, battle.player)
	return "攻撃 %d" % per_hit if hits <= 1 else "攻撃 %d×%d" % [per_hit, hits]
