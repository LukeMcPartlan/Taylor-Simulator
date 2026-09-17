class_name Minigame
extends Control
## Base class for every WarioWare-style station minigame.
##
## Contract (kept tiny on purpose):
## - Launcher calls `start()` once after adding the minigame to the tree.
## - The minigame calls `_end(true)` on win, `_end(false)` on lose/timeout.
## - Launcher listens for `finished(success)` and resumes the world.
##
## Godot conventions:
## - `process_mode = PROCESS_MODE_ALWAYS`: the launcher pauses the whole tree
##   (get_tree().paused = true) while a minigame is open, which would freeze a
##   normal node. ALWAYS nodes keep receiving _process/_input/_draw anyway.
## - `queue_redraw()` + `_draw()`: Godot's immediate-mode 2D drawing. We draw
##   every frame from state — no sprites needed for these simple games.
## - `ThemeDB.fallback_font`: the built-in font, always available even with no
##   theme set — perfect for programmer-art minigames.

signal finished(success: bool)

# Set by the subclass in start().
var title_text: String = "Minigame"
var help_text: String = ""

# Difficulty relief: night-shift buffs (Espresso Machine, Panic Clean) return
# > 1.0 here; base game always returns 1.0. Higher = more forgiving timers.
var _speed: float = 1.0
var _over: bool = false
var _result_text: String = ""
var _result_color: Color = Color.WHITE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func start() -> void:
	## Called by the launcher. Subclasses override to init state, but MUST
	## call super.start() so _speed gets picked up.
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("get_minigame_speed_mult"):
		_speed = float(gs.call("get_minigame_speed_mult"))
	_speed = maxf(_speed, 0.1)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Chrome: title + instructions, drawn by the base class so every game
	# looks consistent. The play area lives below y = 72.
	draw_string(font, Vector2(20, 38), title_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1))
	draw_string(font, Vector2(20, 64), help_text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 16, Color(0.75, 0.78, 0.85))
	draw_line(Vector2(16, 76), Vector2(size.x - 16, 76), Color(0.35, 0.35, 0.45), 2.0)
	_draw_game()
	if _over:
		# Dim the board behind the result banner.
		draw_rect(Rect2(0, 76, size.x, size.y - 76), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(0, size.y * 0.55), _result_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, _result_color)


func _draw_game() -> void:
	## Subclasses draw their playfield here. Base draws nothing.
	pass


func _end(success: bool) -> void:
	## Call exactly once when the game is decided. Shows a banner, waits a
	## beat (SceneTreeTimer ignores tree pause by default), then tells the
	## launcher. Guarded so double-calls are harmless.
	if _over:
		return
	_over = true
	_result_text = "DONE!" if success else "FAILED!"
	_result_color = Color(0.45, 1.0, 0.55) if success else Color(1.0, 0.45, 0.45)
	queue_redraw()
	await get_tree().create_timer(1.2).timeout
	finished.emit(success)
