extends Node
## 常駐オートロード。DB・状態・エンジン・設定・音の差し込み口を持つ。

const SETTINGS_PATH := "user://settings.json"
const BGM_DIR := "res://assets/audio/bgm/"
const SE_DIR := "res://assets/audio/se/"

var db := GameDB.new()
var state := GameState.new()
var engine: StoryEngine
var validation: Dictionary = {}

## text_speed: 1秒あたりの表示文字数（0 = 即時表示）
var settings := {"text_speed": 45, "master_volume": 0.8, "show_roll_detail": false}

var _bgm_player: AudioStreamPlayer
var _se_player: AudioStreamPlayer
var _bgm_id := ""


func _ready() -> void:
	db.load_all()
	validation = DataValidator.validate(db)
	if OS.is_debug_build():
		for line in validation["errors"]:
			push_error("[データ検証] " + line)
		for line in validation["warnings"]:
			push_warning("[データ検証] " + line)
	engine = StoryEngine.new(db, state)
	_bgm_player = AudioStreamPlayer.new()
	_se_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	add_child(_se_player)
	load_settings()


func new_game() -> void:
	engine.show_roll_detail = settings["show_roll_detail"]
	engine.start_new_game()


# ---------------------------------------------------------------- 設定

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			for k in settings:
				if d.has(k):
					settings[k] = d[k]
	apply_settings()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(settings["master_volume"]), 0.0001, 1.0)))
	if engine:
		engine.show_roll_detail = bool(settings["show_roll_detail"])


# ---------------------------------------------------------------- BGM・効果音の差し込み口
# assets/audio/bgm/<id>.ogg|mp3|wav を置くと、シーンの "bgm": "<id>" で鳴る（SE も同様に "se"）。

func play_bgm(id: String) -> void:
	if id == _bgm_id:
		return
	_bgm_id = id
	if id.is_empty():
		_bgm_player.stop()
		return
	var stream := _find_audio(BGM_DIR, id)
	if stream:
		_bgm_player.stream = stream
		_bgm_player.play()


func play_se(id: String) -> void:
	var stream := _find_audio(SE_DIR, id)
	if stream:
		_se_player.stream = stream
		_se_player.play()


func _find_audio(dir: String, id: String) -> AudioStream:
	for ext in ["ogg", "mp3", "wav"]:
		var p := "%s%s.%s" % [dir, id, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null
