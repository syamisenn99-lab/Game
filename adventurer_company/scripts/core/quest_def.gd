class_name QuestDef
extends RefCounted
## クエストの定義（data/quests.json の1件）。

var id: String = ""
var name: String = ""
var difficulty: int = 0
## 期間（週）
var weeks: int = 1
var reward: int = 0
## 推奨職業（職業ID）
var job: String = ""
var required_reputation: int = 0
## 掲示板に出る週
var appear_week: int = 1
## 依頼文
var description: String = ""
## 常設依頼か。常設依頼は掲示期限がなく、完了すると次の週にまた受けられる（同時に受けられるのは1組だけ）
var repeatable: bool = false
## この依頼で評判が上がるのは、この値まで（0 未満なら上限なし）。下がる方には効かない
var reputation_cap: int = -1
