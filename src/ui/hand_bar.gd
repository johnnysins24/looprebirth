class_name HandBar
extends Control
## The hand along the bottom (docs/design/07-ux.md): card slots on the left, a context box
## on the right that says what the hovered card or cell does.

const SLOT_W := 34
const INFO_X := 346.0

var run: RunState
var game: Game

var hover_slot := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game


func slot_rect(i: int) -> Rect2:
	return Rect2(3 + i * SLOT_W, 1, CardView.W, CardView.H)


## Hand index under a point in this control's own coordinates, or -1.
func slot_at(p: Vector2) -> int:
	for i in run.hand.size():
		if slot_rect(i).has_point(p):
			return i
	return -1


func _process(_d: float) -> void:
	hover_slot = slot_at(get_local_mouse_position()) if run != null else -1
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.PANEL)
	draw_line(Vector2(0, 0.5), Vector2(size.x, 0.5), UiTheme.BORDER)
	for i in run.hand.size():
		var card := run.hand[i]
		var r := slot_rect(i)
		var lift := -3.0 if (i == game.held or i == hover_slot) else 0.0
		CardView.draw_card(self, r.position + Vector2(0, lift), run.db, card.id, card.level, i == game.held)
	# empty slots hint the hand limit
	for i in range(run.hand.size(), run.hand_limit()):
		draw_rect(slot_rect(i), Color(1, 1, 1, 0.06), false, 1.0)
	var count := "%d/%d" % [run.hand.size(), run.hand_limit()]
	# context box
	var box := Rect2(INFO_X, 3, size.x - INFO_X - 3.0, size.y - 6.0)
	UiTheme.box(self, box, Color("181425"), UiTheme.BORDER)
	var y := box.position.y + 2.0
	for line in game.info_lines():
		y += UiTheme.paragraph(self, box.position.x + 3, y, box.size.x - 6, line["t"], UiTheme.FS_SMALL, line["c"], 7.5)
		if y > box.end.y - 6.0:
			break
	UiTheme.text(self, box.end.x - UiTheme.text_width(count, UiTheme.FS_SMALL) - 3, box.end.y - 8, count, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
