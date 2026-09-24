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
# Set by the launcher right after start() runs (start is deferred one frame
# so the container layout has assigned a real size). Guards _draw_game():
# drawing before start() would read uninitialized state (empty grids, etc.).
var _ready_to_draw: bool = false
var _over: bool = false
var _result_text: String = ""
var _result_color: Color = Color.WHITE


func _exit_rect() -> Rect2:
	## Top-right "bail out" button, in local coords.
	return Rect2(Vector2(size.x - 140.0, 10.0), Vector2(124.0, 38.0))


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
	if _ready_to_draw:
		_draw_game()
	_draw_exit_button(font)
	if _over:
		# Dim the board behind the result banner.
		draw_rect(Rect2(0, 76, size.x, size.y - 76), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(0, size.y * 0.55), _result_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, _result_color)


func _draw_game() -> void:
	## Subclasses draw their playfield here. Base draws nothing.
	pass


func _draw_exit_button(font: Font) -> void:
	## The bail-out button. Drawn by the base class so it's on every game;
	## hidden once the game is decided (the result banner takes over).
	if _over:
		return
	var r := _exit_rect()
	draw_rect(r, Color(0.62, 0.2, 0.2, 0.92))
	draw_rect(r, Color(1, 1, 1, 0.9), false, 2.0)
	draw_string(font, Vector2(r.position.x, r.get_center().y + 6.0), "EXIT (Esc)",
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(1, 1, 1))


func _input(event: InputEvent) -> void:
	## Base-class input: the exit button. Subclasses use _unhandled_input /
	## _process polling for their own controls, so this never collides.
	if _over:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			quit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse() \
				* mb.position
			if _exit_rect().has_point(local):
				quit()
				get_viewport().set_input_as_handled()


func quit() -> void:
	## Player bailed via the exit button: counts as a fail — no reward, the
	## chore stays open and can re-proc later. Closes instantly, no banner.
	if _over:
		return
	_over = true
	finished.emit(false)


func _end(success: bool) -> void:
	## Call exactly once when the game is decided. Wins close immediately
	## (the world pops the "✓ DONE" text over the player); losses show the
	## banner, wait a beat, then close.
	_finish(success, "DONE!" if success else "FAILED!")


func _finish(success: bool, banner: String) -> void:
	if _over:
		return
	_over = true
	if success:
		# Win: no in-game banner, no wait — close at once. The station
		# shows the "✓ DONE" popup over the player instead.
		finished.emit(success)
		return
	_result_text = banner
	_result_color = Color(1.0, 0.45, 0.45)
	queue_redraw()
	await get_tree().create_timer(1.2).timeout
	finished.emit(success)
