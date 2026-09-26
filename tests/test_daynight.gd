extends SceneTree
## Headless test for the day/night cycle (2026-09-26):
##  - tint keyframes blend smoothly (dawn warm, day clear, sunset orange, night dark)
##  - phase icons are readable per phase
##  - the DayNight node exists in the world and covers the camera view
##  - the HUD clock shows the phase icon
##
## Run: godot --headless --script tests/test_daynight.gd

var _failures: Array = []
var _checks: int = 0
var GS = null


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


func _run_tests() -> void:
	GS = root.get_node("/root/GameState")

	# --- tint keyframes -------------------------------------------------------
	var dawn: Color = DayNight.tint_for_hour(6.5)
	_check(dawn.r > 0.7 and dawn.r > dawn.b and dawn.a > 0.05,
		"daynight: 6:30am tint is warm (r=%.2f b=%.2f a=%.2f)" % [dawn.r, dawn.b, dawn.a])
	var noon: Color = DayNight.tint_for_hour(12.0)
	_check(noon.a < 0.01, "daynight: noon tint is transparent")
	var sunset: Color = DayNight.tint_for_hour(19.5)
	_check(sunset.r > 0.9 and sunset.b < 0.4 and sunset.a > 0.1,
		"daynight: 7:30pm tint is orange (r=%.2f b=%.2f a=%.2f)" % [sunset.r, sunset.b, sunset.a])
	var night: Color = DayNight.tint_for_hour(22.0)
	_check(night.b > night.r and night.a > 0.3,
		"daynight: 10pm tint is cool and dark (b=%.2f r=%.2f a=%.2f)" % [night.b, night.r, night.a])
	# Smooth blend: 7am sits between dawn (6am) and clear (8am), not snapping.
	var seven: Color = DayNight.tint_for_hour(7.0)
	var dawn6: Color = DayNight.tint_for_hour(6.0)
	_check(seven.a < dawn6.a and seven.a > noon.a,
		"daynight: 7am blends between dawn and day (a=%.3f)" % seven.a)
	# Never fully opaque: gameplay stays readable.
	for h in [6.0, 12.0, 19.5, 22.0, 25.0]:
		_check(DayNight.tint_for_hour(h).a < 0.5,
			"daynight: tint at %.0fh stays subtle (a=%.2f)" % [h, DayNight.tint_for_hour(h).a])

	# --- phase icons -----------------------------------------------------------
	_check(DayNight.phase_icon_for_hour(6.5) == "🌅", "daynight: dawn icon at 6:30am")
	_check(DayNight.phase_icon_for_hour(12.0) == "☀️", "daynight: day icon at noon")
	_check(DayNight.phase_icon_for_hour(19.0) == "🌇", "daynight: sunset icon at 7pm")
	_check(DayNight.phase_icon_for_hour(23.0) == "🌙", "daynight: night icon at 11pm")

	# --- world node ------------------------------------------------------------
	var MM = root.get_node("/root/ModeManager")
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
	_check(world != null, "daynight: world exists")
	var dn = world.get_node_or_null("DayNight")
	_check(dn != null, "daynight: DayNight node added to world")
	await _frames(5)
	var rect = dn.get_node_or_null("ColorRect") if dn != null else null
	if dn != null:
		rect = dn.get_child(0)
	_check(rect != null and rect is ColorRect, "daynight: overlay ColorRect exists")
	if rect != null:
		# Overlay must exactly cover the camera view (viewport / zoom).
		var cam = root.get_camera_2d()
		var expect: Vector2 = root.get_visible_rect().size
		if cam != null:
			expect = expect / (cam as Camera2D).zoom
		_check((rect.size - expect).length() < 2.0,
			"daynight: overlay covers the camera view (%.0fx%.0f)" % [rect.size.x, rect.size.y])
		_check(rect.z_index > 100, "daynight: overlay draws above world sprites")
		GS.set("time_hours", 22.0)
		await _frames(3)
		_check((rect as ColorRect).color.b > (rect as ColorRect).color.r,
			"daynight: overlay turns cool blue at 10pm")
		GS.set("time_hours", 6.0)

	# --- HUD clock ---------------------------------------------------------------
	var hud = root.get_node_or_null("Main/HUD")
	_check(hud != null, "daynight: HUD exists")
	if hud != null:
		GS.set("time_hours", 19.0)
		GS.emit_signal("clock_changed", GS.call("get_time_string"))
		await _frames(2)
		var clock_text: String = hud.get_node("ClockLabel").text
		_check("🌇" in clock_text, "daynight: HUD clock shows sunset icon (%s)" % clock_text)
		GS.set("time_hours", 6.0)

	print("----")
	print("checks: %d  failures: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
