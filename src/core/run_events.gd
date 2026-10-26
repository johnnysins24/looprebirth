class_name RunEvents
extends RefCounted
## The five "?" events (docs/design/05-items-events.md). Values such as "20% of current HP"
## are worked out when the option is shown and again when it is chosen, so a notification
## that waited a while uses the HP of that moment.


## The two options of event notice `n`: [{label, detail, enabled, reason, cards}].
## `cards` > 0 means the player must pick that many hand cards first (the merchant).
static func options(run: RunState, n: Notice) -> Array[Dictionary]:
	var db := run.db
	var def: GameDb.EventDef = db.events[n.payload["event"]]
	var a := {"label": def.a_th, "detail": "", "enabled": true, "reason": "", "cards": 0}
	var b := {"label": def.b_th, "detail": "ไม่เกิดอะไรขึ้น", "enabled": true, "reason": "", "cards": 0}
	match def.id:
		"shrine":
			a["detail"] = "เสีย %d HP (%d%% ของ HP ตอนนี้) · ได้ของหายาก 1 ชิ้น" % [
				roundi(run.hp_cost(run.hero.hp, db.c("event_shrine_hp"))), roundi(db.c("event_shrine_hp") * 100.0)
			]
		"merchant":
			var need := db.ci("event_trade_cards")
			a["detail"] = "แลกการ์ดในมือ %d ใบ (เลือกเอง) · ได้ของระดับรอบ %d 1 ชิ้น" % [need, run.lap]
			a["cards"] = need
			if run.hand.size() < need:
				a["enabled"] = false
				a["reason"] = "ในมือมีการ์ดไม่พอ"
		"traveler":
			a["detail"] = "เสีย %d HP (%d%% ของ max HP) · ได้การ์ดบ้าน L2 1 ใบ" % [
				roundi(run.hp_cost(run.hero.max_hp, db.c("event_traveler_hp"))), roundi(db.c("event_traveler_hp") * 100.0)
			]
		"fountain":
			a["detail"] = "%d%%: แต้ม stat +%d · %d%%: เสีย %d HP" % [
				roundi(db.c("event_fountain_win") * 100.0),
				db.ci("event_fountain_points"),
				roundi((1.0 - db.c("event_fountain_win")) * 100.0),
				roundi(run.hp_cost(run.hero.hp, db.c("event_fountain_hp"))),
			]
		"deserter":
			a["detail"] = "สู้ elite โจร 1 ตัว · ชนะได้ skill card 1 จาก 3 · แพ้คือจบ run"
			if run.phase != RunState.Phase.WALKING:
				a["enabled"] = false
				a["reason"] = "กำลังสู้อยู่ รอให้จบก่อน"
	return [a, b]


static func resolve(run: RunState, n: Notice, option: int, extra: Dictionary) -> bool:
	var db := run.db
	var opts := options(run, n)
	if option < 0 or option > 1 or not opts[option]["enabled"]:
		return false
	var id: String = n.payload["event"]
	if option == 1:
		run.toast.emit("%s: เดินผ่าน" % db.events[id].name_th)
		return true
	match id:
		"shrine":
			run.lose_hp(run.hp_cost(run.hero.hp, db.c("event_shrine_hp")))
			run.offer_item(run.new_item(Item.Rarity.RARE))
		"merchant":
			var picked: Array = extra.get("cards", [])
			var need := db.ci("event_trade_cards")
			if picked.size() != need:
				return false
			var seen := {}
			for i: int in picked:
				if i < 0 or i >= run.hand.size() or seen.has(i):
					return false
				seen[i] = true
			picked.sort()
			picked.reverse()
			for i: int in picked:
				run.hand.remove_at(i)
			run.hand_changed.emit()
			run.offer_item(run.new_item())
		"traveler":
			run.lose_hp(run.hp_cost(run.hero.max_hp, db.c("event_traveler_hp")))
			run.give_card(CardInst.make("house", 2))
		"fountain":
			if run.event_random() < db.c("event_fountain_win"):
				run.grant_stat_points(db.ci("event_fountain_points"), "น้ำพุลึกลับ")
				run.toast.emit("น้ำพุให้พลัง! แต้ม stat +%d" % db.ci("event_fountain_points"))
			else:
				var cost := run.hp_cost(run.hero.hp, db.c("event_fountain_hp"))
				run.lose_hp(cost)
				run.toast.emit("น้ำพุเป็นพิษ เสีย %d HP" % roundi(cost))
		"deserter":
			return run.start_duel()
	return true
