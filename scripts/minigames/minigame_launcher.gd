extends CanvasLayer
## MinigameLauncher — autoload singleton that opens a station minigame as a
## modal overlay and pauses the world while it runs.
##
## Flow: Station calls `MinigameLauncher.open("dishes", _on_minigame_done)`.
## The launcher freezes the tree (so the day clock and neglect pressure stop),
## builds a dimmed overlay + centered panel, instantiates the minigame by id,
## and on `finished(success)` tears everything down, unpauses, and calls the
## station back with the result.
##
## The GAME_NAMES / GAME_SCRIPTS tables are the single registry: adding a new
## minigame = one new script + one line here + a "game" id on the station.

# Station-facing ids -> minigame script paths. load() is used (instead of
# class_name references) so this autoload compiles even when the global
# class cache hasn't seen the minigame scripts yet.
const GAME_SCRIPTS: Dictionary = {
	"dishes": "res://scripts/minigames/dish_tetris.gd",
	"microwave": "res://scripts/minigames/microwave_wipe.gd",
	"laundry": "res://scripts/minigames/laundry_hoops.gd",
	"mop": "res://scripts/minigames/mop_pong.gd",
	"toilet": "res://scripts/minigames/toilet_whack.gd",
	"trash": "res://scripts/minigames/trash_sort.gd",
	"feed_baby": "res://scripts/minigames/baby_spoon.gd",
	"change_baby": "res://scripts/minigames/diaper_catch.gd",
	"book": "res://scripts/minigames/book_focus.gd",
	"phone": "res://scripts/minigames/phone_swipe.gd",
	"amazon_break": "res://scripts/minigames/amazon_break.gd",
}
# Friendly names shown in station prompts ("Press E — Dish Tetris").
const GAME_NAMES: Dictionary = {
	"dishes": "Dish Tetris",
	"microwave": "Microwave Wipe",
	"laundry": "Laundry Hoops",
	"mop": "Mop Pong",
	"toilet": "Whack-a-Leak",
	"trash": "Trash Sort",
	"feed_baby": "Spoon Timing",
	"change_baby": "Diaper Catch",
	"book": "Reading Focus",
	"phone": "FakeTok",
	"amazon_break": "Box Breaker",
}

var _dim: ColorRect = null
var _game: Minigame = null
var _callback: Callable = Callable()
var _open_msec: int = 0


func _ready() -> void:
	# Above the HUD (default layer 1) and always processing so input works
	# while the tree is paused.
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _game != null


func display_name(game_id: String) -> String:
	return String(GAME_NAMES.get(game_id, game_id))


func open(game_id: String, on_done: Callable) -> void:
	## Opens the minigame overlay. No-ops if one is already open or the id is
	## unknown — stations can't double-open or crash on a bad id.
	if _game != null or not GAME_SCRIPTS.has(game_id):
		return
	_callback = on_done
	_open_msec = Time.get_ticks_msec()
	get_tree().paused = true
	# The day clock keeps ticking inside minigames: GameState (and the mode
	# hooks under it) run on PROCESS_MODE_ALWAYS so time, task procs, and
	# neglect pressure all advance while the world itself stays frozen.
	GameState.process_mode = Node.PROCESS_MODE_ALWAYS

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	# STOP so clicks don't fall through to anything under the overlay.
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 560)
	center.add_child(panel)

	_game = (load(String(GAME_SCRIPTS[game_id])) as GDScript).new() as Minigame
	_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_game)
	_game.finished.connect(_on_game_finished)
	# Every minigame snapshots `size` in start() to place its playfield, but
	# size is (0,0) until the container layout runs. Freeze the game and
	# start it deferred once the layout assigns a real size, so all
	# playfields land on the real 700x560 panel instead of at the origin.
	_game.set_process(false)
	_game.set_process_input(false)
	_game.set_process_unhandled_input(false)
	_deferred_start()


func _deferred_start() -> void:
	# Every minigame snapshots `size` in start() to place its playfield, but
	# size is (0,0) until the container layout runs (CenterContainer >
	# PanelContainer nesting can need more than one frame to settle on some
	# frames). Wait for real layout instead of a blind one-frame delay, so a
	# slow sort can never leave playfields stranded at the origin.
	var frames := 0
	while _game != null and (_game.size.x <= 0.0 or _game.size.y <= 0.0) and frames < 60:
		await get_tree().process_frame
		frames += 1
	if _game == null:
		return
	if frames > 1:
		push_warning("MinigameLauncher: playfield layout took %d frames" % frames)
	_game.start()
	_game._ready_to_draw = true
	_game.set_process(true)
	_game.set_process_input(true)
	_game.set_process_unhandled_input(true)
	_game.queue_redraw()


func _on_game_finished(success: bool) -> void:
	var cb := _callback
	_callback = Callable()
	if _game != null:
		_game.queue_free()
		_game = null
	if _dim != null:
		_dim.queue_free()
		_dim = null
	get_tree().paused = false
	GameState.process_mode = Node.PROCESS_MODE_INHERIT
	if cb.is_valid():
		# elapsed: real seconds the player spent in the minigame — variants
		# like combo-mom use it for clear-time bonuses.
		var elapsed := float(Time.get_ticks_msec() - _open_msec) / 1000.0
		cb.call(success, elapsed)
