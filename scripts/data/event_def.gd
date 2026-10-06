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
## 冒険者のスケッチ（assets/illustrations/sketches/<この名前>.png）。空なら絵なし
@export var sketch: StringName
## 初めての冒険の案内。物語のセリフとして、操作を伝える。キー: report（文字送り中）, drag（運ぶ言葉と行き先を示す）,
## wrong_drop, matched, command（選ぶ指示を示す）, wrong_command, result。値は {"speaker": 名前（空なら語り）, "text": 文}
@export var coach: Dictionary = {}
## 初めての冒険で、出来事の前と後に挟む会話。各行は StoryScene.lines と同じ形（speaker / text / portrait）
var before_lines: Array[Dictionary] = []
var after_lines: Array[Dictionary] = []
