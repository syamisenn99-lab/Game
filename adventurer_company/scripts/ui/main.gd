extends Control
## メイン画面。GameController を1つ持ち、各パネルとダイアログをつなぐ。
## 起動時に `-- --seed 123` を付けると、その乱数シードで遊べる（再現用）。

@onready var top_bar: PanelContainer = $TopBar
@onready var board: Control = $Board
@onready var detail: PanelContainer = $Detail
@onready var roster: PanelContainer = $Roster
@onready var dispatch_panel: Control = $DispatchPanel
@onready var report_dialog: Control = $ReportDialog
@onready var injury_dialog: Control = $InjuryDialog
@onready var message_dialog: Control = $MessageDialog
@onready var result_screen: Control = $ResultScreen

var controller: GameController
var selected_quest_id: String = ""


func _ready() -> void:
	var data := GameData.load_from()
	if not data.is_valid():
		var error := UiKit.label("data/*.json を読み込めなかった:\n" + "\n".join(data.errors), 18, Color.WHITE, true)
		error.position = Vector2(40, 80)
		error.size = Vector2(1200, 600)
		add_child(error)
		top_bar.visible = false
		return
	var seed_value := _seed_from_args()
	print("乱数シード: ", seed_value)
	controller = GameController.new(data, seed_value)
	top_bar.setup(controller)
	board.setup(controller)
	detail.setup(controller)
	roster.setup(controller)
	dispatch_panel.setup(controller)
	injury_dialog.setup(controller)

	controller.changed.connect(refresh)
	top_bar.end_week_pressed.connect(_on_end_week)
	board.quest_selected.connect(_on_quest_selected)
	detail.dispatch_requested.connect(func(id: String) -> void: dispatch_panel.open(id))
	result_screen.restart_requested.connect(_on_restart)
	refresh()


func refresh() -> void:
	top_bar.refresh()
	board.refresh(selected_quest_id)
	detail.refresh()
	roster.refresh()


func _seed_from_args() -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seed")
	if i >= 0 and i + 1 < args.size():
		return int(args[i + 1])
	return randi()


func _on_quest_selected(id: String) -> void:
	selected_quest_id = id
	detail.show_quest(id)
	board.refresh(selected_quest_id)


func _on_end_week() -> void:
	if controller.phase != GameController.Phase.PLANNING:
		return
	var report := controller.end_week()
	report_dialog.open(controller, report)
	await report_dialog.closed
	for case: InjuryCase in controller.pending_injuries():
		injury_dialog.open(case)
		await injury_dialog.closed
	controller.finish_week()
	if controller.is_over():
		result_screen.open(controller)
		return
	var lines: Array[String] = []
	if report.payday:
		lines.append("給料日：月給 %dG を支払った。（残り %dG）" % [report.payroll, controller.gold])
	if not report.new_quests.is_empty():
		lines.append("新しい依頼：" + "、".join(report.new_quests))
	if not report.expired_quests.is_empty():
		lines.append("掲示が終わった依頼：" + "、".join(report.expired_quests))
	if not lines.is_empty():
		message_dialog.open("第%d週（%d月目）がはじまった" % [controller.week, controller.month()], "\n".join(lines))
		await message_dialog.closed


func _on_restart() -> void:
	selected_quest_id = ""
	controller.new_game(randi())
