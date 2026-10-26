class_name LogView
extends Control
## Full fight log (key L): the explanation lines, then the latest events of the current or
## the last fight. For checking exactly why a fight went the way it did.

const MAX_LINES := 15

var run: RunState
var game: Game


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game


func _process(_d: float) -> void:
	visible = run != null and game.show_log
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var b: Battle = run.battle if run.battle != null else run.last_battle
	var r := Rect2(10, 8, size.x - 20, size.y - 16)
	draw_rect(r, Color(UiTheme.BG, 0.94))
	draw_rect(r, UiTheme.GOLD, false, 1.0)
	UiTheme.text(self, r.position.x + 6, r.position.y + 4, "บันทึกการต่อสู้ (L ปิด)", UiTheme.FS, UiTheme.GOLD, true)
	if b == null:
		UiTheme.text(self, r.position.x + 6, r.position.y + 20, "ยังไม่มีการต่อสู้", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		return
	var y := r.position.y + 17.0
	var lines := b.explain()
	for line in lines:
		y += UiTheme.paragraph(self, r.position.x + 6, y, r.size.x - 12, line, UiTheme.FS_SMALL, UiTheme.TEXT, 7.5)
	y += 3.0
	draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), UiTheme.BORDER)
	y += 3.0
	var shown := 0
	var i := b.history.size() - 1
	var out: Array[Dictionary] = []
	while i >= 0 and out.size() < MAX_LINES and y + (out.size() + 1) * 7.5 < r.end.y - 4:
		var e: Dictionary = b.history[i]
		var s := BattleText.describe(e, b)
		if s != "":
			out.append({"t": "%5.1fs  %s" % [e["t"], s], "c": BattleText.color(e)})
		i -= 1
	for k in out.size():
		var line: Dictionary = out[out.size() - 1 - k]
		UiTheme.text(self, r.position.x + 6, y + shown * 7.5, line["t"], UiTheme.FS_SMALL, line["c"])
		shown += 1
