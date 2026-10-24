class_name Gesture
extends RefCounted
## 御沙汰の刻に記録した扇の開閉から、所作（gesture）と、その特徴を読み取る。UI に依存しない。
## 刻の始まりの扇は、いつも閉じている。toggle_times は刻の始まりからの秒数（開・閉・開…の順）。

const STILL := "still"
const OPEN_HOLD := "open_hold"
const SNAP := "snap"
const FLUTTER := "flutter"


static func read(toggle_times: Array, window_sec: float, cfg: Dictionary) -> Dictionary:
	var times: Array[float] = []
	for t in toggle_times:
		times.append(clampf(float(t), 0.0, window_sec))
	var n := times.size()
	var hesitate_sec := float(cfg.get("hesitate_sec", 2.0))
	var quick_snap_sec := float(cfg.get("quick_snap_sec", 0.5))
	var long_hold_sec := float(cfg.get("long_hold_sec", 4.5))
	var flutter_min := int(cfg.get("flutter_min_toggles", 4))

	var ended_open := n % 2 == 1
	var first_move: float = times[0] if n > 0 else window_sec
	# 開いてから閉じるまで（最初のひと組）
	var snap_open: float = times[1] - times[0] if n >= 2 else 0.0
	# 最後に開いてから、刻の終わりまで
	var final_open: float = window_sec - times[n - 1] if ended_open else 0.0

	var gesture := STILL
	if n == 0:
		gesture = STILL
	elif n >= flutter_min:
		gesture = FLUTTER
	elif ended_open:
		gesture = OPEN_HOLD
	else:
		gesture = SNAP

	return {
		"gesture": gesture,
		"toggles": n,
		"times": times,
		"first_move_sec": first_move,
		"hesitated": n > 0 and first_move >= hesitate_sec,
		"snap_open_sec": snap_open,
		"quick": gesture == SNAP and snap_open <= quick_snap_sec,
		"final_open_sec": final_open,
		"long_hold": gesture == OPEN_HOLD and final_open >= long_hold_sec,
		"ended_open": ended_open,
	}
