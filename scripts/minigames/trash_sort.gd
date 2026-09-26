class_name TrashSort
extends Minigame
## Trash station — "Trash Sort". A stream of junk falls down the screen;
## LEFT/A sorts into recycle, RIGHT/D into trash. Every press sorts the LOWEST
## item on screen — no timing, just call it right. 10 correct to win.
## 3 mistakes = fail.
##
## Controls: Left/Right arrows to sort the bottom item.

const WIN_SORTED: int = 10
const MAX_MISTAKES: int = 3
const FALL_SPEED: float = 170.0
const ITEM_COUNT: int = 4
const ITEM_SPACING: float = 130.0
# item name -> true means recyclable.
const ITEMS: Array = [
	["Bottle", true], ["Banana peel", false], ["Newspaper", true],
	["Styrofoam", false], ["Tin can", true], ["Broken glass", false],
	["Cardboard", true], ["Chip bag", false], ["Milk jug", true],
	["Battery", false],
]

# item name -> placeholder sprite. Every trash-sort item has art now.
const ITEM_TEX := {
	"Bottle": preload("res://placeholder art/Sprites/bottle_recycle.png"),
	"Banana peel": preload("res://placeholder art/Sprites/banana_peel.png"),
	"Newspaper": preload("res://placeholder art/Sprites/newspaper.png"),
	"Styrofoam": preload("res://placeholder art/Sprites/styrofoam.png"),
	"Tin can": preload("res://placeholder art/Sprites/can_recycle.png"),
	"Broken glass": preload("res://placeholder art/Sprites/glass_shard.png"),
	"Cardboard": preload("res://placeholder art/Sprites/cardboard_flat.png"),
	"Chip bag": preload("res://placeholder art/Sprites/chip_bag.png"),
	"Milk jug": preload("res://placeholder art/Sprites/milk_jug.png"),
	"Battery": preload("res://placeholder art/Sprites/battery.png"),
}

var _items: Array = []  # Dictionaries {id, name, recyclable, y}
var _next_id: int = 1
var _sorted: int = 0
var _mistakes: int = 0
var _bin_recycle := Rect2()
var _bin_trash := Rect2()


func start() -> void:
	super.start()
	title_text = "Trash Sort"
	help_text = "LEFT/A = recycle, RIGHT/D = trash. Each press sorts the LOWEST item! %d right wins." % WIN_SORTED
	_bin_recycle = Rect2(60, size.y - 180.0, 150, 120)
	_bin_trash = Rect2(size.x - 210, size.y - 180.0, 150, 120)
	_items.clear()
	_next_id = 1
	_sorted = 0
	_mistakes = 0
	for i in ITEM_COUNT:
		_spawn_item()


func _spawn_item() -> void:
	var def: Array = ITEMS[randi() % ITEMS.size()]
	# Stack newcomers above whatever is already falling so they never overlap.
	var y := 96.0
	for it in _items:
		y = minf(y, float((it as Dictionary)["y"]) - ITEM_SPACING)
	_items.append({"id": _next_id, "name": String(def[0]),
		"recyclable": bool(def[1]), "y": y})
	_next_id += 1


## The active item: whichever is lowest on screen.
func _bottom_item() -> Dictionary:
	var best := {}
	var best_y := -INF
	for it in _items:
		var d := it as Dictionary
		if float(d["y"]) > best_y:
			best_y = float(d["y"])
			best = d
	return best


func _process(delta: float) -> void:
	if _over:
		return
	for it in _items:
		var d := it as Dictionary
		d["y"] = float(d["y"]) + FALL_SPEED * delta / _speed
	# Anything that fell off the bottom unsorted is a mistake.
	var kept: Array = []
	for it in _items:
		var d := it as Dictionary
		if float(d["y"]) > size.y - 40.0:
			_register_mistake("Missed the " + String(d["name"]) + "!")
			if _over:
				return
		else:
			kept.append(d)
	_items = kept
	while _items.size() < ITEM_COUNT:
		_spawn_item()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_LEFT or k.keycode == KEY_A:
		_sort_item(true)
	elif k.keycode == KEY_RIGHT or k.keycode == KEY_D:
		_sort_item(false)


func _sort_item(said_recyclable: bool) -> void:
	# Always sorts the bottom item — no timing window.
	var it := _bottom_item()
	if it.is_empty():
		return
	_items.erase(it)
	if said_recyclable == bool(it["recyclable"]):
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
	var it := _bottom_item()
	if it.is_empty():
		return
	_sort_item(bool(it["recyclable"]))


func test_sort_wrong() -> void:
	var it := _bottom_item()
	if it.is_empty():
		return
	_sort_item(not bool(it["recyclable"]))


func _draw_game() -> void:
	var font := ThemeDB.fallback_font
	var cx := size.x / 2.0
	# Bins.
	draw_rect(_bin_recycle, Color(0.2, 0.55, 0.3))
	draw_rect(_bin_trash, Color(0.45, 0.45, 0.5))
	draw_string(font, _bin_recycle.position + Vector2(0, -8), "RECYCLE (L)",
		HORIZONTAL_ALIGNMENT_CENTER, _bin_recycle.size.x, 16, Color(0.7, 1.0, 0.75))
	draw_string(font, _bin_trash.position + Vector2(0, -8), "TRASH (R)",
		HORIZONTAL_ALIGNMENT_CENTER, _bin_trash.size.x, 16, Color(0.9, 0.9, 0.9))
	# Falling items; the bottom (active) one gets the gold outline.
	var bottom := _bottom_item()
	var items_sorted := _items.duplicate()
	items_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["y"]) < float(b["y"]))
	for it in items_sorted:
		var d := it as Dictionary
		var iy := float(d["y"])
		var tex: Texture2D = ITEM_TEX.get(String(d["name"]), null)
		var is_bottom := int(d["id"]) == int(bottom.get("id", -1))
		if tex != null:
			var tpos := Vector2(cx - tex.get_width() / 2.0, iy - tex.get_height() / 2.0)
			draw_texture(tex, tpos)
			var edge := Color(1.0, 0.85, 0.3) if is_bottom else Color(0.3, 0.25, 0.15)
			draw_rect(Rect2(tpos - Vector2(3, 3), tex.get_size() + Vector2(6, 6)),
				edge, false, 3.0 if is_bottom else 2.0)
		else:
			var rect := Rect2(cx - 70, iy - 22, 140, 44)
			draw_rect(rect, Color(0.85, 0.8, 0.6))
			var edge := Color(1.0, 0.85, 0.3) if is_bottom else Color(0.3, 0.25, 0.15)
			draw_rect(rect, edge, false, 3.0 if is_bottom else 2.0)
		draw_string(font, Vector2(cx - 70, iy + 34), String(d["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(0.9, 0.88, 0.8))
	draw_string(font, Vector2(24, 120),
		"Sorted: %d/%d   Mistakes: %d/%d" % [_sorted, WIN_SORTED, _mistakes, MAX_MISTAKES],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
