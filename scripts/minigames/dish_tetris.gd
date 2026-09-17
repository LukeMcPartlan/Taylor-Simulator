class_name DishTetris
extends Minigame
## Dishes station — "Dish Tetris". A tiny falling-block game: fit dishes into
## the drying rack. Clear 3 rows to win. Lose if the stack reaches the top
## or the 75-second timer runs out.
##
## Controls: A/D or Left/Right = move, S/Down = soft drop, Z = rotate.

const COLS: int = 8
const ROWS: int = 10
const CELL: float = 30.0
const WIN_ROWS: int = 3
const TIME_LIMIT: float = 75.0
# Two WarioWare-simple pieces: domino and square, as cell offsets.
const PIECES: Array = [
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
]

var _grid: Array = []          # ROWS x COLS of bool
var _piece: Array = []         # current piece cell offsets
var _px: int = 3               # piece origin (grid coords)
var _py: int = 0
var _fall_timer: float = 0.0
var _fall_interval: float = 0.7
var _rows_cleared: int = 0
var _time_left: float = TIME_LIMIT
var _origin := Vector2.ZERO    # top-left of the grid in local coords


func start() -> void:
	super.start()
	title_text = "Dish Tetris"
	help_text = "A/D move - S drops faster - Z rotates. Clear %d rows!" % WIN_ROWS
	_grid.clear()
	for _r in ROWS:
		var row: Array = []
		for _c in COLS:
			row.append(false)
		_grid.append(row)
	_origin = Vector2((size.x - COLS * CELL) / 2.0, 96.0)
	_spawn_piece()


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	# Held movement with a small repeat delay feels right for tetris-likes.
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		_try_move(-1, 0)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		_try_move(1, 0)
	_fall_timer += delta
	var interval: float = _fall_interval
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		interval = 0.06
	if _fall_timer >= interval / _speed:
		_fall_timer = 0.0
		if not _try_move(0, 1):
			_lock_piece()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_Z:
		_try_rotate()


func _spawn_piece() -> void:
	_piece = (PIECES[randi() % PIECES.size()] as Array).duplicate()
	_px = 3
	_py = 0
	if _collides(_piece, _px, _py):
		_end(false)  # topped out


func _cells() -> Array:
	var out: Array = []
	for off in _piece:
		out.append(Vector2i(_px, _py) + off)
	return out


func _collides(piece: Array, ox: int, oy: int) -> bool:
	for off in piece:
		var cx: int = ox + off.x
		var cy: int = oy + off.y
		if cx < 0 or cx >= COLS or cy >= ROWS:
			return true
		if cy >= 0 and bool(_grid[cy][cx]):
			return true
	return false


func _try_move(dx: int, dy: int) -> bool:
	if not _collides(_piece, _px + dx, _py + dy):
		_px += dx
		_py += dy
		return true
	return false


func _try_rotate() -> void:
	# 90-degree rotation of the offsets around the piece origin.
	var rotated: Array = []
	for off in _piece:
		rotated.append(Vector2i(-off.y, off.x))
	if not _collides(rotated, _px, _py):
		_piece = rotated


func _lock_piece() -> void:
	for cell in _cells():
		if cell.y >= 0:
			_grid[cell.y][cell.x] = true
	_check_rows()
	if not _over:
		_spawn_piece()


func _check_rows() -> void:
	var cleared: int = 0
	var r: int = ROWS - 1
	while r >= 0:
		var full: bool = true
		for c in COLS:
			if not bool(_grid[r][c]):
				full = false
				break
		if full:
			cleared += 1
			_grid.remove_at(r)
			var fresh: Array = []
			for _c in COLS:
				fresh.append(false)
			_grid.push_front(fresh)
			# Don't advance r: the shifted-down row needs re-checking.
		else:
			r -= 1
	if cleared > 0:
		_rows_cleared += cleared
		if _rows_cleared >= WIN_ROWS:
			_end(true)


# --- Test hooks: drive the real win/lose paths without playing ---------
func test_add_cleared_row() -> void:
	_rows_cleared += 1
	if _rows_cleared >= WIN_ROWS:
		_end(true)


func test_top_out() -> void:
	_end(false)


func _draw_game() -> void:
	var ox := _origin.x
	var oy := _origin.y
	# Rack frame.
	draw_rect(Rect2(ox - 6, oy - 6, COLS * CELL + 12, ROWS * CELL + 12),
		Color(0.3, 0.22, 0.15))
	for r in ROWS:
		for c in COLS:
			var p := Vector2(ox + c * CELL, oy + r * CELL)
			var col := Color(0.16, 0.17, 0.22) if not bool(_grid[r][c]) else Color(0.55, 0.75, 0.95)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), col)
	# Falling piece.
	for cell in _cells():
		if cell.y >= 0:
			var p := Vector2(ox + cell.x * CELL, oy + cell.y * CELL)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)),
				Color(0.95, 0.85, 0.6))
	# HUD bits.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(ox, oy + ROWS * CELL + 28),
		"Rows: %d/%d   Time: %ds" % [_rows_cleared, WIN_ROWS, int(_time_left)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
