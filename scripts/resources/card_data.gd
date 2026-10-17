class_name CardData
extends Resource
## カードの定義（データ）。ラン中の1枚ごとの実体は別のクラスで持つ。
## マイルストーン2で、効果は EffectData の配列に置き換える予定（今は最小形）。

enum CardType { ATTACK, SKILL }

@export var id: StringName
@export var display_name: String = ""
@export var cost: int = 1
@export var card_type: CardType = CardType.ATTACK
@export var damage: int = 0
@export var block: int = 0


func describe() -> String:
	var parts: Array[String] = []
	if damage > 0:
		parts.append("%dダメージ" % damage)
	if block > 0:
		parts.append("ブロック%d" % block)
	return "、".join(parts)
