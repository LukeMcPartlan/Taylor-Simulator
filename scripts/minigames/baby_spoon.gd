class_name BabySpoon
extends Minigame
## Feed-baby station — "Spoon Timing". A marker sweeps back and forth;
## press SPACE when it's inside the green zone to land a spoonful.
## 5 spoonfuls to win. 3 misses and the baby throws the bowl (fail).
##
## Controls: SPACE to feed when the marker is green.

const WIN_SPOONFULS: int = 5
const MAX_MISSES: int = 3
const BAR_W: float = 460.0
const ZONE_W: float = 110.0

var _spoonfuls: int = 0
var _misses: int = 0
var _marker_t: float = 0.0   # 0..1 ping-pong position
var _marker_dir: float = 1.0
var _marker_speed: float = 0.9  # sweeps per second
var _bar := Rect2()


func start() -> void:
	super.start()
	title_text = "Spoon Timing"
	help_text = "SPACE when the marker is in the GREEN zone! %d spoonfuls." % WIN_SPOONFULS
	_bar = Rect2(Vector2((size.x - BAR_W) / 2.0, size.y / 2.0 - 20.0), Vector2(BAR_W, 40))
	_spoonfuls = 0
	_misses = 0
	_marker_t = 0.0
	_marker_dir = 1.0


func _process(delta: float) -> void:
	if _over:
		return
	_marker_t += _marker_dir * _marker_speed * delta * _speed
	if _marker_t >= 1.0:
		_marker_t = 1.0
		_marker_dir = -1.0
	elif _marker_t <= 0.0:
		_marker_t = 0.0
		_marker_dir = 1.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.keycode == KEY_SPACE and k.pressed and not k.echo:
		_try_spoon()


func _try_spoon() -> void:
	var x := _bar.position.x + _marker_t * BAR_W
	var zone := Rect2(_bar.get_center() - Vector2(ZONE_W / 2.0, 0), Vector2(ZONE_W, _bar.size.y))
	if zone.has_point(Vector2(x, _bar.get_center().y)):
		_spoonfuls += 1
		_marker_speed += 0.12  # baby gets wigglier each bite
		if _spoonfuls >= WIN_SPOONFULS:
			_end(true)
	else:
		_misses += 1
		if _misses >= MAX_MISSES:
			_end(false)


# --- Test hooks ----------------------------------------------------------
func test_spoon_hit() -> void:
	_marker_t = 0.5  # dead center = inside the green zone
	_try_spoon()


func test_spoon_miss() -> void:
	_marker_t = 0.0  # far edge = outside the zone
	_try_spoon()


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# Track.
	draw_rect(_bar, Color(0.22, 0.22, 0.28))
	# Green zone.
	var zone := Rect2(_bar.get_center() - Vector2(ZONE_W / 2.0, 0), Vector2(ZONE_W, _bar.size.y))
	draw_rect(zone, Color(0.3, 0.75, 0.35))
	# Marker.
	var mx := _bar.position.x + _marker_t * BAR_W
	draw_rect(Rect2(mx - 5, _bar.position.y - 10, 10, _bar.size.y + 20), Color(1.0, 0.9, 0.3))
	# Baby: circle face + open mouth that grows happier per spoonful.
	var baby := Vector2(size.x / 2.0, size.y / 2.0 + 150.0)
	draw_circle(baby, 44, Color(1.0, 0.85, 0.7))
	var mouth_r := 6.0 + 3.0 * _spoonfuls
	draw_circle(baby + Vector2(0, 12), mouth_r, Color(0.4, 0.15, 0.15))
	draw_string(font, Vector2(24, 120),
		"Spoonfuls: %d/%d   Misses: %d/%d" % [_spoonfuls, WIN_SPOONFULS, _misses, MAX_MISSES],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
