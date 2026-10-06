class_name ShopItem
extends Resource
## 準備フェーズで買えるもの。
##   kind = &"info" … ダンジョンの情報。買うと、target のノートの箇所が埋まる（訂正される）
##   kind = &"item" … 道具。買うと、効果がずっと続く

@export var id: StringName
@export var kind: StringName
@export var title: String
@export var description: String
@export var price: int
## kind が info のとき、埋まるノートの箇所の id
@export var target: StringName
