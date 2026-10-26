class_name Meta
extends RefCounted
## What survives from run to run (docs/design/06-meta.md): Rebirth points and the ranks bought
## with them in the Rebirth tree. Saved as JSON; an empty path keeps everything in memory.

signal changed

const VERSION := 1

var db: GameDb
var path := ""
var rp := 0
var ranks: Dictionary = {}  # node id -> rank bought
var runs := 0
var wins := 0
var best_lap := 0
var last_seed := 0


func _init(p_db: GameDb, p_path: String = "") -> void:
	db = p_db
	path = p_path
	if path != "":
		load_file()


func rank(id: String) -> int:
	return int(ranks.get(id, 0))


## Cards and skills the tree has unlocked, as ids (feeds GameDb.unlocked_card_ids/skill ids).
func unlocked_flags() -> Array:
	var out := []
	for id in db.node_order:
		var n: GameDb.NodeDef = db.nodes[id]
		if n.unlock_id() != "" and rank(id) >= 1:
			out.append(n.unlock_id())
	return out


## {ok, reason, cost} for buying the next rank of `id`.
func check_buy(id: String) -> Dictionary:
	var n: GameDb.NodeDef = db.nodes.get(id)
	if n == null:
		return {"ok": false, "reason": "ไม่มี node นี้", "cost": 0}
	var have := rank(id)
	if have >= n.ranks:
		return {"ok": false, "reason": "ซื้อครบแล้ว", "cost": 0}
	var cost := n.cost_of(have + 1)
	if n.requires != "" and rank(n.requires) < n.requires_rank:
		var req: GameDb.NodeDef = db.nodes[n.requires]
		return {"ok": false, "reason": "ต้องมี %s ขั้น %d ก่อน" % [req.name_th, n.requires_rank], "cost": cost}
	if rp < cost:
		return {"ok": false, "reason": "RP ไม่พอ (ต้องการ %d)" % cost, "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


func buy(id: String) -> bool:
	var res := check_buy(id)
	if not res["ok"]:
		return false
	rp -= int(res["cost"])
	ranks[id] = rank(id) + 1
	save()
	changed.emit()
	return true


func add_rp(amount: int) -> void:
	if amount == 0:
		return
	rp += amount
	save()
	changed.emit()


## Called once when a run is over.
func record_run(won: bool, lap: int, seed_value: int) -> void:
	runs += 1
	if won:
		wins += 1
	best_lap = maxi(best_lap, lap)
	last_seed = seed_value
	save()
	changed.emit()


## RP needed for the whole tree and how much of it is already bought.
func tree_cost() -> Array[int]:
	var total := 0
	var spent := 0
	for id in db.node_order:
		var n: GameDb.NodeDef = db.nodes[id]
		for r in range(1, n.ranks + 1):
			total += n.cost_of(r)
			if r <= rank(id):
				spent += n.cost_of(r)
	return [spent, total]


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"rp": rp,
		"ranks": ranks,
		"runs": runs,
		"wins": wins,
		"best_lap": best_lap,
		"last_seed": last_seed,
	}


func save() -> void:
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("cannot save %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))


func load_file() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("%s is not a valid profile; starting fresh" % path)
		return
	var d: Dictionary = parsed
	rp = int(d.get("rp", 0))
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_lap = int(d.get("best_lap", 0))
	last_seed = int(d.get("last_seed", 0))
	ranks.clear()
	var saved: Dictionary = d.get("ranks", {})
	for id in saved:
		if db.nodes.has(id):  # a node removed from the tree is dropped, its RP is not refunded
			ranks[id] = clampi(int(saved[id]), 0, db.nodes[id].ranks)
