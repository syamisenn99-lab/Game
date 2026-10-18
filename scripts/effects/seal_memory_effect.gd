class_name SealMemoryEffect
extends EffectData
## ランダムな記憶を数ターン封印する（敵の行動用）。
## 記憶はマイルストーン3で作るので、今は予告と記録だけ出す仮の実装。

@export var turns: int = 2


func apply(battle: BattleState, _source: Combatant, _chosen: Combatant, _card: CardInstance) -> void:
	battle.add_log("記憶の封印は未実装（マイルストーン3で対応）")


func describe() -> String:
	return "ランダムな記憶を%dターン封印" % turns


func intent_text(_battle: BattleState, _source: Combatant) -> String:
	return "記憶封印"
