class_name StoryDirector
extends RefCounted
## どの場面を、いつ出すか。見た場面と、探索を終えた回数から決める。

const STORY_SCENE := "res://scenes/story_screen.tscn"
const MATCHING_SCENE := "res://scenes/matching_screen.tscn"


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
	# 導入（プロローグ、チュートリアル、プロローグのつづき）を終えるまでは、ほかの場面は出ない
	if scene.id != &"prologue" and scene.id != &"prologue_2" and not GameSession.has_seen(&"prologue_2"):
		return false
	if scene.id == &"prologue_2" and not GameSession.has_seen(&"prologue"):
		return false
	for adventurer_id in scene.after_runs:
		if GameSession.runs_of(StringName(adventurer_id)) < int(scene.after_runs[adventurer_id]):
			return false
	for required in scene.requires_seen:
		if not GameSession.has_seen(required):
			return false
	return true


## プロローグは見たが、チュートリアルの冒険がまだ終わっていないか（途中でやめた場合は、そこから再開する）
static func pending_first_adventure() -> bool:
	return GameSession.has_seen(&"prologue") and not GameSession.has_seen(&"first_adventure")


## 場面を再生する。終わったら next_path のシーンへ進む。
## チュートリアルを始める場面（プロローグ）は、終わったらチュートリアルの冒険へ進む。
static func play(tree: SceneTree, scene_id: StringName, next_path: String) -> void:
	var scene := StoryData.find(scene_id)
	GameSession.story_scene = scene_id
	GameSession.story_next = next_path
	if scene != null and scene.starts_first_adventure and not GameSession.has_seen(&"first_adventure"):
		GameSession.first_adventure_active = true
		GameSession.story_next = MATCHING_SCENE
	GameSession.go_to(tree, STORY_SCENE)


## チュートリアルの冒険を始める（プロローグのあと、または途中から再開するとき）
static func start_first_adventure(tree: SceneTree) -> void:
	GameSession.first_adventure_active = true
	GameSession.go_to(tree, MATCHING_SCENE)
