class_name CardView
extends RefCounted
## Draws a card (32x44, docs/dev/art-contract.md) anywhere on a CanvasItem.

const W := 32
const H := 44


static func type_color(type: String) -> Color:
	match type:
		"terrain":
			return Art.color("green")
		"encounter":
			return Art.color("crimson")
		"building":
			return Art.color("gold")
		"special":
			return Art.color("purple")
	return Art.color("slate")


static func draw_card(ci: CanvasItem, pos: Vector2, db: GameDb, card_id: String, level: int, selected: bool = false, dim: bool = false) -> void:
	var def: GameDb.CardDef = db.cards[card_id]
	var tint := Color(1, 1, 1, 0.45) if dim else Color.WHITE
	var name := def.name_th
	var w := UiTheme.text_width(name, UiTheme.FS_SMALL)
	if Art.has_real("cards", card_id):
		# finished face (frame, picture, level badge, type icon) with an empty name plate at (4, 34, 24, 6)
		Art.draw_frame(ci, "cards", card_id, pos, W, H, level - 1, 0, tint)
		if selected:
			ci.draw_rect(Rect2(pos, Vector2(W, H)), UiTheme.GOLD, false, 1.0)
		var scale := minf(1.0, 22.0 / maxf(w, 1.0))  # long Thai names shrink to fit inside the plate
		UiTheme.text(ci, pos.x + 4 + (24.0 - w * scale) / 2.0, pos.y + 33, name, maxi(4, int(UiTheme.FS_SMALL * scale)), Color("3e2731") * tint)
		return
	var r := Rect2(pos, Vector2(W, H))
	ci.draw_rect(r, UiTheme.PANEL_LIGHT * tint)
	var tc := type_color(def.type)
	ci.draw_rect(Rect2(pos, Vector2(W, 3)), tc * tint)
	ci.draw_rect(r, UiTheme.GOLD if selected else UiTheme.BORDER, false, 1.0)
	Art.draw_frame(ci, "map", card_id, pos + Vector2(8, 3), 16, 24, level - 1, 0, tint)
	if level > 1:
		for k in level:
			ci.draw_rect(Rect2(pos + Vector2(3 + k * 4, 6), Vector2(3, 3)), UiTheme.GOLD)
	UiTheme.text(ci, pos.x + (W - w) / 2.0, pos.y + 29, name, UiTheme.FS_SMALL, UiTheme.TEXT * tint)
	var lv := "L%d" % level
	var lw := UiTheme.text_width(lv, UiTheme.FS_SMALL, true)
	UiTheme.text(ci, pos.x + (W - lw) / 2.0, pos.y + 36, lv, UiTheme.FS_SMALL, (UiTheme.GOLD if level > 1 else UiTheme.TEXT_DIM) * tint, true)
