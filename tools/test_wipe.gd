extends SceneTree
## Functional test: clear_all_save_data() wipes files + resets state.
## Run: godot --headless --script tools/test_wipe.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	_run()
	return false


func _run() -> void:
	var GS = root.get_node("/root/GameState")
	# Seed some state: savings, an unlock, a bird, a permanent upgrade.
	GS.set("savings", 123.0)
	var um = GS.get("unlocked_modes")
	um.append("classic")
	GS.set("unlocked_modes", um)
	var birds = GS.get("birds_found")
	birds.append("robin")
	GS.set("birds_found", birds)
	GS.set("permanent_upgrades", {"roomba": 1})
	GS.save_bank()
	_check(FileAccess.file_exists("user://taylor_savings.cfg"), "bank file exists before wipe")

	# Task serotonin: taylor completion grants +8.
	GS.set("serotonin", 50.0)
	GS.set("cortisol", 50.0)
	GS.register_task_def({"id": "wipe_test_task", "label": "Wipe test", "cortisol_relief": 10.0})
	GS._activate_task({"id": "wipe_test_task", "label": "Wipe test", "cortisol_relief": 10.0})
	var before_ser: float = GS.get("serotonin")
	GS.complete_task("wipe_test_task", "taylor")
	_check(abs(GS.get("serotonin") - (before_ser + 8.0)) < 0.01, "taylor completion grants +8 serotonin")

	# Delegated completion grants no serotonin.
	GS.set("serotonin", 50.0)
	GS._activate_task({"id": "wipe_test_task2", "label": "Wipe test 2", "cortisol_relief": 10.0})
	GS.complete_task("wipe_test_task2", "robot")
	_check(abs(GS.get("serotonin") - 50.0) < 0.01, "robot completion grants no serotonin")

	# Now wipe.
	GS.clear_all_save_data()
	_check(not FileAccess.file_exists("user://taylor_savings.cfg"), "bank file deleted")
	_check(abs(GS.get("savings") - 0.0) < 0.01, "savings reset to 0")
	_check((GS.get("unlocked_modes") as Array).is_empty(), "unlocked_modes cleared")
	_check((GS.get("birds_found") as Array).is_empty(), "birds_found cleared")
	_check((GS.get("permanent_upgrades") as Dictionary).is_empty(), "permanent_upgrades cleared")

	if _fails == 0:
		print("WIPE TEST ALL GREEN")
	else:
		print("WIPE TEST FAILURES: ", _fails)
	quit(1 if _fails > 0 else 0)
