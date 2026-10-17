class_name Sfx
extends RefCounted
## 効果音の再生。音は Synth で合成し、必要になったときに作る。
## 画面から Sfx.play(&"match") のように呼ぶだけで使える。

const POOL_SIZE := 8
const SETTINGS_PATH := "user://settings.cfg"

static var muted := false
static var volume_db := -5.0
## 実際に鳴らした音の履歴（テスト用）
static var played_log: Array[StringName] = []

static var _streams: Dictionary = {}
static var _host: Node
static var _players: Array[AudioStreamPlayer] = []
static var _settings_loaded := false


## 再生用ノードと合成済みの音を片付ける（テスト終了時など）
static func shutdown() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	_host = null
	_players.clear()
	_streams.clear()


static func names() -> Array[StringName]:
	return [&"grab", &"hover", &"match", &"fix", &"stamp", &"mismatch", &"ting", &"known",
		&"tick", &"success", &"fail", &"crit_fail", &"warn", &"type", &"click", &"select", &"coin"]


static func stream(sound: StringName) -> AudioStreamWAV:
	if not _streams.has(sound):
		var parts := _recipe(sound)
		if parts.is_empty():
			return null
		_streams[sound] = Synth.render(parts)
	return _streams[sound]


static func play(sound: StringName, pitch: float = 1.0) -> void:
	load_settings()
	if muted:
		return
	var st := stream(sound)
	if st == null:
		return
	played_log.append(sound)
	if played_log.size() > 300:
		played_log = played_log.slice(150)
	var player := _free_player()
	if player == null:
		return
	player.stream = st
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


## 少し遅らせて鳴らす（照合のチャイムのあとに「ティン」を重ねる、など）
static func play_later(node: Node, sound: StringName, delay: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.get_tree().create_timer(delay).timeout.connect(func() -> void: play(sound))


static func set_muted(value: bool) -> void:
	muted = value
	if GameSession.persist:
		var cfg := ConfigFile.new()
		cfg.set_value("audio", "muted", muted)
		cfg.save(SETTINGS_PATH)


static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	if not GameSession.persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))


static func mute_button_text() -> String:
	return "音: OFF" if muted else "音: ON"


static func _free_player() -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if _host == null or not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "SfxPlayers"
		_players.clear()
		tree.root.add_child(_host)
	if _players.is_empty():
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			_host.add_child(p)
			_players.append(p)
	for p in _players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.playing:
			return p
	# 全部使用中なら、いちばん古いものを使い回す
	var first := _players[0]
	return first if is_instance_valid(first) and first.is_inside_tree() else null


