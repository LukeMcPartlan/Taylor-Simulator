class_name PhoneSwipe
extends Minigame
## Phone station (fun) — "TikTok Swipe". Symbols scroll by on the phone; mash
## ANY button and the symbol vanishes the instant you press it, a fresh one
## popping up in its place. 10 swipes completes the scroll session.
##
## Controls: any key or mouse button.

const WIN_HITS: int = 10
const PROMPT_INTERVAL: float = 1.1  # seconds a symbol scrolls before it refreshes

const ARROWS: Array = [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]
const ARROW_GLYPHS: Dictionary = {
	KEY_LEFT: "<", KEY_UP: "^", KEY_RIGHT: ">", KEY_DOWN: "v",
}

var _hits: int = 0
var _prompt: int = KEY_LEFT
var _prompt_age: float = 0.0


func start() -> void:
	super.start()
	title_text = "TikTok Swipe"
	help_text = "Mash ANY button to swipe! %d swipes wins." % WIN_HITS
	_hits = 0
	_new_prompt()


func _new_prompt() -> void:
	_prompt = int(ARROWS[randi() % ARROWS.size()])
	_prompt_age = 0.0


func _process(delta: float) -> void:
	if _over:
		return
	_prompt_age += delta
	if _prompt_age >= PROMPT_INTERVAL * 2.2:
		# Symbol scrolled off unswiped — just refresh it, no penalty.
		_new_prompt()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		_swipe()
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.pressed:
			_swipe()


## Any button press swipes the current symbol away and shows a new one.
func _swipe() -> void:
	_hits += 1
	if _hits >= WIN_HITS:
		_end(true)
		return
	_new_prompt()


# --- Test hooks ----------------------------------------------------------
func test_hit() -> void:
	_swipe()


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	var cx := size.x / 2.0
	# The phone frame.
	var phone := Rect2(cx - 130, 110, 260, 400)
	draw_rect(phone.grow(8), Color(0.15, 0.15, 0.18))
	draw_rect(phone, Color(0.1, 0.12, 0.16))
	# Prompt symbol scrolling down; any button press swipes it away.
	var travel := clampf(_prompt_age / (PROMPT_INTERVAL * 2.2), 0.0, 1.0)
	var py := lerpf(160.0, 420.0, travel)
	var glyph: String = String(ARROW_GLYPHS[_prompt])
	draw_string(font, Vector2(cx - 40, py), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, 80, 64, Color(0.4, 1.0, 0.5))
	# Hit line.
	draw_line(Vector2(phone.position.x + 16, 420), Vector2(phone.position.x + 244, 420),
		Color(1.0, 0.85, 0.3), 3.0)
	draw_string(font, Vector2(24, 120),
		"Swipes: %d/%d   (mash any button!)" % [_hits, WIN_HITS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
