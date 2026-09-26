class_name PhoneSwipe
extends Minigame
## Phone button minigame — "FakeTok". A fake TikTok app: a big arrow shows
## above the phone screen and you press the matching arrow key.
##
## - DOWN  = next TikTok (wraps around at the end; 3x more likely to appear)
## - UP    = previous TikTok (never offered while on the first one)
## - LEFT / RIGHT = open/close the comments
## - While comments are open, UP/DOWN scroll them instead of changing videos
##
## Endless: there is no win condition — swipe as long as you like and exit
## whenever (EXIT closes instantly). Correct swipes drip +1 dopamine and move
## to a new prompt; wrong arrows still perform their swipe but cost -1
## dopamine, and the prompt arrow stays put (blinking red) until you hit it.

const SWIPE_DOPAMINE: float = 1.0
const WRONG_SWIPE_DOPAMINE: float = -1.0
const DISPLAY_COUNT: int = 16
const DISPLAY_PATH: String = "res://placeholder art/phone/display_%02d.png"
const COMMENT_POOL_SIZE: int = 60
const COMMENTS_VISIBLE: int = 6
const NEGATIVE_ODDS: float = 1.0 / 50.0

const ARROW_GLYPHS: Dictionary = {
	KEY_LEFT: "<", KEY_UP: "^", KEY_RIGHT: ">", KEY_DOWN: "v",
}
# WASD mirrors the arrows (W=up, A=left, S=down, D=right).
const WASD_TO_ARROW: Dictionary = {
	KEY_W: KEY_UP, KEY_A: KEY_LEFT, KEY_S: KEY_DOWN, KEY_D: KEY_RIGHT,
}

const POSITIVE_TEXTS: Array = [
	"Yaaaaaas queen",
	"This is literally ME fr",
	"POV: you finally get it",
	"the algorithm knew I needed this",
	"watching this for the 47th time no regrets",
	"this healed something in me",
	"ok but why is this so real",
	"sending this to everyone I know",
	"the way I GASPED",
	"new personality just dropped",
	"this is my roman empire",
	"instant follow, no notes",
]
const NEGATIVE_TEXTS: Array = [
	"Uhhh, is this ironic? Seems like this would be really damaging to society at scale.",
]

const NAMES_POSITIVE: Array = [
	# Russian
	"anastasia_v", "dashenka", "katya_msk", "maria.spb", "olga_1999",
	"natasha.k", "irina_volga", "sveta_moon", "yulia_b", "ekaterinaaa",
	# Chinese
	"xiao.mei", "lili_88", "chen.wei", "meimei_sh", "jingjing",
	"yuki_chen", "fangfang", "lina.bj", "xiaoyu", "wang.annie",
	# American
	"ashley.xo", "brittany_2001", "madisonrae", "kayleigh",
	"jessica.lynn", "taylor_bae", "emilyyy", "sophia.m", "haileyj", "chloe.vibes",
]
const NAMES_NEGATIVE: Array = [
	"xX_sl4yer_Xx", "NoScopeNinja", "pwnmaster69", "fraglord",
	"teabaggintony", "camper_van", "gg_ez_clap", "headshot_harry",
	"respawn_rufus", "lagswitch_larry",
]

var _hits: int = 0
var _prompt: int = KEY_DOWN
var _display_index: int = 0
var _displays: Array = []
var _comments_open: bool = false
var _comments: Array = []
var _scroll: int = 0
var _flash: float = 0.0
var _gs = null  # /root/GameState, cached in start() for the dopamine drip


func start() -> void:
	super.start()
	_gs = get_node_or_null("/root/GameState")
	title_text = "FakeTok"
	help_text = "Press the arrow shown above the phone (arrows or WASD)!"
	_hits = 0
	_display_index = 0
	_comments_open = false
	_scroll = 0
	_displays.clear()
	for i in DISPLAY_COUNT:
		var tex: Texture2D = load(DISPLAY_PATH % (i + 1))
		_displays.append(tex)
	_pick_prompt()


## Weighted prompt: down shows up 3x as often as any other direction. Up is
## never offered on the first TikTok (there's nothing before it).
func _pick_prompt() -> void:
	var bag: Array = [KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_UP, KEY_LEFT, KEY_RIGHT]
	if _display_index == 0:
		bag = bag.filter(func(k: int) -> bool: return k != KEY_UP)
	_prompt = int(bag[randi() % bag.size()])


func _process(delta: float) -> void:
	if _over:
		return
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		var code := int(k.keycode)
		if WASD_TO_ARROW.has(code):
			code = int(WASD_TO_ARROW[code])
		if ARROW_GLYPHS.has(code):
			_press(code)


func _press(keycode: int) -> void:
	if _over:
		return
	if keycode == _prompt:
		_hits += 1
		if _gs != null:
			_gs.call("add_dopamine", SWIPE_DOPAMINE)
		_apply_action(keycode)
		_pick_prompt()
	else:
		# Wrong arrow: the input STILL happens (the swipe/scroll/toggle goes
		# through), it just costs -1 dopamine. The prompt arrow stays the
		# same and blinks red — no new prompt until you hit the right one.
		_flash = 0.3
		if _gs != null:
			_gs.call("add_dopamine", WRONG_SWIPE_DOPAMINE)
		_apply_action(keycode)


