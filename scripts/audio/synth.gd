class_name Synth
extends RefCounted
## 効果音を、音声ファイルなしでコードから合成する小さなシンセサイザ。
## 1つの音は「パーツ」の並びで、各パーツは周波数・波形・長さ・音量などを持つ。

const RATE := 22050


## parts の各要素（Dictionary）:
##   t: 開始秒 / dur: 長さ秒 / f0, f1: 開始・終了周波数（Hz）/ wave: sine, tri, square, noise
##   vol: 音量(0-1) / attack: 立ち上がり秒 / curve: 減衰の強さ / lp: noise の高域カット（0-1、小さいほど低い音）
static func render(parts: Array) -> AudioStreamWAV:
	var total := 0.0
	for p: Dictionary in parts:
		total = maxf(total, float(p.get("t", 0.0)) + float(p["dur"]))
	var n := int(ceil(total * RATE)) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	for p: Dictionary in parts:
		var start := int(float(p.get("t", 0.0)) * RATE)
		var count := int(float(p["dur"]) * RATE)
		var f0: float = p.get("f0", 440.0)
		var f1: float = p.get("f1", f0)
		var wave: String = p.get("wave", "sine")
		var vol: float = p.get("vol", 0.3)
		var attack_samples := maxf(1.0, float(p.get("attack", 0.004)) * RATE)
		var curve: float = p.get("curve", 1.5)
		var lp: float = p.get("lp", 1.0)
		var phase := 0.0
		var low := 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345 + start
		for i in count:
			var idx := start + i
			if idx >= n:
				break
			var u := float(i) / float(maxi(1, count - 1))
			phase += lerpf(f0, f1, u) / RATE
			var s := 0.0
			match wave:
				"sine":
					s = sin(TAU * phase)
				"tri":
					s = 4.0 * absf(fposmod(phase, 1.0) - 0.5) - 1.0
				"square":
					s = 0.6 if fposmod(phase, 1.0) < 0.5 else -0.6
				"noise":
					low = lerpf(low, rng.randf_range(-1.0, 1.0), lp)
					s = low
			# 立ち上がりと減衰（最後は必ず0に落ちるので、プチッというノイズが出にくい）
			var env := minf(1.0, float(i) / attack_samples) * pow(1.0 - u, curve)
			buf[idx] += s * vol * env
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## 合成した音の最大振幅（0-1）
static func peak(stream: AudioStreamWAV) -> float:
	var m := 0.0
	for i in stream.data.size() / 2:
		m = maxf(m, absf(float(stream.data.decode_s16(i * 2)) / 32768.0))
	return m


static func length_sec(stream: AudioStreamWAV) -> float:
	return float(stream.data.size() / 2) / float(stream.mix_rate)
