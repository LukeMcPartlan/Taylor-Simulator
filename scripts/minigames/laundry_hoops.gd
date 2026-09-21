class_name LaundryHoops
extends Minigame
## Laundry station — "Laundry Hoops". Toss clothes into the hamper with
## arcade arc physics. Rapid-fire: throw the next garment while the last
## one is still in the air. Score 5 baskets to win; misses just fall.
##
## Controls: hold SPACE to charge, release to throw. Aim is fixed — it's
## about power control (WarioWare loves one-button timing).

const WIN_BASKETS: int = 5
const GRAVITY: float = 900.0
const MAX_POWER: float = 950.0
const CHARGE_RATE: float = 700.0  # power units per second
const SHOT_COLORS: Array[Color] = [
	Color(0.95, 0.6, 0.65), Color(0.55, 0.75, 0.95), Color(0.95, 0.85, 0.45),
	Color(0.6, 0.9, 0.6), Color(0.9, 0.9, 0.95),
]
const TEX_BASKET := preload("res://placeholder art/Sprites/laundry_basket.png")
const GARMENT_TEX: Array[Texture2D] = [
	preload("res://placeholder art/Sprites/garment_shirt.png"),
	preload("res://placeholder art/Sprites/garment_pants.png"),
	preload("res://placeholder art/Sprites/garment_sock.png"),
]

var _baskets: int = 0
var _charging: bool = false
var _power: float = 0.0
var _shots: Array = []  # Dictionaries {pos: Vector2, vel: Vector2, col: Color}
var _throws: int = 0


const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")


func _upgrade_tier(id: String) -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return 0
	return int(gs.call("upgrade_tier", id))
var _throw_origin := Vector2.ZERO
var _hamper := Rect2()


func start() -> void:
	super.start()
	title_text = "Laundry Hoops"
	help_text = "Hold SPACE to charge, release to shoot! Throw again mid-flight! %d baskets wins." % WIN_BASKETS
	_throw_origin = Vector2(110, size.y - 90)
	var hamper_tier := _upgrade_tier("hamper")
	var hw := _UPGRADE_DEFS.tier_fx("hamper", hamper_tier, "width", 110.0)
	_hamper = Rect2(Vector2(size.x - 190 - (hw - 110.0), size.y - 170), Vector2(hw, 90))
	if hamper_tier > 0:
		help_text += " %s equipped!" % String((_UPGRADE_DEFS.def("hamper")["tiers"] as Array)[hamper_tier - 1]["label"])
	_shots.clear()
	_throws = 0
	_charging = false
	_power = 0.0


func _next_color() -> Color:
	return SHOT_COLORS[_throws % SHOT_COLORS.size()]


func _process(delta: float) -> void:
	if _over:
		return
	# Charging is always available — even with laundry in the air.
	if Input.is_key_pressed(KEY_SPACE):
		_charging = true
		_power = minf(_power + CHARGE_RATE * delta, MAX_POWER)
	# Fly every live shot.
	var i := _shots.size() - 1
	while i >= 0:
		var s: Dictionary = _shots[i]
		var v: Vector2 = s["vel"]
		v.y += GRAVITY * delta
		s["vel"] = v
		var p: Vector2 = s["pos"] + v * delta
		s["pos"] = p
		if _hamper.has_point(p):
			_shots.remove_at(i)
			_score_basket()
			if _over:
				return
		elif p.y > size.y + 40 or p.x > size.x + 40:
			_shots.remove_at(i)
		i -= 1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.keycode != KEY_SPACE or k.echo:
		return
	if not k.pressed and _charging:
		# Release: throw toward the hamper. Aim angle is fixed at 55 degrees;
		# only power varies, so it's a one-button skill shot. Other shots
		# already in the air are unaffected.
		_charging = false
		var angle := deg_to_rad(-55.0)
		var vel := Vector2(cos(angle), sin(angle)) * (280.0 + _power)
		_power = 0.0
		_shots.append({"pos": _throw_origin, "vel": vel, "col": _next_color(),
			"gi": _throws % GARMENT_TEX.size()})
		_throws += 1


func _score_basket() -> void:
	_baskets += 1
	if _baskets >= WIN_BASKETS:
		_end(true)


# --- Test hooks ----------------------------------------------------------
func test_score_basket() -> void:
	_score_basket()


func test_throw(power: float = 500.0) -> void:
	_charging = true
	_power = power
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = false
	_unhandled_input(ev)


func _draw_garment(p: Vector2, gi: int, col: Color) -> void:
	## Placeholder garment art, tinted the shot's color.
	var tex: Texture2D = GARMENT_TEX[gi % GARMENT_TEX.size()]
	draw_texture(tex, p - tex.get_size() / 2.0, col)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# Hamper: placeholder basket art stretched over the (possibly upgraded) rect.
	draw_texture_rect(TEX_BASKET, _hamper, false)
	# Taylor-ish thrower marker.
	draw_circle(_throw_origin, 16, Color(0.5, 0.7, 1.0))
	# Ready garment (next color up) + every flying shot.
	_draw_garment(_throw_origin + Vector2(0, -26), _throws % GARMENT_TEX.size(), _next_color())
	for s in _shots:
		_draw_garment(s["pos"], int(s["gi"]), s["col"])
	# Charge meter.
	if _charging:
		var frac := _power / MAX_POWER
		draw_rect(Rect2(40, size.y - 60, 200 * frac, 18), Color(1.0, 0.7, 0.2))
		draw_rect(Rect2(40, size.y - 60, 200, 18), Color(0.85, 0.85, 0.85), false, 2.0)
	draw_string(font, Vector2(40, 120),
		"Baskets: %d/%d" % [_baskets, WIN_BASKETS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 0.9))
