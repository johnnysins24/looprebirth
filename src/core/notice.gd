class_name Notice
extends RefCounted
## One entry in the side notification list (docs/design/07-ux.md). Every choice the player
## has to make is a Notice; it waits until the player opens it.

var id := 0
var kind := ""  ## stat | lap_card | skill_card | item | shop | town_perk | event | info (just a message)
var title := ""
var detail := ""
var created := 0.0  ## run time when it appeared
var expires := -1.0  ## run time when it vanishes by itself; -1 = never
var payload: Dictionary = {}
