class_name CardView
extends RefCounted
## Draws a card (32x44, docs/dev/art-contract.md) anywhere on a CanvasItem.

const W := 32
const H := 44
const PLATE := Rect2(4, 31, 24, 9)  ## empty name plate on the finished card faces (manifest.json cards.name_plate)
const PLATE_TEXT := Color("3e2731")


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


## Draws a hand card of either kind (a map card or a skill card).
static func draw_inst(ci: CanvasItem, pos: Vector2, db: GameDb, card: CardInst, selected: bool = false, dim: bool = false) -> void:
	if card.skill:
		draw_skill(ci, pos, db, card.id, card.level, selected, dim)
	else:
		draw_card(ci, pos, db, card.id, card.level, selected, dim)


## A skill card: the same 32x44 face, picture from cards/skill_<id>.png (placeholder: icon on a panel).
static func draw_skill(ci: CanvasItem, pos: Vector2, db: GameDb, skill_id: String, level: int, selected: bool = false, dim: bool = false) -> void:
	var def: GameDb.SkillDef = db.skills[skill_id]
	var tint := Color(1, 1, 1, 0.45) if dim else Color.WHITE
	var face := "skill_" + skill_id
	if Art.has_real("cards", face):
		Art.draw_frame(ci, "cards", face, pos, W, H, level - 1, 0, tint)
		if selected:
			ci.draw_rect(Rect2(pos, Vector2(W, H)), UiTheme.GOLD, false, 1.0)
		_plate_name(ci, pos, def.name_th, tint)
		return
	var r := Rect2(pos, Vector2(W, H))
	ci.draw_rect(r, UiTheme.PANEL_LIGHT * tint)
	ci.draw_rect(Rect2(pos, Vector2(W, 3)), Art.color("purple") * tint)
	ci.draw_rect(r, UiTheme.GOLD if selected else UiTheme.BORDER, false, 1.0)
	ci.draw_texture(Art.icon("skill_" + skill_id), pos + Vector2(8, 8), tint)
	for k in level:
		ci.draw_rect(Rect2(pos + Vector2(3 + k * 4, 6), Vector2(3, 3)), UiTheme.GOLD)
	var w := UiTheme.text_width(def.name_th, UiTheme.FS_SMALL)
	UiTheme.text(ci, pos.x + (W - w) / 2.0, pos.y + 29, def.name_th, UiTheme.FS_SMALL, UiTheme.TEXT * tint)
	var lv := "L%d" % level
	var lw := UiTheme.text_width(lv, UiTheme.FS_SMALL, true)
	UiTheme.text(ci, pos.x + (W - lw) / 2.0, pos.y + 36, lv, UiTheme.FS_SMALL, UiTheme.GOLD * tint, true)


## Thai name on the empty plate of a finished card face, shrunk to fit.
static func _plate_name(ci: CanvasItem, pos: Vector2, name: String, tint: Color) -> void:
	var bw := UiTheme.text_width(name, UiTheme.FS_SMALL, true)
	var scale := minf(1.0, (PLATE.size.x - 2.0) / maxf(bw, 1.0))
	var fs := maxi(4, int(UiTheme.FS_SMALL * scale))
	var tw := UiTheme.text_width(name, fs, true)
	UiTheme.text(ci, pos.x + PLATE.position.x + (PLATE.size.x - tw) / 2.0, pos.y + PLATE.position.y + 0.5, name, fs, PLATE_TEXT * tint, true)


static func draw_card(ci: CanvasItem, pos: Vector2, db: GameDb, card_id: String, level: int, selected: bool = false, dim: bool = false) -> void:
	var def: GameDb.CardDef = db.cards[card_id]
	var tint := Color(1, 1, 1, 0.45) if dim else Color.WHITE
	var name := def.name_th
	var w := UiTheme.text_width(name, UiTheme.FS_SMALL)
	if Art.has_real("cards", card_id):
		# finished face (frame, picture, level badge, type icon) with an empty name plate
		Art.draw_frame(ci, "cards", card_id, pos, W, H, level - 1, 0, tint)
		if selected:
			ci.draw_rect(Rect2(pos, Vector2(W, H)), UiTheme.GOLD, false, 1.0)
		_plate_name(ci, pos, name, tint)
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
