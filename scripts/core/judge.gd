class_name Judge
extends RefCounted
## 指示の正しさから目標値補正を決め、ダイス判定を行う純粋関数群。


static func modifier(matched: bool, chosen: StringName, required: StringName) -> int:
	if chosen == &"":
		return Rules.MOD_NO_INSTRUCTION
	var stat_ok := chosen == required
	if matched:
		return Rules.MOD_MATCHED_CORRECT_STAT if stat_ok else Rules.MOD_MATCHED_WRONG_STAT
	return Rules.MOD_UNMATCHED_CORRECT_STAT if stat_ok else Rules.MOD_UNMATCHED_WRONG_STAT


static func resolve(base_target: int, mod: int, stat_value: int, roll: int) -> Dictionary:
	var target := base_target + mod
	var total := roll + stat_value
	var crit_fail := roll == 1
	var success := not crit_fail and (roll == Rules.DICE_SIDES or total >= target)
	return {
		"target": target,
		"roll": roll,
		"total": total,
		"success": success,
		"crit_fail": crit_fail,
	}
