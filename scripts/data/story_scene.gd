class_name StoryScene
extends Resource
## ノベル風の場面1つ分。

@export var id: StringName
## 場面の題（手がかり帳などに出す）
@export var title: String
## いつ出るか。&"start" = 準備画面を開いたとき、&"depart" = 冒険者と出発するとき
@export var trigger: StringName = &"start"
## trigger が depart のとき、どの冒険者と出発するときか
@export var adventurer: StringName
## 冒険者id -> その冒険者との探索を終えた回数（これ以上）
@export var after_runs: Dictionary = {}
## これらの場面を見たあとでないと出ない
@export var requires_seen: Array[StringName] = []
## 見終わったあと、チュートリアルの冒険に進む場面か
@export var starts_first_adventure := false
## 手がかり帳に載せる場合の見出しと要約（空なら手がかりではない）
@export var clue_title: String
@export var clue_summary: String
## 各行: {"speaker": 名前（空なら語り）, "text": 文, "portrait": 顔の絵の名前（空なら顔なし）}
var lines: Array[Dictionary] = []


func is_clue() -> bool:
	return clue_title != ""