func _apply_action(keycode: int) -> void:
	match keycode:
		KEY_DOWN:
			if _comments_open:
				_scroll = mini(_scroll + 1, maxi(_comments.size() - COMMENTS_VISIBLE, 0))
			else:
				_display_index = (_display_index + 1) % DISPLAY_COUNT
		KEY_UP:
			if _comments_open:
				_scroll = maxi(_scroll - 1, 0)
			elif _display_index > 0:
				_display_index -= 1
		KEY_LEFT, KEY_RIGHT:
			_comments_open = not _comments_open
			if _comments_open:
				_comments = _gen_comments()
				_scroll = 0


func _gen_comments() -> Array:
	var out: Array = []
	for i in COMMENT_POOL_SIZE:
		if randf() < NEGATIVE_ODDS:
			out.append({
				"name": String(NAMES_NEGATIVE[randi() % NAMES_NEGATIVE.size()]),
				"text": String(NEGATIVE_TEXTS[randi() % NEGATIVE_TEXTS.size()]),
				"votes": -randi_range(1_000_000, 9_999_999),
				"neg": true,
			})
		else:
			out.append({
				"name": String(NAMES_POSITIVE[randi() % NAMES_POSITIVE.size()]),
				"text": String(POSITIVE_TEXTS[randi() % POSITIVE_TEXTS.size()]),
				"votes": randi_range(1_200, 98_700),
				"neg": false,
			})
	return out


static func format_votes(votes: int) -> String:
	if votes < 0:
		return "-" + format_votes(-votes)
	if votes >= 1_000_000:
		return "%.1fM" % (float(votes) / 1_000_000.0)
	if votes >= 1_000:
		return "%.1fK" % (float(votes) / 1_000.0)
	return str(votes)


func _wrap(font: Font, text: String, font_size: int, max_w: float) -> Array:
	var lines: Array = []
	var cur := ""
	for word in text.split(" "):
		var trial := (cur + " " + word).strip_edges()
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w or cur == "":
			cur = trial
		else:
			lines.append(cur)
			cur = word
	if cur != "":
		lines.append(cur)
	return lines


# --- Test hooks ----------------------------------------------------------
func get_prompt() -> int:
	return _prompt


func test_set_prompt(keycode: int) -> void:
	_prompt = keycode


func test_press(keycode: int) -> void:
	_press(keycode)


func test_pick_prompt() -> void:
	_pick_prompt()


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	var cx := size.x / 2.0
	# Big arrow above the phone screen.
	var glyph: String = String(ARROW_GLYPHS[_prompt])
	var arrow_col := Color(0.4, 1.0, 0.5)
	if _flash > 0.0:
		arrow_col = Color(1.0, 0.3, 0.3)
	draw_string(font, Vector2(cx - 60, 136), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 64, arrow_col)
	if _flash > 0.0:
		draw_rect(Rect2(cx - 66, 76, 132, 72), Color(1.0, 0.3, 0.3, 0.5), false, 4.0)
	# The phone frame (9:16, matching the display art).
	var phone := Rect2(cx - 110, 150, 220, 390)
	draw_rect(phone.grow(8), Color(0.15, 0.15, 0.18))
	var tex: Texture2D = _displays[_display_index] if _display_index < _displays.size() else null
	if tex != null:
		draw_texture_rect(tex, phone, false)
	else:
		draw_rect(phone, Color(0.1, 0.12, 0.16))
		draw_string(font, phone.position + Vector2(0, 170),
			"FakeTok %d/%d" % [_display_index + 1, DISPLAY_COUNT],
			HORIZONTAL_ALIGNMENT_CENTER, phone.size.x, 24, Color(0.9, 0.9, 0.9))
	if _comments_open:
		_draw_comments(font, phone)


func _draw_comments(font: Font, phone: Rect2) -> void:
	var panel := Rect2(phone.position + Vector2(40, 10), Vector2(phone.size.x - 50, phone.size.y - 20))
	draw_rect(panel, Color(0.05, 0.05, 0.08, 0.94))
	draw_rect(panel, Color(0.4, 0.4, 0.5), false, 2.0)
	draw_string(font, panel.position + Vector2(0, 24), "Comments (%d)" % _comments.size(),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 17, Color(1, 1, 1))
	var y := panel.position.y + 44.0
	var end := mini(_scroll + COMMENTS_VISIBLE, _comments.size())
	for i in range(_scroll, end):
		var c: Dictionary = _comments[i]
		var ncol := Color(1.0, 0.45, 0.45) if bool(c["neg"]) else Color(0.55, 0.85, 1.0)
		draw_string(font, Vector2(panel.position.x + 10, y), "@" + String(c["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20, 14, ncol)
		y += 18.0
		for line in _wrap(font, String(c["text"]), 13, panel.size.x - 20):
			draw_string(font, Vector2(panel.position.x + 10, y), line,
				HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20, 13, Color(0.92, 0.92, 0.92))
			y += 17.0
		var vcol := Color(1.0, 0.4, 0.4) if bool(c["neg"]) else Color(0.5, 1.0, 0.55)
		draw_string(font, Vector2(panel.position.x + 10, y),
			format_votes(int(c["votes"])) + (" downvotes" if bool(c["neg"]) else " upvotes"),
			HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20, 12, vcol)
		y += 28.0
	# Scroll hint.
	if _comments.size() > COMMENTS_VISIBLE:
		draw_string(font, Vector2(panel.position.x, panel.end.y - 6),
			"UP/DOWN scrolls  (%d-%d)" % [_scroll + 1, end],
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 12, Color(0.6, 0.6, 0.65))
