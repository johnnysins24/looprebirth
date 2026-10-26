extends RefCounted
## Tiny assertion helper handed to every test method.

var failures: Array[String] = []
var checks := 0
var current := ""


func ok(cond: bool, msg: String = "") -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg: String = "") -> void:
	checks += 1
	if a != b:
		failures.append("%s: expected %s, got %s  %s" % [current, str(b), str(a), msg])


func near(a: float, b: float, tol: float, msg: String = "") -> void:
	checks += 1
	if absf(a - b) > tol:
		failures.append("%s: expected %s +/- %s, got %s  %s" % [current, str(b), str(tol), str(a), msg])
