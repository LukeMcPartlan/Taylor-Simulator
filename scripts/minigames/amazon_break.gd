class_name AmazonBreak
extends Minigame
## Amazon boxes station — "Box Breaker". Brick-breaker: flatten every Amazon
## box with the tape-gun paddle. 3 lost balls and the boxes win. 120s timer.
##
## Controls: A/D or Left/Right, or just move the mouse.

const BOX_COLS: int = 7
const BOX_ROWS: int = 4
const BOX_SIZE := Vector2(86, 36)
const PADDLE_W: float = 120.0
const BALL_R: float = 9.0
const BASE_BALL_SPEED: float = 400.0
const TIME_LIMIT: float = 120.0
const MAX_LIVES: int = 3

var _boxes: Array = []  # BOX_ROWS x BOX_COLS of bool (true = still boxed)
var _boxes_left: int = 0
var _boxes_broken: int = 0
var _paddle_x: float = 0.0
var _pw: float = PADDLE_W  # paddle width; Paddle Extender buff widens it
var _balls: Array = []  # Dictionaries {pos: Vector2, vel: Vector2}
var _respawn_timer: float = 0.0
var _lives: int = MAX_LIVES
var _time_left: float = TIME_LIMIT
var _top := Vector2.ZERO
var _box_cols: Array = []


const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")


func _upgrade_tier(id: String) -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return 0
	return int(gs.call("upgrade_tier", id))


func _ball_count() -> int:
	return int(_UPGRADE_DEFS.tier_fx("extra_ball", _upgrade_tier("extra_ball"), "balls", 1.0))


func start() -> void:
	super.start()
	title_text = "Box Breaker"
	var extra_tier := _upgrade_tier("extra_ball")
	var paddle_tier := _upgrade_tier("paddle")
	var extra := ""
	if extra_tier > 0:
		extra += " %s!" % String((_UPGRADE_DEFS.def("extra_ball")["tiers"] as Array)[extra_tier - 1]["label"])
	if paddle_tier > 0:
		extra += " %s!" % String((_UPGRADE_DEFS.def("paddle")["tiers"] as Array)[paddle_tier - 1]["label"])
	help_text = "Break down every Amazon box! A/D or mouse. 3 missed balls = the boxes win.%s" % extra
	_pw = PADDLE_W * _UPGRADE_DEFS.tier_fx("paddle", paddle_tier, "width_mult", 1.0)
	_boxes.clear()
	_boxes_left = 0
	_boxes_broken = 0
	_box_cols.clear()
	var shades := [Color(0.72, 0.53, 0.30), Color(0.68, 0.49, 0.27), Color(0.76, 0.57, 0.33)]
	for _r in BOX_ROWS:
		var row: Array = []
		var crow: Array = []
		for _c in BOX_COLS:
			row.append(true)
			crow.append(shades[(_r + _c) % shades.size()])
			_boxes_left += 1
		_boxes.append(row)
		_box_cols.append(crow)
	_top = Vector2((size.x - BOX_COLS * BOX_SIZE.x) / 2.0, 100.0)
	_paddle_x = size.x / 2.0
	_lives = MAX_LIVES
	_time_left = TIME_LIMIT
	_serve_ball()


func _ball_speed() -> float:
	return minf(BASE_BALL_SPEED * (1.0 + 0.015 * _boxes_broken), BASE_BALL_SPEED * 1.8)


func _serve_ball() -> void:
	_balls.clear()
	for i in _ball_count():
		var ang := deg_to_rad(randf_range(-60.0, -120.0))
		_balls.append({
			"pos": Vector2(size.x / 2.0 + (i * 60.0 - 30.0), size.y - 170.0),
			"vel": Vector2(cos(ang), sin(ang)) * _ball_speed(),
		})
	_respawn_timer = 0.0


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	# Paddle: keyboard, or mouse motion (whichever moved last wins).
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		_paddle_x = clampf(_paddle_x + dir * 560.0 * delta,
			_pw / 2.0 + 16.0, size.x - _pw / 2.0 - 16.0)
	else:
		var mx := get_local_mouse_position().x
		if mx > 0.0 and mx < size.x:
			_paddle_x = clampf(mx, _pw / 2.0 + 16.0, size.x - _pw / 2.0 - 16.0)
	# Balls.
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_serve_ball()
	else:
		for ball in _balls.duplicate():
			ball["pos"] = (ball["pos"] as Vector2) + (ball["vel"] as Vector2) * delta * _speed
			if _bounce_walls(ball):
				continue  # missed the paddle: ball is gone
			_bounce_paddle(ball)
			_hit_boxes(ball)
	queue_redraw()


