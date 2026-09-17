class_name LaundryHoops
extends Minigame
## Laundry station — "Laundry Hoops". Toss clothes into the hamper with
## arcade arc physics. Score 5 baskets to win; misses just reset the throw.
##
## Controls: hold SPACE to charge, release to throw. Aim is fixed — it's
## about power control (WarioWare loves one-button timing).

const WIN_BASKETS: int = 5
const GRAVITY: float = 900.0
const MAX_POWER: float = 950.0
const CHARGE_RATE: float = 700.0  # power units per second

var _baskets: int = 0
var _charging: bool = false
var _power: float = 0.0
# The flying garment. null-ish state via _flying flag.
var _flying: bool = false
var _pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _throw_origin := Vector2.ZERO
var _hamper := Rect2()


func start() -> void:
	super.start()
	title_text = "Laundry Hoops"
	help_text = "Hold SPACE to charge, release to shoot! %d baskets wins." % WIN_BASKETS
	_throw_origin = Vector2(110, size.y - 90)
	_hamper = Rect2(Vector2(size.x - 190, size.y - 170), Vector2(110, 90))
	_reset_throw()


func _reset_throw() -> void:
	_flying = false
	_charging = false
	_power = 0.0
	_pos = _throw_origin


func _process(delta: float) -> void:
	if _over:
		return
	if not _flying:
		if Input.is_key_pressed(KEY_SPACE):
			_charging = true
			_power = minf(_power + CHARGE_RATE * delta, MAX_POWER)
	else:
		_vel.y += GRAVITY * delta
		_pos += _vel * delta
		if _hamper.has_point(_pos):
			_score_basket()
		elif _pos.y > size.y + 40 or _pos.x > size.x + 40:
			_reset_throw()  # missed — garment hits the floor, try again
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.keycode != KEY_SPACE or k.echo:
		return
	if not k.pressed and _charging and not _flying:
		# Release: throw toward the hamper. Aim angle is fixed at 55 degrees;
		# only power varies, so it's a one-button skill shot.
		_flying = true
		_charging = false
		var angle := deg_to_rad(-55.0)
		_vel = Vector2(cos(angle), sin(angle)) * (280.0 + _power)


func _score_basket() -> void:
	_baskets += 1
	if _baskets >= WIN_BASKETS:
		_end(true)
	else:
		_reset_throw()


# --- Test hooks ----------------------------------------------------------
func test_score_basket() -> void:
	_score_basket()


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# Hamper: brown basket with a rim.
	draw_rect(_hamper.grow(6), Color(0.3, 0.2, 0.12))
	draw_rect(_hamper, Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(_hamper.position, Vector2(_hamper.size.x, 14)), Color(0.42, 0.28, 0.14))
	# Taylor-ish thrower marker.
	draw_circle(_throw_origin, 16, Color(0.5, 0.7, 1.0))
	# Garment: a little shirt-colored blob (skip while charging? no — show it).
	if not _flying:
		draw_circle(_throw_origin + Vector2(0, -26), 12, Color(0.95, 0.6, 0.65))
	else:
		draw_circle(_pos, 12, Color(0.95, 0.6, 0.65))
	# Charge meter.
	if _charging:
		var frac := _power / MAX_POWER
		draw_rect(Rect2(40, size.y - 60, 200 * frac, 18), Color(1.0, 0.7, 0.2))
		draw_rect(Rect2(40, size.y - 60, 200, 18), Color(0.85, 0.85, 0.85), false, 2.0)
	draw_string(font, Vector2(40, 120),
		"Baskets: %d/%d" % [_baskets, WIN_BASKETS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 0.9))
