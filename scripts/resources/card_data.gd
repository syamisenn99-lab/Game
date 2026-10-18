class_name CardData
extends Resource
## カードの定義（データ）。ラン中の1枚ごとの実体は CardInstance。
## 効果は EffectData の配列で持ち、説明文はそこから自動生成する。

enum CardType { ATTACK, SKILL }
enum Rarity { BASIC, COMMON, RARE }

@export var id: StringName
@export var display_name: String = ""
@export var cost: int = 1
@export var card_type: CardType = CardType.ATTACK
@export var rarity: Rarity = Rarity.BASIC
@export var effects: Array[EffectData] = []
@export var keywords: Array[String] = []


func needs_target() -> bool:
	for e in effects:
		if e.needs_target():
			return true
	return false


func describe() -> String:
	var parts: Array[String] = []
	for e in effects:
		parts.append(e.describe())
	for k in keywords:
		parts.append(Keyword.label(k))
	return "、".join(parts)
