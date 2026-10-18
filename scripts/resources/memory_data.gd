class_name MemoryData
extends Resource
## 記憶の定義。手放したカードが変わるパッシブ効果。
## 思い出の量で「淡い／確かな／鮮明な」の3段階に分かれ、段階ごとに効果量(values)が変わる。

enum Timing { BATTLE_START, TURN_START, CARD_PLAYED, RESHUFFLE, BATTLE_WIN }
enum CardFilter { ANY, ATTACK, SKILL }

const TIER_LABELS: Array[String] = ["淡い", "確かな", "鮮明な"]

@export var id: StringName
@export var display_name: String = ""
@export var timing: Timing = Timing.BATTLE_START
## CARD_PLAYED のとき、どの種別のカードで発動するか
@export var card_filter: CardFilter = CardFilter.ANY
## CARD_PLAYED のとき、1ターンに何枚目で発動するか（0なら毎回）
@export var nth_in_turn: int = 0
## 淡い／確かな／鮮明な の順の効果量
@export var values: Array[int] = [0, 0, 0]
@export var effects: Array[EffectData] = []
## 説明文のひな形。{v} が効果量に置き換わる
@export var template: String = ""


func describe(tier: int = -1) -> String:
	if tier < 0:
		var all: Array[String] = []
		for v in values:
			all.append(str(v))
		return template.replace("{v}", "／".join(all))
	return template.replace("{v}", str(values[tier]))


func matches_card(card: CardInstance, plays_of_type_this_turn: int) -> bool:
	if card_filter == CardFilter.ATTACK and card.data.card_type != CardData.CardType.ATTACK:
		return false
	if card_filter == CardFilter.SKILL and card.data.card_type != CardData.CardType.SKILL:
		return false
	return nth_in_turn == 0 or plays_of_type_this_turn == nth_in_turn
