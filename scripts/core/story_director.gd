class_name StoryDirector
extends RefCounted
## どの場面を、いつ出すか。見た場面と、探索を終えた回数から決める。

const STORY_SCENE := "res://scenes/story_screen.tscn"


## 準備画面を開いたときに出す場面（なければ null）。条件を満たした、まだ見ていない最初の場面。
static func next_for_prep() -> StoryScene:
	for scene in StoryData.all():
		if scene.trigger == &"start" and _available(scene):
			return scene
	return null


## 冒険者と出発するときに出す場面（その冒険者の紹介。なければ null）
static func intro_for_depart(adventurer_id: StringName) -> StoryScene:
	for scene in StoryData.all():
		if scene.trigger == &"depart" and scene.adventurer == adventurer_id and _available(scene):
			return scene
	return null


## 条件を満たしていて、まだ見ていない場面か
static func _available(scene: StoryScene) -> bool:
	if GameSession.has_seen(scene.id):
		return false
	# プロローグを見るまでは、ほかの場面は出ない
	if scene.id != &"prologue" and not GameSession.has_seen(&"prologue"):
		return false
	for adventurer_id in scene.after_runs:
		if GameSession.runs_of(StringName(adventurer_id)) < int(scene.after_runs[adventurer_id]):
			return false
	for required in scene.requires_seen:
		if not GameSession.has_seen(required):
			return false
	return true


## 場面を再生する。終わったら next_path のシーンへ進む。
static func play(tree: SceneTree, scene_id: StringName, next_path: String) -> void:
	GameSession.story_scene = scene_id
	GameSession.story_next = next_path
	GameSession.go_to(tree, STORY_SCENE)
