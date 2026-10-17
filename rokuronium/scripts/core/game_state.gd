class_name GameState
extends RefCounted
## ゲーム中に変化する状態をすべて持つ（セーブ対象）。UIには依存しない。

const SLOTS: Array[String] = ["朝", "昼", "夕方", "夜", "深夜"]
const STAT_NAMES: Array[String] = ["力", "体力", "敏捷", "知力", "魔力", "器用", "運"]
const AFFINITY_NAMES: Array[String] = ["知り合い", "友人", "信頼", "特別な存在", "恋人"]

var rng := RandomNumberGenerator.new()
var day := 1
var slot := "朝"
var location := ""
var money := 0
var total_exp := 0
var party_order: Array[String] = []
var party: Dictionary = {}       # id -> {name, level, hp, max_hp, mp, max_mp, stats, skills, equipment}
var inventory: Dictionary = {}   # item id -> 個数
var affinity: Dictionary = {}    # 出会ったヒロインのみ。id -> 0..100 の内部値
var flags: Dictionary = {}
var current_scene := ""


func _init() -> void:
	rng.randomize()


func new_game(db: GameDB) -> void:
	day = 1
	slot = "朝"
	location = ""
	current_scene = ""
	total_exp = 0
	flags = {}
	inventory = {}
	affinity = {}
	party = {}
	party_order = []
	var cfg: Dictionary = db.config
	money = Money.parse(cfg.get("start_money", 0))
	for id in cfg.get("party", []):
		var c: Dictionary = db.characters[id]
		party_order.append(id)
		party[id] = {
			"name": c["name"],
			"level": c.get("level", 1),
			"hp": c["hp"], "max_hp": c["hp"],
			"mp": c["mp"], "max_mp": c["mp"],
			"stats": (c.get("stats", {}) as Dictionary).duplicate(),
			"skills": (c.get("skills", {}) as Dictionary).duplicate(),
			"equipment": (c.get("equipment", {}) as Dictionary).duplicate(),
		}
		if c.get("heroine", false):
			affinity[id] = int(c.get("affinity", 0))
	for item_id in cfg.get("start_items", {}):
		inventory[item_id] = int(cfg["start_items"][item_id])


# ---------------------------------------------------------------- 親密度

## 内部値(0..100) → ♡の数(1..5)
@warning_ignore("integer_division")
static func hearts(value: int) -> int:
	return clampi(value / 20 + 1, 1, 5)


static func hearts_text(value: int) -> String:
	var h := hearts(value)
	return "♡%d %s" % [h, AFFINITY_NAMES[h - 1]]


# ---------------------------------------------------------------- 値の参照

func has_member(id: String) -> bool:
	return party.has(id)


func stat_of(who: String, stat: String) -> int:
	if not party.has(who):
		return 0
	return int(party[who]["stats"].get(stat, 0))


func skill_of(who: String, skill: String) -> int:
	if skill.is_empty() or not party.has(who):
		return 0
	return int(party[who]["skills"].get(skill, 0))


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


## 条件式から参照される値。未知の名前は null を返す（検証は DataValidator 側で行う）。
func resolve(path: String) -> Variant:
	match path:
		"money":
			return money
		"day":
			return day
		"slot":
			return slot
		"location":
			return location
		"exp":
			return total_exp
	var dot := path.find(".")
	if dot < 0:
		return null
	var ns := path.substr(0, dot)
	var key := path.substr(dot + 1)
	match ns:
		"flag":
			return flags.get(key, false)
		"affinity":
			return int(affinity.get(key, 0))
		"item":
			return item_count(key)
		"hp":
			return int(party[key]["hp"]) if party.has(key) else 0
		"mp":
			return int(party[key]["mp"]) if party.has(key) else 0
		"level":
			return int(party[key]["level"]) if party.has(key) else 0
	return null


# ---------------------------------------------------------------- 表示

## 状況欄:【冒険1日目・朝】【乗合馬車】【所持金 2金】【HP カズキ 30/30・アヤカ 20/20】
func status_line() -> String:
	var hp_parts: Array[String] = []
	for id in party_order:
		var m: Dictionary = party[id]
		hp_parts.append("%s %d/%d" % [m["name"], m["hp"], m["max_hp"]])
	return "【冒険%d日目・%s】【%s】【所持金 %s】【HP %s】" % [
		day, slot, location, Money.format(money), "・".join(hp_parts)]


# ---------------------------------------------------------------- 時間

func slot_index() -> int:
	return maxi(SLOTS.find(slot), 0)


## 指定の時間帯まで進める。すでにその時間帯以降なら翌日のその時間帯になる。
func advance_to_slot(target: String) -> void:
	var t := SLOTS.find(target)
	if t < 0:
		return
	if t <= slot_index():
		day += 1
	slot = target


func advance_steps(steps: int) -> void:
	var idx := slot_index() + steps
	@warning_ignore("integer_division")
	day += idx / SLOTS.size()
	slot = SLOTS[idx % SLOTS.size()]


# ---------------------------------------------------------------- セーブ用

func to_dict() -> Dictionary:
	return {
		"day": day, "slot": slot, "location": location, "money": money,
		"total_exp": total_exp, "party_order": party_order.duplicate(),
		"party": party.duplicate(true), "inventory": inventory.duplicate(),
		"affinity": affinity.duplicate(), "flags": flags.duplicate(true),
		"current_scene": current_scene,
	}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	slot = str(d.get("slot", "朝"))
	location = str(d.get("location", ""))
	money = int(d.get("money", 0))
	total_exp = int(d.get("total_exp", 0))
	party_order.clear()
	for id in d.get("party_order", []):
		party_order.append(str(id))
	party = (d.get("party", {}) as Dictionary).duplicate(true)
	inventory = (d.get("inventory", {}) as Dictionary).duplicate()
	affinity = (d.get("affinity", {}) as Dictionary).duplicate()
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	current_scene = str(d.get("current_scene", ""))
