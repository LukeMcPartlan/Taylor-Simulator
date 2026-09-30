extends SceneTree
## Headless test for the 2026-09-30 art update (Luke's ToBeAdded sprites):
##  - dishes station uses the new sink art
##  - laptop store uses the new laptop art, sitting on the desk decor
##  - dining table decor sits where the sink was; sink moved 3 tiles right
##  - cot decor in the basement blue room; chris spawns on it
##  - washer/dryer moved 6 tiles right, toilet 4 tiles right
##  - NPC patrol bounds are x 133..570
##
## Run: godot --headless --script tests/test_new_art.gd

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
	_boot()
	_run_tests()
	return false


func _boot() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	MM.set_mode(0)  # CLASSIC
	GS.set("day_number", 0)
	GS.start_new_day()
	var scene: PackedScene = load("res://Main.tscn")
	root.add_child(scene.instantiate())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run_tests() -> void:
	await _frames(10)
	var main = root.get_node("Main")
	var spawns = main.get_node("World/Spawns")
	var decor = main.get_node("World/Decor")

	# --- sink art on the dishes station -------------------------------------
	var station_script: Script = load("res://scripts/station.gd")
	var consts: Dictionary = station_script.get_script_constant_map()
	var sprites: Dictionary = consts.get("STATION_SPRITES", {})
	_check(String(sprites.get("dishes", "")) == "res://art/ToBeAdded/sink.png",
		"art: dishes station uses the new sink sprite")

	# --- dining table where the sink was; sink moved 3 tiles right ---------
	var dishes_pos: Vector2 = (spawns.get_node("dishes") as Node2D).position
	_check(dishes_pos.distance_to(Vector2(628, -119)) < 0.5,
		"art: dishes marker moved 3 tiles right of the old sink spot")
	var table = decor.get_node_or_null("dining_table") as Sprite2D
	_check(table != null and table.position.distance_to(Vector2(532, -119)) < 0.5,
		"art: dining table decor sits where the sink was")

	# --- laptop art + desk --------------------------------------------------
	var laptop_store = null
	for n in main.get_node("World").get_children():
		if n is Node and n.get_script() != null \
				and String(n.get_script().resource_path).ends_with("store_cortisol.gd"):
			laptop_store = n
			break
	_check(laptop_store != null, "art: laptop store spawned")
	if laptop_store != null:
		var found_laptop := false
		for c in laptop_store.get_children():
			if c is Sprite2D and (c as Sprite2D).texture != null \
					and (c as Sprite2D).texture.resource_path == "res://art/ToBeAdded/Laptop.png":
				found_laptop = true
		_check(found_laptop, "art: laptop store uses the new laptop sprite")
	var desk = decor.get_node_or_null("desk") as Sprite2D
	_check(desk != null and desk.texture != null \
			and desk.texture.resource_path == "res://art/ToBeAdded/desk.png" \
			and desk.position.distance_to(Vector2(655, -353)) < 0.5,
		"art: desk decor under the laptop")

	# --- cot in the blue room; chris spawns on it ---------------------------
	var cot = decor.get_node_or_null("cot") as Sprite2D
	_check(cot != null and cot.texture != null \
			and cot.texture.resource_path == "res://art/ToBeAdded/cot.png",
		"art: cot decor exists with the new cot sprite")
	var chris_pos: Vector2 = (spawns.get_node("chris") as Node2D).position
	_check(cot != null and chris_pos.distance_to(cot.position) < 0.5,
		"art: chris spawns on the cot")
	_check(cot != null and cot.position.x > 112.0 and cot.position.x < 336.0,
		"art: cot is inside the blue room")

	# --- washer/dryer +6 tiles, toilet +4 tiles ------------------------------
	var laundry_pos: Vector2 = (spawns.get_node("laundry") as Node2D).position
	_check(laundry_pos.distance_to(Vector2(353, 32)) < 0.5,
		"art: washer moved 6 tiles right")
	var dryer = decor.get_node_or_null("Dryer") as Sprite2D
	_check(dryer != null and dryer.position.distance_to(Vector2(428, 0)) < 0.5,
		"art: dryer moved 6 tiles right")
	var toilet_pos: Vector2 = (spawns.get_node("basement_toilet") as Node2D).position
	_check(toilet_pos.distance_to(Vector2(499, 45)) < 0.5,
		"art: toilet moved 4 tiles right")

	# --- patrol bounds --------------------------------------------------------
	var luke_consts: Dictionary = (load("res://scripts/luke.gd") as Script).get_script_constant_map()
	_check(float(luke_consts.get("WANDER_MIN_X", -1.0)) == 133.0 \
			and float(luke_consts.get("WANDER_MAX_X", -1.0)) == 570.0,
		"art: luke patrols x 133..570")
	var chris_consts: Dictionary = (load("res://scripts/chris.gd") as Script).get_script_constant_map()
	_check(float(chris_consts.get("WANDER_MIN_X", -1.0)) == 133.0 \
			and float(chris_consts.get("WANDER_MAX_X", -1.0)) == 570.0,
		"art: chris patrols x 133..570")

	print("----")
	print("NEW ART TEST: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
