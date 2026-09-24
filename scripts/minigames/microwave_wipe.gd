class_name MicrowaveWipe
extends Minigame
## Microwave station — "Microwave Wipe". A grime layer covers the microwave;
## drag the mouse to wipe it away. Win at 90%+ cleaned. 45-second timer.
##
## Controls: hold left mouse button and drag to wipe.

const GRID_W: int = 14
const GRID_H: int = 10
const BRUSH_RADIUS: float = 34.0
const WIN_FRACTION: float = 0.9
const TIME_LIMIT: float = 45.0
const TEX_DIRT := preload("res://placeholder art/Sprites/dirt_spot.png")
const TEX_SPONGE := preload("res://placeholder art/Sprites/sponge.png")
const TEX_INTERIOR := preload("res://art/furniture/microwaveInterior.png")

var _dirty: Array = []   # GRID_H x GRID_W of bool
var _dirty_count: int = 0
var _total: int = GRID_W * GRID_H
var _rect := Rect2()
var _brush_radius: float = BRUSH_RADIUS
var _time_left: float = TIME_LIMIT
var _was_down: bool = false


const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")

func _upgrade_tier(id: String) -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return 0
	return int(gs.call("upgrade_tier", id))


func start() -> void:
	super.start()
	# Crisp pixels for the stretched interior backdrop (and the dirt/sponge).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_text = "Microwave Wipe"
	var sponge_tier := _upgrade_tier("sponge")
	var sponge_note := ""
	if sponge_tier > 0:
		sponge_note = " %s equipped!" % String((_UPGRADE_DEFS.def("sponge")["tiers"] as Array)[sponge_tier - 1]["label"])
	help_text = "Drag with the mouse to wipe the grime. Clean %d%% to win!%s" % [
		int(WIN_FRACTION * 100.0), sponge_note]
	_brush_radius = BRUSH_RADIUS * _UPGRADE_DEFS.tier_fx("sponge", sponge_tier, "brush_mult", 1.0)
	_dirty.clear()
	_dirty_count = 0
	for _r in GRID_H:
		var row: Array = []
		for _c in GRID_W:
			# Sprinkle grime; leave a few cells clean so it's not uniform.
			var d := randf() < 0.82
			row.append(d)
			if d:
				_dirty_count += 1
		_dirty.append(row)
	_rect = Rect2(Vector2((size.x - 560) / 2.0, 100), Vector2(560, 400))


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if down:
		_wipe_at(get_local_mouse_position())
	_was_down = down
	queue_redraw()


func _wipe_at(pos: Vector2) -> void:
	var cell := Vector2(_rect.size.x / GRID_W, _rect.size.y / GRID_H)
	var changed := false
	for r in GRID_H:
		for c in GRID_W:
			if not bool(_dirty[r][c]):
				continue
			var center := _rect.position + Vector2((c + 0.5) * cell.x, (r + 0.5) * cell.y)
			if center.distance_to(pos) <= _brush_radius:
				_dirty[r][c] = false
				_dirty_count -= 1
				changed = true
	if changed and _clean_fraction() >= WIN_FRACTION:
		_end(true)


func _clean_fraction() -> float:
	return 1.0 - float(_dirty_count) / float(maxi(_total, 1))


# --- Test hooks ----------------------------------------------------------
func test_wipe_all() -> void:
	for r in GRID_H:
		for c in GRID_W:
			if bool(_dirty[r][c]):
				_dirty[r][c] = false
				_dirty_count -= 1
	if _clean_fraction() >= WIN_FRACTION:
		_end(true)


func test_timeout() -> void:
	_end(false)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# The microwave interior: Luke's interior sprite stretched over the play
	# field (nearest filter keeps the pixels crisp).
	draw_rect(_rect.grow(10), Color(0.25, 0.25, 0.3))
	draw_texture_rect(TEX_INTERIOR, _rect, false)
	# Grime layer: placeholder dirt splotches over the still-dirty cells.
	var cell := Vector2(_rect.size.x / GRID_W, _rect.size.y / GRID_H)
	for r in GRID_H:
		for c in GRID_W:
			if bool(_dirty[r][c]):
				var center := _rect.position + Vector2((c + 0.5) * cell.x, (r + 0.5) * cell.y)
				var radius := minf(cell.x, cell.y) * (0.42 + 0.08 * float((r * 7 + c * 13) % 5) / 4.0)
				var dsize := Vector2(radius * 2.0, radius * 2.0)
				draw_texture_rect(TEX_DIRT, Rect2(center - dsize / 2.0, dsize), false)
	# Progress + timer.
	var frac := _clean_fraction()
	draw_rect(Rect2(20, size.y - 46, (size.x - 40) * frac, 20), Color(0.45, 0.9, 0.5))
	draw_rect(Rect2(20, size.y - 46, size.x - 40, 20), Color(0.8, 0.8, 0.8), false, 2.0)
	draw_string(font, Vector2(20, size.y - 56),
		"Clean: %d%%   Time: %ds" % [int(frac * 100.0), int(_time_left)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
	# Sponge cursor.
	var mpos := get_local_mouse_position()
	draw_texture(TEX_SPONGE, mpos - TEX_SPONGE.get_size() / 2.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		draw_arc(mpos, _brush_radius, 0, TAU, 24,
			Color(1, 1, 1, 0.6), 2.0)
