class_name Money
extends RefCounted
## 通貨ユーティリティ。内部は銅貨単位の整数で持ち、表示だけ「1金4銀2銅」にする。
## 10銅 = 1銀、10銀 = 1金。

const COPPER_PER_SILVER := 10
const COPPER_PER_GOLD := 100


@warning_ignore("integer_division")
static func format(copper: int) -> String:
	if copper == 0:
		return "0銅"
	var v := absi(copper)
	var gold := v / COPPER_PER_GOLD
	var silver := (v % COPPER_PER_GOLD) / COPPER_PER_SILVER
	var cu := v % COPPER_PER_SILVER
	var s := "-" if copper < 0 else ""
	if gold > 0:
		s += "%d金" % gold
	if silver > 0:
		s += "%d銀" % silver
	if cu > 0:
		s += "%d銅" % cu
	return s


## 整数（銅貨）または「2金3銀」「30」のような文字列として解釈できるか。
static func is_valid(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) != TYPE_STRING:
		return false
	var s := (v as String).strip_edges()
	if s.is_empty():
		return false
	var rx := RegEx.new()
	rx.compile("^-?(\\d+(金|銀|銅)?)+$")
	return rx.search(s) != null


## 金額を銅貨に変換する。整数はそのまま、文字列は「2金3銀」形式（数字のみなら銅貨）。
static func parse(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	var s := String(v).strip_edges()
	var negative := s.begins_with("-")
	if negative:
		s = s.substr(1)
	var rx := RegEx.new()
	rx.compile("(\\d+)(金|銀|銅)?")
	var total := 0
	for m in rx.search_all(s):
		var n := int(m.get_string(1))
		match m.get_string(2):
			"金":
				total += n * COPPER_PER_GOLD
			"銀":
				total += n * COPPER_PER_SILVER
			_:
				total += n
	return -total if negative else total
