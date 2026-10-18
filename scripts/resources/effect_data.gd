class_name EffectData
extends Resource
## 効果の基底クラス。apply で実行し、describe で説明文を自動生成する。
## 新しい効果の種類を足すときは、このクラスを継承したスクリプトを scripts/effects/ に作る。

## 対象。カードなら「自分／選んだ敵／敵全体」、敵の行動なら「自分／プレイヤー／プレイヤー」の意味になる
enum Target { SELF, OPPONENT, ALL_OPPONENTS }


func apply(_battle: BattleState, _source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	pass


## カードの説明文
func describe() -> String:
	return ""


## 敵の行動予告に出す短い文（既定はカードの説明文と同じ）
func intent_text(_battle: BattleState, _source: Combatant) -> String:
	return describe()


## 使うときに敵を1体選ぶ必要があるか
func needs_target() -> bool:
	return false


func target_prefix(target: Target) -> String:
	match target:
		Target.OPPONENT: return "敵に"
		Target.ALL_OPPONENTS: return "敵全体に"
	return ""
