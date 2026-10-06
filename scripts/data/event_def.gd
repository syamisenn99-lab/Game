class_name EventDef
extends Resource
## 探索中の1イベント（報告1件分）。

@export var id: StringName
## キーワードは "[kw:id]表示語[/kw]" で埋め込む
@export_multiline var report: String
@export var time_limit: float = 25.0
@export var base_target: int = 12
@export var required_stat: StringName
## キーワード id -> 正しいドロップ先（ノート項目 id または穴 id）
@export var keyword_targets: Dictionary = {}
@export var correct_line: String
## 以前の探索で埋めた（訂正した）ノートのおかげで、照合済みで始まったときの主人公のセリフ
@export var known_line: String
@export var success_text: String
@export var fail_text: String
