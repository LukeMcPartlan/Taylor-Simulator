class_name TrashSort
extends Minigame
## Trash station — "Trash Sort". Items fall; sort each into the right bin
## while it's in the sort zone. LEFT = recycle, RIGHT = trash.
## 10 correct to win. 3 mistakes = fail.
##
## Controls: Left/Right arrows to sort the highlighted item.

const WIN_SORTED: int = 10
const MAX_MISTAKES: int = 3
const FALL_SPEED: float = 170.0
# item name -> true means recyclable.
const ITEMS: Array = [
	["Bottle", true], ["Banana peel", false], ["Newspaper", true],
	["Styrofoam", false], ["Tin can", true], ["Broken glass", false],
	["Cardboard", true], ["Chip bag", false], ["Milk jug", true],
	["Battery", false],
]

var _item: Dictionary = {}  # {name, recyclable, y}
var _sorted: int = 0
var _mistakes: int = 0
var _zone := Rect2()
var _bin_recycle := Rect2()
var _bin_trash := Rect2()


func start() -> void:
	super.start()
	title_text = "Trash Sort"
	help_text = "LEFT = recycle bin, RIGHT = trash bin. Sort %d right!" % WIN_SORTED
	var cx := size.x / 2.0
	_zone = Rect2(cx - 150.0, size.y - 220.0, 300.0, 120.0)
	_bin_recycle = Rect2(60, size.y - 180.0, 150, 120)
	_bin_trash = Rect2(size.x - 210, size.y - 180.0, 150, 120)
	_sorted = 0
	_mistakes = 0
	_spawn_item()


func _spawn_item() -> void:
	var def: Array = ITEMS[randi() % ITEMS.size()]
	_item = {"name": String(def[0]), "recyclable": bool(def[1]), "y": 96.0}


func _process(delta: float) -> void:
	if _over:
		return
	_item["y"] = float(_item["y"]) + FALL_SPEED * delta / _speed
	if float(_item["y"]) > size.y - 40.0:
		# Let it fall through unjudged? No — ignoring trash is a mistake too.
		_register_mistake("Missed the " + String(_item["name"]) + "!")
		_spawn_item()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_LEFT:
		_sort_item(true)
	elif k.keycode == KEY_RIGHT:
		_sort_item(false)


func _sort_item(said_recyclable: bool) -> void:
	# Only counts while the item is in the sort zone — timing matters.
	var y := float(_item["y"])
	if not _zone.has_point(Vector2(size.x / 2.0, y)):
		return
	if said_recyclable == bool(_item["recyclable"]):
		_sorted += 1
		if _sorted >= WIN_SORTED:
			_end(true)
			return
	else:
		_register_mistake("Wrong bin!")
		if _over:
			return
	_spawn_item()


func _register_mistake(_why: String) -> void:
	_mistakes += 1
	if _mistakes >= MAX_MISTAKES:
		_end(false)


# --- Test hooks ----------------------------------------------------------
func test_sort_correct() -> void:
	_item["y"] = _zone.get_center().y
	_sort_item(bool(_item["recyclable"]))


func test_sort_wrong() -> void:
	_item["y"] = _zone.get_center().y
	_sort_item(not bool(_item["recyclable"]))


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	# Sort zone.
	draw_rect(_zone, Color(0.2, 0.25, 0.35, 0.6))
	draw_rect(_zone, Color(0.6, 0.7, 0.9), false, 2.0)
	# Bins.
	draw_rect(_bin_recycle, Color(0.2, 0.55, 0.3))
	draw_rect(_bin_trash, Color(0.45, 0.45, 0.5))
	draw_string(font, _bin_recycle.position + Vector2(0, -8), "RECYCLE (L)",
		HORIZONTAL_ALIGNMENT_CENTER, _bin_recycle.size.x, 16, Color(0.7, 1.0, 0.75))
	draw_string(font, _bin_trash.position + Vector2(0, -8), "TRASH (R)",
		HORIZONTAL_ALIGNMENT_CENTER, _bin_trash.size.x, 16, Color(0.9, 0.9, 0.9))
	# Falling item: a labeled box.
	var iy := float(_item["y"])
	var cx := size.x / 2.0
	draw_rect(Rect2(cx - 70, iy - 22, 140, 44), Color(0.85, 0.8, 0.6))
	draw_rect(Rect2(cx - 70, iy - 22, 140, 44), Color(0.3, 0.25, 0.15), false, 2.0)
	draw_string(font, Vector2(cx - 70, iy + 6), String(_item["name"]),
		HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(0.15, 0.12, 0.08))
	draw_string(font, Vector2(24, 120),
		"Sorted: %d/%d   Mistakes: %d/%d" % [_sorted, WIN_SORTED, _mistakes, MAX_MISTAKES],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
