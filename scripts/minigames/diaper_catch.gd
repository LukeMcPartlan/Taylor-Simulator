class_name DiaperCatch
extends Minigame
## Change-baby station — "Diaper Catch". Slide the changing pad to catch
## what the baby needs: exactly 1 diaper, 1 baby powder, 1 wipe, and
## 1 change of clothes. Only items you still need ever spawn. The baby
## fights back with poop, pee, and vomit — catching any of those knocks
## one collected item back off your list. Collect all four to win.
## 60-second timer.
##
## Controls: A/D or Left/Right to slide the pad.

const FALL_SPEED: float = 260.0
const PAD_W: float = 120.0
const TIME_LIMIT: float = 60.0
const EW_TIME: float = 0.8
const GROSS_CHANCE: float = 0.65

const GOODS: Array[String] = ["diaper", "powder", "wipe", "clothes"]
const GOOD_LABELS := {"diaper": "Diaper", "powder": "Powder",
	"wipe": "Wipe", "clothes": "Outfit"}
const GROSS_KINDS: Array[String] = ["poop", "pee", "vomit"]

# Placeholder item art (gross-outs stay procedurally drawn, sorry).
const GOOD_TEX := {
	"diaper": preload("res://art/furniture/diaper.png"),
	"powder": preload("res://art/furniture/baby_powder.png"),
	"wipe": preload("res://art/furniture/baby_wipe.png"),
	"clothes": preload("res://art/furniture/baby_clothes.png"),
}

var _have := {"diaper": false, "powder": false, "wipe": false, "clothes": false}
var _pad_x: float = 0.0
var _items: Array = []  # Dictionaries {x, y, kind}
var _spawn_timer: float = 0.0
var _time_left: float = TIME_LIMIT
var _ew_timer: float = 0.0   # "EW!" popup after catching something gross
var _ew_pos := Vector2.ZERO


func start() -> void:
	super.start()
	title_text = "Diaper Catch"
	help_text = "Catch 1 diaper, 1 powder, 1 wipe, 1 fresh outfit. DODGE the gross stuff!"
	_pad_x = size.x / 2.0
	for k in GOODS:
		_have[k] = false
	_items.clear()
	_spawn_timer = 0.5
	_time_left = TIME_LIMIT
	_ew_timer = 0.0


func _missing_goods() -> Array:
	var out: Array = []
	for k in GOODS:
		if not bool(_have[k]):
			out.append(k)
	return out


func _roll_kind() -> String:
	if randf() < GROSS_CHANCE:
		return GROSS_KINDS[randi() % GROSS_KINDS.size()]
	var missing := _missing_goods()
	if missing.is_empty():
		return GROSS_KINDS[randi() % GROSS_KINDS.size()]
	return String(missing[randi() % missing.size()])


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


func _all_collected() -> bool:
	return _missing_goods().is_empty()


func _catch_item(kind: String, pos: Vector2) -> void:
	if kind in GOODS:
		if not bool(_have[kind]):
			_have[kind] = true
			if _all_collected():
				_end(true)
	else:
		# Gross stuff knocks one collected item back off the list.
		var owned: Array = []
		for k in GOODS:
			if bool(_have[k]):
				owned.append(k)
		if not owned.is_empty():
			_have[String(owned[randi() % owned.size()])] = false
		_ew_timer = EW_TIME
		_ew_pos = pos


# --- Test hooks ----------------------------------------------------------
func test_catch_diaper() -> void:
	_catch_item("diaper", Vector2.ZERO)


func test_catch_all_goods() -> void:
	for k in GOODS:
		_catch_item(k, Vector2.ZERO)


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
		var kind := String(it["kind"])
		if GOOD_TEX.has(kind):
			var tex: Texture2D = GOOD_TEX[kind]
			draw_texture(tex, p - tex.get_size() / 2.0)
			continue
		match kind:
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
	# Checklist HUD.
	var parts := PackedStringArray()
	for k in GOODS:
		parts.append("%s %s" % [String(GOOD_LABELS[k]), "v" if bool(_have[k]) else "x"])
	draw_string(font, Vector2(24, 96), "   ".join(parts),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 0.9))
	draw_string(font, Vector2(24, 124), "Time: %ds" % int(_time_left),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
