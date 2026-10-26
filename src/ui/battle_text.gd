class_name BattleText
extends RefCounted
## Turns Battle events into the short Thai lines shown in the fight overlay and the log.


static func describe(e: Dictionary, battle: Battle) -> String:
	var db := battle.db
	var foe_name := ""
	if e.has("foe") and int(e["foe"]) >= 0 and int(e["foe"]) < battle.foes.size():
		foe_name = battle.foes[int(e["foe"])].display_name()
	match e["k"]:
		"hit":
			var via: String = e.get("via", "")
			var dmg := "%d" % roundi(e["dmg"])
			if via != "":
				return "%s ใส่ %s %s" % [(db.skills[via] as GameDb.SkillDef).name_th, foe_name, dmg]
			return "ฮีโร่ตี %s %s%s" % [foe_name, dmg, " คริติคอล!" if e.get("crit", false) else ""]
		"miss":
			return "ฮีโร่ตี %s พลาด" % foe_name
		"cast":
			return "ใช้ %s L%d" % [(db.skills[e["skill"]] as GameDb.SkillDef).name_th, e["level"]]
		"heal":
			return "ฟื้น HP %d" % roundi(e["amount"])
		"buff":
			return "%s %.0f วิ" % [(db.skills[e["skill"]] as GameDb.SkillDef).name_th, e["seconds"]]
		"foe_hit":
			var extra := ""
			if e.get("slam", false):
				extra = " ทุบแรง!"
			if e.get("absorbed", 0.0) > 0.0:
				extra += " (โล่กัน %d)" % roundi(e["absorbed"])
			return "%s ตีฮีโร่ %d%s" % [foe_name, roundi(e["dmg"]), extra]
		"foe_miss":
			return "%s ตีพลาด (หลบได้)" % foe_name
		"kill":
			return "%s ตาย +%d XP" % [foe_name, e["xp"]]
		"end":
			return "ชนะการต่อสู้" if e["won"] else "ฮีโร่พ่ายแพ้"
	return ""


static func color(e: Dictionary) -> Color:
	match e["k"]:
		"hit":
			return UiTheme.GOLD if e.get("via", "") != "" or e.get("crit", false) else UiTheme.TEXT
		"foe_hit":
			return UiTheme.BAD
		"kill":
			return UiTheme.GOOD
		"heal", "buff", "cast":
			return Color("2ce8f5")
		"miss", "foe_miss":
			return UiTheme.TEXT_DIM
		"end":
			return UiTheme.GOLD
	return UiTheme.TEXT
