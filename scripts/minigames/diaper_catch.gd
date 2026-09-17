class_name DiaperCatch
extends Minigame
## Change-baby station — "Diaper Catch". Slide the changing pad to catch
## falling diapers. Rubber ducks are NOT diapers — each duck caught costs
## one diaper. Catch 8 diapers to win. 60-second timer.
##
## Controls: A/D or Left/Right to slide the pad.

const WIN_DIAPERS: int = 8
const FALL_SPEED: float = 260.0
const PAD_W: float = 120.0
const TIME_LIMIT: float = 60.0

var _diapers: int = 0
var _pad_x: float = 0.0
var _items: Array = []  # Dictionaries {x, y, kind: "diaper"|"duck"}
var _spawn_timer: float = 0.0
var _time_left: float = TIME_LIMIT


func start() -> void:
	super.start()
	title_text = "Diaper Catch"
	help_text = "Catch diapers, DODGE the rubber ducks! %d diapers wins." % WIN_DIAPERS
	_pad_x = size.x / 2.0
	_diapers = 0
	_items.clear()
	_spawn_timer = 0.5
	_time_left = TIME_LIMIT


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	# Pad movement.
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	_pad_x = clampf(_pad_x + dir * 480.0 * delta, PAD_W / 2.0 + 16.0, size.x - PAD_W / 2.0 - 16.0)
	# Spawn.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(0.5, 0.9) / _speed
		var kind := "duck" if randf() < 0.3 else "diaper"
		_items.append({"x": randf_range(60.0, size.x - 60.0), "y": 96.0, "kind": kind})
	# Fall + catch.
	var pad_y := size.y - 80.0
	var i := _items.size() - 1
	while i >= 0:
		var it: Dictionary = _items[i]
		it["y"] = float(it["y"]) + FALL_SPEED * delta / _speed
		if float(it["y"]) >= pad_y - 10.0:
			if absf(float(it["x"]) - _pad_x) <= PAD_W / 2.0:
				_catch_item(String(it["kind"]))
			_items.remove_at(i)
			if _over:
				return
		elif float(it["y"]) > size.y + 30.0:
			_items.remove_at(i)
		i -= 1
	queue_redraw()


func _catch_item(kind: String) -> void:
	if kind == "diaper":
		_diapers += 1
		if _diapers >= WIN_DIAPERS:
			_end(true)
	else:
		_diapers = maxi(0, _diapers - 1)  # ducks undo your progress


# --- Test hooks ----------------------------------------------------------
func test_catch_diaper() -> void:
	_catch_item("diaper")


func test_catch_duck() -> void:
	_catch_item("duck")


func test_timeout() -> void:
	_end(false)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	var pad_y := size.y - 80.0
	# Changing pad.
	draw_rect(Rect2(_pad_x - PAD_W / 2.0, pad_y, PAD_W, 22), Color(0.6, 0.75, 0.95))
	draw_rect(Rect2(_pad_x - PAD_W / 2.0, pad_y, PAD_W, 22), Color(0.3, 0.4, 0.6), false, 2.0)
	# Falling items.
	for it in _items:
		var p := Vector2(float(it["x"]), float(it["y"]))
		if String(it["kind"]) == "diaper":
			draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color(1, 1, 1))
			draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color(0.6, 0.6, 0.7), false, 2.0)
		else:
			draw_circle(p, 14, Color(1.0, 0.85, 0.2))
			draw_circle(p + Vector2(8, -6), 7, Color(1.0, 0.85, 0.2))  # duck head
	draw_string(font, Vector2(24, 120),
		"Diapers: %d/%d   Time: %ds" % [_diapers, WIN_DIAPERS, int(_time_left)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