## Returns true if the ball missed the paddle (caller skips it).
func _bounce_walls(ball: Dictionary) -> bool:
	var pos: Vector2 = ball["pos"]
	var vel: Vector2 = ball["vel"]
	if pos.x < 16.0 + BALL_R:
		pos.x = 16.0 + BALL_R
		vel.x = absf(vel.x)
	elif pos.x > size.x - 16.0 - BALL_R:
		pos.x = size.x - 16.0 - BALL_R
		vel.x = -absf(vel.x)
	if pos.y < 84.0 + BALL_R:
		pos.y = 84.0 + BALL_R
		vel.y = absf(vel.y)
	if pos.y > size.y + 40.0:
		# Missed the paddle: lose a ball (a life).
		_balls.erase(ball)
		_lives -= 1
		if _lives <= 0:
			_end(false)
		elif _balls.is_empty():
			_respawn_timer = 0.8
		return true
	ball["pos"] = pos
	ball["vel"] = vel
	return false


func _bounce_paddle(ball: Dictionary) -> void:
	var pos: Vector2 = ball["pos"]
	var vel: Vector2 = ball["vel"]
	var py := size.y - 70.0
	if vel.y > 0.0 and absf(pos.y - py) <= BALL_R + 6.0 \
			and absf(pos.x - _paddle_x) <= _pw / 2.0:
		pos.y = py - BALL_R - 6.0
		var offset := clampf((pos.x - _paddle_x) / (_pw / 2.0), -1.0, 1.0)
		var ang := deg_to_rad(-90.0 + offset * 55.0)
		vel = Vector2(cos(ang), sin(ang)) * _ball_speed()
	ball["pos"] = pos
	ball["vel"] = vel


func _hit_boxes(ball: Dictionary) -> void:
	var pos: Vector2 = ball["pos"]
	var vel: Vector2 = ball["vel"]
	for r in BOX_ROWS:
		for c in BOX_COLS:
			if not bool(_boxes[r][c]):
				continue
			var rect := Rect2(_top + Vector2(c * BOX_SIZE.x, r * BOX_SIZE.y), BOX_SIZE)
			if rect.grow(2.0).has_point(pos):
				_break_box(r, c)
				vel.y = -vel.y
				ball["vel"] = vel
				return


func _break_box(r: int, c: int) -> void:
	_boxes[r][c] = false
	_boxes_left -= 1
	_boxes_broken += 1
	if _boxes_left <= 0:
		_end(true)


# --- Test hooks ----------------------------------------------------------
func test_break_all() -> void:
	for r in BOX_ROWS:
		for c in BOX_COLS:
			if bool(_boxes[r][c]):
				_break_box(r, c)


func test_miss_ball() -> void:
	_lives -= 1
	if _lives <= 0:
		_end(false)
	else:
		_respawn_timer = 0.01


func test_timeout() -> void:
	_end(false)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# Amazon boxes: cardboard with a tape stripe.
	for r in BOX_ROWS:
		for c in BOX_COLS:
			var p := _top + Vector2(c * BOX_SIZE.x, r * BOX_SIZE.y)
			var inset := Rect2(p + Vector2(2, 2), BOX_SIZE - Vector2(4, 4))
			if bool(_boxes[r][c]):
				draw_rect(inset, _box_cols[r][c])
				draw_rect(Rect2(p + Vector2(BOX_SIZE.x / 2.0 - 3, 4), Vector2(6, BOX_SIZE.y - 8)),
					Color(0.88, 0.82, 0.70))  # packing tape
				draw_rect(inset, Color(0.35, 0.24, 0.12), false, 2.0)
			else:
				draw_rect(inset, Color(0.16, 0.18, 0.24))
	# Tape-gun paddle: flattened box.
	var py := size.y - 70.0
	draw_rect(Rect2(_paddle_x - _pw / 2.0, py - 7, _pw, 14), Color(0.72, 0.53, 0.30))
	draw_rect(Rect2(_paddle_x - _pw / 2.0, py - 7, _pw, 14), Color(0.35, 0.24, 0.12), false, 2.0)
	draw_rect(Rect2(_paddle_x - 10, py - 26, 20, 20), Color(0.55, 0.55, 0.58))  # tape gun
	# Balls.
	if _respawn_timer <= 0.0:
		for ball in _balls:
			var bpos: Vector2 = ball["pos"]
			draw_circle(bpos, BALL_R, Color(0.95, 0.85, 0.4))
			draw_arc(bpos, BALL_R, 0, TAU, 16, Color(0.6, 0.5, 0.2), 2.0)
	var balls := ""
	for i in MAX_LIVES:
		balls += "● " if i < _lives else "○ "
	draw_string(font, Vector2(24, 120),
		"Boxes left: %d   Balls: %s  Time: %ds" % [_boxes_left, balls, int(_time_left)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
