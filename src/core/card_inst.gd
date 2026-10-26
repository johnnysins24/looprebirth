class_name CardInst
extends RefCounted
## One card (in the hand, or sitting on a map cell). `level` goes 1..3 by merging.
## A skill card (`skill` true) has a skill id and is dropped on a hero skill slot, not on the map.

var id := ""
var level := 1
var skill := false
var progress := 0  ## L1 cards already absorbed towards the next level; only used at L2 (see CardRules.merge_step)


static func make(p_id: String, p_level: int = 1) -> CardInst:
	var c := CardInst.new()
	c.id = p_id
	c.level = p_level
	return c


static func make_skill(p_id: String, p_level: int = 1) -> CardInst:
	var c := make(p_id, p_level)
	c.skill = true
	return c


func copy() -> CardInst:
	var c := CardInst.make(id, level)
	c.skill = skill
	c.progress = progress
	return c
