class_name OutcomeDef
extends RefCounted
## 判定結果の1段階（data/balance.json の outcomes の1件）。

var id: String = ""
var name: String = ""
## 0 が最良。outcomes の並び順
var rank: int = 0
## 差 = 判定値 − 難易度 がこれ以上ならこの段階。has_min_diff が false なら下限なし
var min_diff: int = 0
var has_min_diff: bool = true
var reward_rate: float = 0.0
var reputation: int = 0
## 負傷の種類（injuries のキー）。空なら負傷なし
var injury: String = ""
