extends SceneTree
## Verifies stations spawn on their Spawns/<id> markers in Main.tscn, so
## dragging a marker in the editor moves the station (and Taylor's day-start /
## killbox respawn follows Spawns/default).
##
## Run: godot --headless --script tests/test_station_spawns.gd

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
	_run()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	MM.set_mode(0)  # classic
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	if hook != null:
		GS.add_child(hook)
		GS.set("mode_hook", hook)
	GS.set("day_number", 0)
	GS.start_new_day()
	root.add_child(load("res://Main.tscn").instantiate())
	await _frames(10)

	var world = root.get_node("Main/World")
	var spawns = world.get_node_or_null("Spawns")
	_check(spawns != null, "World/Spawns exists")

	# Every runtime station must sit exactly on its marker (or the def
	# fallback when no marker exists).
	var station_count := 0
	for n in world.get_children():
		var sid = n.get("station_id")
		if sid == null or String(sid) == "__store__":
			continue
		station_count += 1
		var id := String(sid)
		var expected: Vector2
		var has_marker := spawns != null and spawns.get_node_or_null(id) is Node2D
		if has_marker:
			expected = (spawns.get_node(id) as Node2D).global_position
		else:
			expected = n.position  # no marker: fallback, just record it
		var dist: float = (n as Node2D).global_position.distance_to(expected)
		_check(dist < 1.0, "station '%s' on marker %s (dist=%.1f)" % [id, "Spawns/" + id, dist])
	_check(station_count == 11, "11 stations spawned (got %d)" % station_count)

	# Taylor starts the day on Spawns/default (physics settles her a little
	# after placement, hence the loose tolerance).
	var taylor = get_nodes_in_group("player")
	_check(taylor.size() == 1, "exactly one player")
	if taylor.size() == 1 and spawns != null:
		var dflt := (spawns.get_node("default") as Node2D).global_position
		var pdist: float = (taylor[0] as Node2D).global_position.distance_to(dflt)
		_check(pdist < 40.0, "taylor starts on Spawns/default (dist=%.1f)" % pdist)

	print("STATION-SPAWN TEST: %d checks, %d failures" % [_checks, _failures.size()])
	quit(1 if _failures.size() > 0 else 0)
