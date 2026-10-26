class_name Item
extends RefCounted
## One piece of gear (docs/design/05-items-events.md): a slot, a rarity, a level and the
## stats it gives. Stats use the same keys as Hero.mods.

enum Rarity { COMMON, RARE, EPIC }

const SLOTS := ["weapon", "armor", "trinket"]
const SLOT_NAMES := {"weapon": "อาวุธ", "armor": "เกราะ", "trinket": "เครื่องประดับ"}
const RARITY_NAMES := ["ธรรมดา", "หายาก", "มหากาพย์"]
const STAT_NAMES := {
	"atk": "ATK",
	"max_hp": "max HP",
	"ap": "AP",
	"crit": "คริ",
	"luck": "luck",
	"attack_speed": "ตีเร็ว",
	"evasion": "หลบ",
	"crit_damage": "คริดาเมจ",
	"max_mana": "max mana",
}
const SHORT_NAMES := {"atk": "ATK", "max_hp": "HP", "ap": "AP", "crit": "คริ", "luck": "luck"}  ## main stats, for the gear slots
const PERCENT := ["crit", "attack_speed", "evasion", "crit_damage"]

var slot := "weapon"
var rarity := Rarity.COMMON
var level := 1
var name := ""
var icon := "item_weapon"  ## icons/<icon>.png
var main := ""  ## the main stat's key
var stats: Dictionary = {}  ## stat -> value, main stat included


## Rolls an item for `level`. `luck` and `rare_bonus` (smithy) shift the odds towards rare;
## `min_rarity` forces at least that rarity (old shrine) and `max_rarity` at most that rarity
## (the hero's starting gear); `slot` "" picks a random slot.
static func roll(
	db: GameDb,
	rng: RandomNumberGenerator,
	level: int,
	luck: float = 0.0,
	rare_bonus: float = 0.0,
	slot: String = "",
	min_rarity: int = Rarity.COMMON,
	max_rarity: int = Rarity.EPIC
) -> Item:
	var it := Item.new()
	it.level = level
	it.slot = slot if slot != "" else SLOTS[rng.randi() % SLOTS.size()]
	it.rarity = clampi(roll_rarity(db, rng, luck, rare_bonus), min_rarity, max_rarity)
	var mult := 1.0
	if it.rarity == Rarity.RARE:
		mult = db.c("item_rare_mult")
	elif it.rarity == Rarity.EPIC:
		mult = db.c("item_epic_mult")
	match it.slot:
		"weapon":
			it.main = "atk"
			it.icon = "item_weapon"
			it.name = ["ดาบ", "ขวาน", "กระบี่"][rng.randi() % 3]
			it.stats["atk"] = roundf((db.c("gear_watk_base") + db.c("gear_watk_per_lap") * level) * mult)
		"armor":
			it.main = "max_hp"
			it.icon = "item_armor"
			it.name = ["เสื้อหนัง", "เกราะ", "เกราะเกล็ด"][rng.randi() % 3]
			it.stats["max_hp"] = roundf((db.c("gear_hp_base") + db.c("gear_hp_per_lap") * level) * mult)
		_:
			var kind := rng.randi() % 3
			if kind == 0:
				it.main = "ap"
				it.icon = "item_amulet"
				it.name = "สร้อยมนตร์"
				it.stats["ap"] = roundf((db.c("gear_ap_base") + db.c("gear_ap_per_lap") * level) * mult)
			elif kind == 1:
				it.main = "crit"
				it.icon = "item_ring"
				it.name = "แหวนคม"
				it.stats["crit"] = roundf(db.c("gear_crit") * mult * 1000.0) / 1000.0
			else:
				it.main = "luck"
				it.icon = "item_charm"
				it.name = "เครื่องรางนำโชค"
				it.stats["luck"] = roundf(db.c("gear_luck") * mult)
	var extra: int = it.rarity  # secondary stats: 0, 1 or 2
	var pool: Array[GameDb.ItemStatDef] = []
	for d in db.item_stats:
		if d.stat != it.main:
			pool.append(d)
	for k in extra:
		var d: GameDb.ItemStatDef = pool.pop_at(rng.randi() % pool.size())
		var v := d.lo + (d.hi - d.lo) * rng.randf() + d.per_level * level
		if PERCENT.has(d.stat):
			v = roundf(v * 100.0) / 100.0
		else:
			v = roundf(v)
		it.stats[d.stat] = v
	return it


## common / rare / epic. 1 luck moves 1% of the odds from common to rare and 0.2% to epic.
static func roll_rarity(db: GameDb, rng: RandomNumberGenerator, luck: float, rare_bonus: float) -> int:
	var epic := clampf(db.c("item_epic_chance") + db.c("item_luck_epic") * luck, 0.0, 1.0)
	var rare := clampf(db.c("item_rare_chance") + db.c("item_luck_rare") * luck + rare_bonus, 0.0, 1.0 - epic)
	var r := rng.randf()
	if r < epic:
		return Rarity.EPIC
	if r < epic + rare:
		return Rarity.RARE
	return Rarity.COMMON


## Is this better than `other` (the item in the same slot, or null)? Higher rarity wins, then level.
func better_than(other: Item) -> bool:
	if other == null:
		return true
	if rarity != other.rarity:
		return rarity > other.rarity
	return level > other.level


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func title() -> String:
	return "%s Lv%d" % [name, level]


static func stat_text(stat: String, value: float) -> String:
	var label: String = STAT_NAMES.get(stat, stat)
	if PERCENT.has(stat):
		return "%s +%d%%" % [label, roundi(value * 100.0)]
	return "%s +%d" % [label, roundi(value)]


## Short form of the main stat ("ATK 13", "คริ 7%") for the small gear slots on the side panel.
func short_text() -> String:
	var v: float = stats[main]
	var label: String = SHORT_NAMES.get(main, main)
	return ("%s %d%%" % [label, roundi(v * 100.0)]) if PERCENT.has(main) else ("%s %d" % [label, roundi(v)])


## One line per stat, main stat first.
func lines() -> Array[String]:
	var out: Array[String] = [stat_text(main, stats[main])]
	for k in stats:
		if k != main:
			out.append(stat_text(k, stats[k]))
	return out
