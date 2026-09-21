class_name MopPong
extends Minigame
## Mop station — "Mop Pong". Breakout with a mop: bounce the dirt ball off
## your paddle to scrub every dirt tile. Clear all 12 to win. If the ball
## slips past, it just respawns — no lives, WarioWare is kind. 90s timer.
##
## Controls: A/D or Left/Right to slide the mop.

const TILE_COLS: int = 6
const TILE_ROWS: int = 2
const TILE_SIZE := Vector2(90, 34)
const PADDLE_W: float = 110.0
const BALL_R: float = 10.0
const BALL_SPEED: float = 380.0
const TIME_LIMIT: float = 90.0
const TEX_BALL := preload("res://placeholder art/Sprites/ball.png")
const TEX_DIRT := preload("res://placeholder art/Sprites/dirt_spot.png")

var _tiles: Array = []  # TILE_ROWS x TILE_COLS of bool (true = dirty)
var _tiles_left: int = 0
var _paddle_x: float = 0.0
var _ball_pos := Vector2.ZERO
var _ball_vel := Vector2.ZERO
var _respawn_timer: float = 0.0
var _time_left: float = TIME_LIMIT
var _top := Vector2.ZERO


func start() -> void:
	super.start()
	title_text = "Mop Pong"
	help_text = "Slide the mop (A/D). Scrub every dirt tile!"
	_tiles.clear()
	_tiles_left = 0
	for _r in TILE_ROWS:
		var row: Array = []
		for _c in TILE_COLS:
			row.append(true)
			_tiles_left += 1
		_tiles.append(row)
	_top = Vector2((size.x - TILE_COLS * TILE_SIZE.x) / 2.0, 100.0)
	_paddle_x = size.x / 2.0
	_serve_ball()


func _serve_ball() -> void:
	_ball_pos = Vector2(size.x / 2.0, size.y - 160.0)
	var ang := deg_to_rad(randf_range(-60.0, -120.0))
	_ball_vel = Vector2(cos(ang), sin(ang)) * BALL_SPEED
	_respawn_timer = 0.0


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	# Paddle.
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	_paddle_x = clampf(_paddle_x + dir * 520.0 * delta, PADDLE_W / 2.0 + 16.0, size.x - PADDLE_W / 2.0 - 16.0)
	# Ball.
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_serve_ball()
	else:
		_ball_pos += _ball_vel * delta * _speed
		_bounce_walls()
		_bounce_paddle()
		_hit_tiles()
	queue_redraw()


func _bounce_walls() -> void:
	if _ball_pos.x < 16.0 + BALL_R:
		_ball_pos.x = 16.0 + BALL_R
		_ball_vel.x = absf(_ball_vel.x)
	elif _ball_pos.x > size.x - 16.0 - BALL_R:
		_ball_pos.x = size.x - 16.0 - BALL_R
		_ball_vel.x = -absf(_ball_vel.x)
	if _ball_pos.y < 84.0 + BALL_R:
		_ball_pos.y = 84.0 + BALL_R
		_ball_vel.y = absf(_ball_vel.y)
	if _ball_pos.y > size.y + 40.0:
		_respawn_timer = 0.8  # slipped past the mop — new ball, no penalty


func _bounce_paddle() -> void:
	var py := size.y - 70.0
	if _ball_vel.y > 0.0 and absf(_ball_pos.y - py) <= BALL_R + 6.0 \
			and absf(_ball_pos.x - _paddle_x) <= PADDLE_W / 2.0:
		_ball_pos.y = py - BALL_R - 6.0
		var offset := clampf((_ball_pos.x - _paddle_x) / (PADDLE_W / 2.0), -1.0, 1.0)
		var ang := deg_to_rad(-90.0 + offset * 55.0)
		_ball_vel = Vector2(cos(ang), sin(ang)) * BALL_SPEED


func _hit_tiles() -> void:
	for r in TILE_ROWS:
		for c in TILE_COLS:
			if not bool(_tiles[r][c]):
				continue
			var rect := Rect2(_top + Vector2(c * TILE_SIZE.x, r * TILE_SIZE.y), TILE_SIZE)
			if rect.grow(2.0).has_point(_ball_pos):
				_clean_tile(r, c)
				_ball_vel.y = -_ball_vel.y
				return


func _clean_tile(r: int, c: int) -> void:
	_tiles[r][c] = false
	_tiles_left -= 1
	if _tiles_left <= 0:
		_end(true)


# --- Test hooks ----------------------------------------------------------
func test_clean_all() -> void:
	for r in TILE_ROWS:
		for c in TILE_COLS:
			if bool(_tiles[r][c]):
				_clean_tile(r, c)


func test_timeout() -> void:
	_end(false)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# Dirt tiles.
	for r in TILE_ROWS:
		for c in TILE_COLS:
			var p := _top + Vector2(c * TILE_SIZE.x, r * TILE_SIZE.y)
			var tile_rect := Rect2(p + Vector2(2, 2), TILE_SIZE - Vector2(4, 4))
			if bool(_tiles[r][c]):
				draw_texture_rect(TEX_DIRT, tile_rect, false)
			else:
				draw_rect(tile_rect, Color(0.2, 0.24, 0.3))
	# Mop paddle.
	var py := size.y - 70.0
	draw_rect(Rect2(_paddle_x - PADDLE_W / 2.0, py - 6, PADDLE_W, 12), Color(0.75, 0.6, 0.35))
	draw_rect(Rect2(_paddle_x - 8, py - 34, 16, 30), Color(0.5, 0.35, 0.2))  # handle
	# Dirt ball.
	if _respawn_timer <= 0.0:
		draw_texture(TEX_BALL, _ball_pos - TEX_BALL.get_size() / 2.0)
	draw_string(font, Vector2(24, 120),
		"Tiles left: %d   Time: %ds" % [_tiles_left, int(_time_left)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
