class_name CardPool
extends Resource
## 初期デッキの抽選元。レア度ごとの重みで選ぶ。

@export var cards: Array[CardData] = []
## 必ず入れるカード（打撃と防御）と、それぞれの最低枚数
@export var guaranteed: Array[CardData] = []
@export var guaranteed_count: int = 4
@export var weight_basic: float = 50.0
@export var weight_common: float = 40.0
@export var weight_rare: float = 10.0


func weight_of(rarity: CardData.Rarity) -> float:
	match rarity:
		CardData.Rarity.BASIC: return weight_basic
		CardData.Rarity.COMMON: return weight_common
	return weight_rare
