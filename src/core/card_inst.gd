class_name CardInst
extends RefCounted
## One card (in the hand, or sitting on a map cell). `level` goes 1..3 by merging.

var id := ""
var level := 1


static func make(p_id: String, p_level: int = 1) -> CardInst:
	var c := CardInst.new()
	c.id = p_id
	c.level = p_level
	return c


func copy() -> CardInst:
	return CardInst.make(id, level)
