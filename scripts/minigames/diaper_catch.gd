class_name DiaperCatch
extends Minigame
## Change-baby station — "Diaper Catch". Slide the changing pad to catch
## falling diapers. The baby is fighting back: dodge the poop, pee, and
## vomit — catching any of them costs one diaper. Catch 8 diapers to win.
## 60-second timer.
##
## Controls: A/D or Left/Right to slide the pad.

const WIN_DIAPERS: int = 8
const FALL_SPEED: float = 260.0
const PAD_W: float = 120.0
const TIME_LIMIT: float = 60.0
const EW_TIME: float = 0.8

var _diapers: int = 0
var _pad_x: float = 0.0
var _items: Array = []  # Dictionaries {x, y, kind: "diaper"|"poop"|"pee"|"vomit"}
var _spawn_timer: float = 0.0
var _time_left: float = TIME_LIMIT
var _ew_timer: float = 0.0   # "EW!" popup after catching something gross
var _ew_pos := Vector2.ZERO


func start() -> void:
	super.start()
	title_text = "Diaper Catch"
	help_text = "Catch diapers, DODGE the poop, pee & vomit! %d diapers wins." % WIN_DIAPERS
	_pad_x = size.x / 2.0
	_diapers = 0
	_items.clear()
	_spawn_timer = 0.5
	_time_left = TIME_LIMIT
	_ew_timer = 0.0


func _roll_kind() -> String:
	var roll := randf()
	if roll < 0.13:
		return "poop"
	if roll < 0.25:
		return "pee"
	if roll < 0.37:
		return "vomit"
	return "diaper"


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	_ew_timer = maxf(_ew_timer - delta, 0.0)
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
		_items.append({"x": randf_range(60.0, size.x - 60.0), "y": 96.0,
			"kind": _roll_kind()})
	# Fall + catch.
	var pad_y := size.y - 80.0
	var i := _items.size() - 1
	while i >= 0:
		var it: Dictionary = _items[i]
		it["y"] = float(it["y"]) + FALL_SPEED * delta / _speed
		if float(it["y"]) >= pad_y - 10.0:
			if absf(float(it["x"]) - _pad_x) <= PAD_W / 2.0:
				_catch_item(String(it["kind"]),
					Vector2(float(it["x"]), float(it["y"])))
			_items.remove_at(i)
			if _over:
				return
		elif float(it["y"]) > size.y + 30.0:
			_items.remove_at(i)
		i -= 1
	queue_redraw()


func _catch_item(kind: String, pos: Vector2) -> void:
	if kind == "diaper":
		_diapers += 1
		if _diapers >= WIN_DIAPERS:
			_end(true)
	else:
		_diapers = maxi(0, _diapers - 1)  # gross stuff undoes your progress
		_ew_timer = EW_TIME
		_ew_pos = pos


# --- Test hooks ----------------------------------------------------------
func test_catch_diaper() -> void:
	_catch_item("diaper", Vector2.ZERO)


func test_catch_gross() -> void:
	_catch_item("poop", Vector2(100, 100))


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
		match String(it["kind"]):
			"diaper":
				draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color(1, 1, 1))
				draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color(0.6, 0.6, 0.7), false, 2.0)
			"poop":
				# A modest little pile, in browns.
				draw_circle(p + Vector2(0, 6), 13, Color(0.35, 0.22, 0.1))
				draw_circle(p + Vector2(0, -4), 9, Color(0.42, 0.27, 0.13))
				draw_circle(p + Vector2(0, -12), 6, Color(0.5, 0.33, 0.16))
			"pee":
				# A yellow stream with drops.
				draw_rect(Rect2(p - Vector2(3, 18), Vector2(6, 30)), Color(0.95, 0.8, 0.15))
				draw_circle(p + Vector2(0, 18), 5, Color(0.95, 0.8, 0.15))
				draw_circle(p + Vector2(4, 28), 3, Color(0.95, 0.8, 0.15))
			"vomit":
				# A green splat with chunks. Sorry.
				draw_circle(p, 14, Color(0.45, 0.65, 0.25))
				draw_circle(p + Vector2(-5, -3), 4, Color(0.3, 0.48, 0.16))
				draw_circle(p + Vector2(6, 4), 5, Color(0.3, 0.48, 0.16))
				draw_circle(p + Vector2(2, -7), 3, Color(0.55, 0.72, 0.3))
	# "EW!" popup when you catch something gross.
	if _ew_timer > 0.0:
		var a := clampf(_ew_timer / EW_TIME, 0.0, 1.0)
		draw_string(font, _ew_pos + Vector2(-30, -24), "EW!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.4, 0.2, a))
	draw_string(font, Vector2(24, 120),
		"Diapers: %d/%d   Time: %ds" % [_diapers, WIN_DIAPERS, int(_time_left)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
