class_name PhoneSwipe
extends Minigame
## Phone station (fun) — "TikTok Swipe". An arrow prompt scrolls toward the
## hit line; press the matching arrow key in time. 10 hits completes the
## scroll session. 3 misses and the algorithm shows you something awful.
##
## Controls: arrow keys matching the prompt.

const WIN_HITS: int = 10
const MAX_MISSES: int = 3
const PROMPT_INTERVAL: float = 1.1  # seconds per prompt (divided by _speed)
const HIT_WINDOW: float = 0.55     # seconds the prompt is hittable

const ARROWS: Array = [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]
const ARROW_GLYPHS: Dictionary = {
	KEY_LEFT: "<", KEY_UP: "^", KEY_RIGHT: ">", KEY_DOWN: "v",
}

var _hits: int = 0
var _misses: int = 0
var _prompt: int = KEY_LEFT
var _prompt_age: float = 0.0
var _gap_timer: float = 0.0


func start() -> void:
	super.start()
	title_text = "TikTok Swipe"
	help_text = "Hit the matching ARROW KEY in time! %d hits wins." % WIN_HITS
	_hits = 0
	_misses = 0
	_new_prompt()
	_gap_timer = 0.0


func _new_prompt() -> void:
	_prompt = int(ARROWS[randi() % ARROWS.size()])
	_prompt_age = 0.0
	_gap_timer = PROMPT_INTERVAL / _speed


func _process(delta: float) -> void:
	if _over:
		return
	_prompt_age += delta
	if _prompt_age >= HIT_WINDOW * 2.2:
		# Let it expire unhit — that's a miss.
		_register_miss()
		if _over:
			return
		_new_prompt()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode in ARROWS:
		_try_hit(int(k.keycode))


func _try_hit(keycode: int) -> void:
	if _prompt_age > HIT_WINDOW:
		return  # too late for this prompt — it'll expire as a miss
	if keycode == _prompt:
		_hits += 1
		if _hits >= WIN_HITS:
			_end(true)
			return
		_new_prompt()
	else:
		_register_miss()
		if not _over:
			_new_prompt()


func _register_miss() -> void:
	_misses += 1
	if _misses >= MAX_MISSES:
		_end(false)


# --- Test hooks ----------------------------------------------------------
func test_hit() -> void:
	_prompt_age = 0.0
	_try_hit(_prompt)


func test_miss() -> void:
	_prompt_age = 0.0
	var wrong := KEY_LEFT
	for a in ARROWS:
		if int(a) != _prompt:
			wrong = int(a)
			break
	_try_hit(wrong)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	var cx := size.x / 2.0
	# The phone frame.
	var phone := Rect2(cx - 130, 110, 260, 400)
	draw_rect(phone.grow(8), Color(0.15, 0.15, 0.18))
	draw_rect(phone, Color(0.1, 0.12, 0.16))
	# Prompt arrow scrolling toward the hit line, shrinking the window.
	var travel := clampf(_prompt_age / (HIT_WINDOW * 2.2), 0.0, 1.0)
	var py := lerpf(160.0, 420.0, travel)
	var glyph: String = String(ARROW_GLYPHS[_prompt])
	var in_window := _prompt_age <= HIT_WINDOW
	var col := Color(0.4, 1.0, 0.5) if in_window else Color(0.6, 0.6, 0.65)
	draw_string(font, Vector2(cx - 40, py), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, 80, 64, col)
	# Hit line.
	draw_line(Vector2(phone.position.x + 16, 420), Vector2(phone.position.x + 244, 420),
		Color(1.0, 0.85, 0.3), 3.0)
	draw_string(font, Vector2(24, 120),
		"Hits: %d/%d   Misses: %d/%d" % [_hits, WIN_HITS, _misses, MAX_MISSES],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
