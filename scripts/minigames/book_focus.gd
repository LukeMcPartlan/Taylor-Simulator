class_name BookFocus
extends Minigame
## Book station (fun) — "Reading Focus". Hold SPACE to sink into the book
## and fill the page meter. But holding builds restlessness — release to
## cool down before it maxes out, or the page meter halves. Fill it to win.
##
## Controls: hold SPACE to read, release to rest.

const FILL_RATE: float = 22.0    # page % per second while holding
const RESTLESS_RATE: float = 30.0
const COOL_RATE: float = 45.0
const TIME_LIMIT: float = 60.0

var _page: float = 0.0
var _restless: float = 0.0
var _time_left: float = TIME_LIMIT
# Test seam: when true, simulates holding SPACE (headless tests can't inject
# real key state reliably). Never set by gameplay code.
var _force_hold: bool = false


func start() -> void:
	super.start()
	title_text = "Reading Focus"
	help_text = "Hold SPACE to read. Release before restlessness maxes out!"
	_page = 0.0
	_restless = 0.0
	_time_left = TIME_LIMIT


func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(false)
		return
	if Input.is_key_pressed(KEY_SPACE) or _force_hold:
		_page += FILL_RATE * delta
		_restless += RESTLESS_RATE * delta / _speed
	else:
		_restless = maxf(0.0, _restless - COOL_RATE * delta)
	if _restless >= 100.0:
		# Overheated: lose half your progress, cool off, keep reading.
		_page *= 0.5
		_restless = 40.0
	if _page >= 100.0:
		_end(true)
		return
	queue_redraw()


# --- Test hooks ----------------------------------------------------------
func test_overheat() -> void:
	_restless = 99.0
	_page = 60.0


func test_timeout() -> void:
	_end(false)


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	var bx := 60.0
	var bw := size.x - 120.0
	# Page meter.
	draw_string(font, Vector2(bx, 170), "PAGE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.9))
	draw_rect(Rect2(bx, 180, bw * clampf(_page, 0.0, 100.0) / 100.0, 34), Color(0.5, 0.7, 1.0))
	draw_rect(Rect2(bx, 180, bw, 34), Color(0.8, 0.8, 0.85), false, 2.0)
	# Restlessness meter.
	draw_string(font, Vector2(bx, 260), "RESTLESSNESS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.8, 0.8))
	var rcol := Color(1.0, 0.5, 0.3) if _restless > 75.0 else Color(0.9, 0.7, 0.35)
	draw_rect(Rect2(bx, 270, bw * clampf(_restless, 0.0, 100.0) / 100.0, 34), rcol)
	draw_rect(Rect2(bx, 270, bw, 34), Color(0.8, 0.8, 0.85), false, 2.0)
	# The book: pages fill with text lines as you read.
	var book := Rect2(size.x / 2.0 - 110, 330, 220, 150)
	draw_rect(book, Color(0.55, 0.35, 0.2))
	draw_rect(Rect2(book.position + Vector2(8, 8), book.size - Vector2(16, 16)), Color(0.95, 0.93, 0.85))
	var lines := int(8.0 * clampf(_page, 0.0, 100.0) / 100.0)
	for i in lines:
		var ly := book.position.y + 22.0 + i * 16.0
		draw_line(Vector2(book.position.x + 22, ly), Vector2(book.position.x + 198, ly),
			Color(0.4, 0.4, 0.45), 3.0)
	draw_string(font, Vector2(24, 120),
		"Time: %ds" % int(_time_left),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
