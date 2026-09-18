class_name ToiletWhack
extends Minigame
## Basement toilet station — "Whack-a-Leak". All 10 leaks spring up at
## once around the toilet; click them to plug them before they spread.
## Win by plugging EVERY leak. Every 2s each active leak spawns one new
## leak adjacent to itself. 15+ active leaks at once = flooded = fail.
##
## Controls: click leaks with the mouse.

const START_LEAKS: int = 10
const SPAWN_INTERVAL: float = 2.0
const FLOOD_LIMIT: int = 15
const LEAK_RADIUS: float = 22.0

var _leaks: Array = []  # Dictionaries {pos: Vector2, age: float}
var _plugged: int = 0
var _toilet_pos := Vector2.ZERO
var _was_down: bool = false


func start() -> void:
	super.start()
	title_text = "Whack-a-Leak"
	help_text = "10 leaks at once! Plug EVERY leak — each one spawns a new leak every 2s!"
	_toilet_pos = Vector2(size.x / 2.0, size.y / 2.0 + 40.0)
	_leaks.clear()
	_plugged = 0
	# All ten leaks spring at once, spawn timers staggered so the first
	# wave doesn't land all in the same instant.
	for _i in START_LEAKS:
		_leaks.append({"pos": _random_leak_pos(), "age": randf_range(0.0, SPAWN_INTERVAL)})


func _random_leak_pos() -> Vector2:
	var ang := randf() * TAU
	var dist := randf_range(90.0, 200.0)
	var p := _toilet_pos + Vector2(cos(ang), sin(ang)) * dist
	return _clamp_to_panel(p)


## A leak spreads: one new leak right next to its parent.
func _adjacent_leak_pos(parent: Vector2) -> Vector2:
	var ang := randf() * TAU
	var dist := randf_range(40.0, 70.0)
	return _clamp_to_panel(parent + Vector2(cos(ang), sin(ang)) * dist)


func _clamp_to_panel(p: Vector2) -> Vector2:
	p.x = clampf(p.x, 60.0, size.x - 60.0)
	p.y = clampf(p.y, 120.0, size.y - 60.0)
	return p


func _process(delta: float) -> void:
	if _over:
		return
	# Age + spread: every 2s each leak births one adjacent leak.
	var i := _leaks.size() - 1
	while i >= 0:
		var leak: Dictionary = _leaks[i]
		leak["age"] = float(leak["age"]) + delta
		if float(leak["age"]) >= SPAWN_INTERVAL / _speed:
			leak["age"] = 0.0
			_leaks.append({"pos": _adjacent_leak_pos(leak["pos"]), "age": 0.0})
		i -= 1
	if _leaks.size() >= FLOOD_LIMIT:
		_end(false)
		return
	# Click to plug (edge-triggered).
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if down and not _was_down:
		_try_plug(get_local_mouse_position())
	_was_down = down
	queue_redraw()


func _try_plug(pos: Vector2) -> void:
	for i in _leaks.size():
		var leak: Dictionary = _leaks[i]
		if (leak["pos"] as Vector2).distance_to(pos) <= LEAK_RADIUS + 10.0:
			_plug_leak(i)
			return


func _plug_leak(i: int) -> void:
	_leaks.remove_at(i)
	_plugged += 1
	# Win = the board is clear. No quota: every last leak must go.
	if _leaks.is_empty():
		_end(true)


# --- Test hooks ----------------------------------------------------------
func test_plug_all() -> void:
	while not _leaks.is_empty():
		_plug_leak(_leaks.size() - 1)


func test_flood() -> void:
	for _i in FLOOD_LIMIT:
		_leaks.append({"pos": _random_leak_pos(), "age": 0.0})
	if _leaks.size() >= FLOOD_LIMIT:
		_end(false)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# The toilet: tank + bowl, programmer-art edition.
	draw_rect(Rect2(_toilet_pos + Vector2(-46, -110), Vector2(92, 44)), Color(0.85, 0.87, 0.9))
	draw_circle(_toilet_pos + Vector2(0, -30), 44, Color(0.9, 0.92, 0.95))
	draw_circle(_toilet_pos + Vector2(0, -30), 30, Color(0.45, 0.6, 0.7))
	draw_rect(Rect2(_toilet_pos + Vector2(-20, 8), Vector2(40, 60)), Color(0.85, 0.87, 0.9))
	# Leaks: pulsing blue blobs, redder as they age.
	for leak in _leaks:
		var p: Vector2 = leak["pos"]
		var age_frac: float = clampf(float(leak["age"]) / SPAWN_INTERVAL, 0.0, 1.0)
		var col := Color(0.3, 0.6, 1.0).lerp(Color(1.0, 0.3, 0.2), age_frac)
		var r := LEAK_RADIUS * (1.0 + 0.15 * sin(age_frac * 12.0))
		draw_circle(p, r, col)
		draw_arc(p, r + 6.0, 0, TAU * (1.0 - age_frac), 20, Color(1, 1, 1, 0.7), 3.0)
	draw_string(font, Vector2(24, 120),
		"Plugged: %d   Active leaks: %d" % [_plugged, _leaks.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
