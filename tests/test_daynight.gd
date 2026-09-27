extends SceneTree
## Headless test for the day/night cycle (2026-09-26):
##  - tint keyframes blend smoothly: dark purple at 6am, warm by 7, sunrise
##    colors to 9, clear midday, sunset warmth to 8pm, purple to 10pm,
##    very dark to 1am
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
	var six: Color = DayNight.tint_for_hour(6.0)
	_check(six.b > six.r and six.a > 0.3,
		"daynight: 6am tint is dark purple (b=%.2f r=%.2f a=%.2f)" % [six.b, six.r, six.a])
	var seven_am: Color = DayNight.tint_for_hour(7.0)
	_check(seven_am.r > 0.7 and seven_am.r > seven_am.b,
		"daynight: 7am tint is warm (r=%.2f b=%.2f)" % [seven_am.r, seven_am.b])
	var eight: Color = DayNight.tint_for_hour(8.0)
	_check(eight.r > 0.9 and eight.a > 0.1,
		"daynight: 8am tint is sunrise colors (r=%.2f a=%.2f)" % [eight.r, eight.a])
	var noon: Color = DayNight.tint_for_hour(12.0)
	_check(noon.a < 0.01, "daynight: noon tint is transparent")
	var sunset: Color = DayNight.tint_for_hour(20.0)
	_check(sunset.r > 0.9 and sunset.b < 0.4 and sunset.a > 0.2,
		"daynight: 8pm tint is sunset warm (r=%.2f b=%.2f a=%.2f)" % [sunset.r, sunset.b, sunset.a])
	var ten_pm: Color = DayNight.tint_for_hour(22.0)
	_check(ten_pm.b > ten_pm.r and ten_pm.a > 0.3,
		"daynight: 10pm tint is purple (b=%.2f r=%.2f a=%.2f)" % [ten_pm.b, ten_pm.r, ten_pm.a])
	var one_am: Color = DayNight.tint_for_hour(25.0)
	_check(one_am.r < 0.1 and one_am.g < 0.1 and one_am.b < 0.15 and one_am.a > 0.5,
		"daynight: 1am tint is very dark (a=%.2f)" % one_am.a)
	# Smooth blend: 6:30 sits between 6am purple and 7am warm, not snapping.
	var six_thirty: Color = DayNight.tint_for_hour(6.5)
	_check(six_thirty.a < six.a and six_thirty.a > seven_am.a,
		"daynight: 6:30am blends between purple and warm (a=%.3f)" % six_thirty.a)
	# Never fully opaque: gameplay stays readable even at 1am.
	for h in [6.0, 12.0, 20.0, 22.0, 25.0]:
		_check(DayNight.tint_for_hour(h).a < 0.7,
			"daynight: tint at %.0fh stays below 0.7 (a=%.2f)" % [h, DayNight.tint_for_hour(h).a])

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