## 音のレシピ。数値はあくまで初期値で、聞いて調整する。
static func _recipe(sound: StringName) -> Array:
	match sound:
		&"grab":    # 掴む: 軽い「ぴょこ」
			return [{"dur": 0.07, "f0": 700.0, "f1": 1100.0, "wave": "tri", "vol": 0.28, "curve": 1.2}]
		&"hover":   # 穴の上に乗った: ごく小さな「こつ」
			return [{"dur": 0.05, "f0": 1500.0, "wave": "sine", "vol": 0.14, "curve": 2.0}]
		&"match":   # 照合成功: 上がっていくチャイム
			return [
				{"t": 0.00, "dur": 0.16, "f0": 784.0, "wave": "sine", "vol": 0.32},
				{"t": 0.07, "dur": 0.18, "f0": 1047.0, "wave": "sine", "vol": 0.30},
				{"t": 0.14, "dur": 0.34, "f0": 1568.0, "wave": "sine", "vol": 0.28, "curve": 2.2},
				{"t": 0.14, "dur": 0.34, "f0": 3136.0, "wave": "sine", "vol": 0.06, "curve": 3.0},
			]
		&"fix":     # 訂正: 鉛筆でこする音＋短い上昇
			return [
				{"t": 0.00, "dur": 0.16, "wave": "noise", "vol": 0.22, "lp": 0.35, "curve": 0.8, "attack": 0.02},
				{"t": 0.14, "dur": 0.14, "f0": 880.0, "wave": "sine", "vol": 0.30},
				{"t": 0.22, "dur": 0.30, "f0": 1319.0, "wave": "sine", "vol": 0.28, "curve": 2.2},
			]
		&"stamp":   # ハンコ: 低い「どすっ」
			return [
				{"dur": 0.20, "f0": 120.0, "f1": 55.0, "wave": "sine", "vol": 0.5, "curve": 2.0, "attack": 0.002},
				{"dur": 0.06, "wave": "noise", "vol": 0.25, "lp": 0.3, "curve": 2.0, "attack": 0.001},
			]
		&"mismatch":   # 失敗: 低い「ぶっ」
			return [
				{"dur": 0.20, "f0": 170.0, "f1": 105.0, "wave": "square", "vol": 0.30, "curve": 1.4, "attack": 0.003},
				{"dur": 0.08, "wave": "noise", "vol": 0.12, "lp": 0.4, "curve": 1.5},
			]
		&"ting":    # 指示パネルが光る: やわらかい「ティン」
			return [
				{"dur": 0.45, "f0": 1319.0, "wave": "sine", "vol": 0.26, "curve": 2.6},
				{"dur": 0.45, "f0": 1976.0, "wave": "sine", "vol": 0.07, "curve": 3.0},
			]
		&"known":   # ノートが役に立った: 2音の「ティンティン」
			return [
				{"t": 0.00, "dur": 0.30, "f0": 988.0, "wave": "sine", "vol": 0.28, "curve": 2.2},
				{"t": 0.12, "dur": 0.42, "f0": 1319.0, "wave": "sine", "vol": 0.28, "curve": 2.4},
			]
		&"tick":    # ダイスのカラカラ
			return [{"dur": 0.03, "f0": 420.0, "wave": "square", "vol": 0.16, "curve": 1.5, "attack": 0.001}]
		&"success": # 判定成功: 明るい上昇アルペジオ
			return [
				{"t": 0.00, "dur": 0.14, "f0": 523.0, "wave": "tri", "vol": 0.30},
				{"t": 0.08, "dur": 0.14, "f0": 659.0, "wave": "tri", "vol": 0.30},
				{"t": 0.16, "dur": 0.14, "f0": 784.0, "wave": "tri", "vol": 0.30},
				{"t": 0.24, "dur": 0.40, "f0": 1047.0, "wave": "tri", "vol": 0.32, "curve": 2.0},
			]
		&"fail":    # 判定失敗: 下がっていく2音
			return [
				{"t": 0.00, "dur": 0.20, "f0": 392.0, "f1": 370.0, "wave": "tri", "vol": 0.30},
				{"t": 0.16, "dur": 0.38, "f0": 294.0, "f1": 262.0, "wave": "tri", "vol": 0.30, "curve": 2.0},
			]
		&"crit_fail":   # 大失敗: 重い「ごごっ」
			return [
				{"dur": 0.55, "f0": 90.0, "f1": 45.0, "wave": "sine", "vol": 0.45, "curve": 1.6},
				{"dur": 0.40, "wave": "noise", "vol": 0.28, "lp": 0.2, "curve": 1.5, "attack": 0.01},
			]
		&"warn":    # 残り時間わずか: 乾いた「コッ」
			return [{"dur": 0.04, "f0": 1000.0, "wave": "sine", "vol": 0.22, "curve": 2.0, "attack": 0.001}]
		&"type":    # 文字送り: ごく小さな「ぽ」
			return [{"dur": 0.015, "f0": 1500.0, "wave": "sine", "vol": 0.06, "curve": 1.0, "attack": 0.001}]
		&"click":   # ボタン
			return [{"dur": 0.05, "f0": 620.0, "wave": "tri", "vol": 0.22, "curve": 2.0, "attack": 0.001}]
		&"coin":    # 買い物: 硬貨の「チャリン」
			return [
				{"t": 0.00, "dur": 0.10, "f0": 1568.0, "wave": "sine", "vol": 0.24, "curve": 2.0, "attack": 0.001},
				{"t": 0.06, "dur": 0.32, "f0": 2093.0, "wave": "sine", "vol": 0.26, "curve": 2.4, "attack": 0.001},
				{"t": 0.06, "dur": 0.32, "f0": 4186.0, "wave": "sine", "vol": 0.05, "curve": 3.0, "attack": 0.001},
			]
		&"select":  # 出発・選択: 2音のチャイム
			return [
				{"t": 0.00, "dur": 0.20, "f0": 659.0, "wave": "sine", "vol": 0.30},
				{"t": 0.10, "dur": 0.40, "f0": 988.0, "wave": "sine", "vol": 0.30, "curve": 2.2},
			]
	return []
