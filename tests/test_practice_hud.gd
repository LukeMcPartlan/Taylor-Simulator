extends SceneTree
## Headless test: practice mode hides the cortisol bar + label (2026-09-26).
## Cortisol is pinned at zero all day in practice, so the bar is dead UI.
## Classic keeps it.
##
## Run: godot --headless --script tests/test_practice_hud.gd

var _failures: Array = []
var _checks: int = 0
var GS = null
var MM = null


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		print("FAIL: ", name)


func _initialize() -> void:
	pass


var _booted := false


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_run_tests.call_deferred()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _set_mode(mode: int) -> void:
	MM.set_mode(mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	if hook != null:
		GS.add_child(hook)
		GS.set("mode_hook", hook)


func _boot_main() -> void:
	GS.set("day_number", 0)
	GS.start_new_day()
	root.add_child(load("res://Main.tscn").instantiate())


func _cortisol_hidden() -> Array:
	var hud = root.get_node("Main/HUD")
	var bar = hud.get_node("TopLeft/Panel/Margin/VBox/CortisolBar")
	var label = hud.get_node("TopLeft/Panel/Margin/VBox/CortisolLabel")
	return [not bar.visible, not label.visible]


func _run_tests() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")

	# Classic: cortisol bar visible.
	_set_mode(0)
	_boot_main()
	await _frames(10)
	var classic := _cortisol_hidden()
	_check(not classic[0], "practice_hud: classic shows cortisol bar")
	_check(not classic[1], "practice_hud: classic shows cortisol label")
	root.get_node("Main").queue_free()
	await _frames(5)

	# Practice: cortisol bar + label hidden.
	_set_mode(5)
	_boot_main()
	await _frames(10)
	var practice := _cortisol_hidden()
	_check(practice[0], "practice_hud: practice hides cortisol bar")
	_check(practice[1], "practice_hud: practice hides cortisol label")

	print("----")
	print("PRACTICE HUD TEST: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
