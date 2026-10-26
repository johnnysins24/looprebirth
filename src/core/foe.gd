class_name Foe
extends RefCounted
## One enemy in a fight, already scaled to the lap it was created in.

var def: GameDb.EnemyDef
var max_hp := 1.0
var hp := 1.0
var atk := 0.0
var aps := 1.0
var df := 0.0
var evasion := 0.0
var slam_chance := 0.0
var elite := false
var xp := 0  ## XP the hero gets for the kill
var drop_chance := 0.0
var alive := true
var timer := 0.0  ## time since the last attack


func display_name() -> String:
	return ("★" if elite else "") + def.name_th


## Builds a foe for `lap` (docs/design/04-hero-combat.md "การโตตามรอบ").
## `xp_mult` carries encounter-level and combo multipliers. `rng` only offsets the first
## attack so a group does not strike in unison.
static func make(
	db: GameDb,
	p_def: GameDb.EnemyDef,
	lap: int,
	is_elite: bool,
	xp_mult: float,
	rng: RandomNumberGenerator,
	hp_mult: float = 1.0
) -> Foe:
	var f := Foe.new()
	f.def = p_def
	var grow := 1.0
	var grow_atk := 1.0
	var grow_def := 1.0
	var grow_xp := 1.0
	if p_def.scales:
		grow = 1.0 + db.c("scale_hp") * (lap - 1)
		grow_atk = 1.0 + db.c("scale_atk") * (lap - 1)
		grow_def = 1.0 + db.c("scale_def") * (lap - 1)
		grow_xp = 1.0 + db.c("scale_xp") * (lap - 1)
	f.max_hp = p_def.hp * grow * hp_mult
	f.atk = p_def.atk * grow_atk
	f.df = p_def.df * grow_def
	f.aps = p_def.aps
	f.evasion = p_def.evasion
	f.slam_chance = p_def.slam_chance
	f.drop_chance = p_def.item_drop
	var xp_f := p_def.xp * grow_xp * xp_mult
	if is_elite:
		f.elite = true
		f.max_hp *= db.c("elite_hp")
		f.atk *= db.c("elite_atk")
		xp_f *= db.c("elite_xp")
		f.drop_chance = 1.0
	f.hp = f.max_hp
	f.xp = 0 if p_def.xp <= 0.0 else maxi(1, roundi(xp_f))
	f.timer = rng.randf() / f.aps
	return f
