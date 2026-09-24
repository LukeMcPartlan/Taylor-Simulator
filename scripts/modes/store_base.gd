class_name ModeStoreBase
extends Area2D
## Base class for the three walk-up night store kiosks (night-shift, meltdown,
## combo-mom). Subclasses provide the inventory; this handles the kiosk
## visuals, the open/closed prompt, and the number-key shop menu.
##
## Subclass contract:
## - store_title() -> String       e.g. "🌙 NIGHT STORE"
## - store_hours_text() -> String  e.g. "opens 9pm" (shown when closed)
## - is_open() -> bool             based on GameState.time_hours
## - wallet_text() -> String       e.g. "Your serotonin: 42"
## - get_rows() -> Array of Dictionaries, each:
##     {"number": int, "name": String, "desc": String, "price": String,
##      "status": String ("OWNED"/"ACTIVE"/""), "affordable": bool,
##      "id": String, "kind": String}
## - buy_row(kind: String, id: String) -> Dictionary {"ok": bool, "msg": String}
##
## Godot conventions:
## - `_input` (not `_unhandled_input`) + set_input_as_handled(): the shop eats
##   number keys so they don't leak into the HUD's hotkeys.
## - CanvasLayer as a child of a Node2D: draws in screen space regardless of
##   where the store sits in the world — the standard way to pop UI from a
##   world object.

const INTERACT_RADIUS: float = 72.0
const OPEN_COLOR := Color(1.0, 0.75, 0.2)    # gold: we're open, baby
const CLOSED_COLOR := Color(0.35, 0.32, 0.4) # sad gray: go to bed

var _player_inside: bool = false
var _menu_open: bool = false
var _was_open: bool = false

var _marker: ColorRect
var _visual_spr: Sprite2D = null  # stall sprite (replaces the old kiosk block)
var _title_label: Label
var _prompt: Label
var _menu_layer: CanvasLayer
var _menu_items: VBoxContainer
var _wallet_label: Label
var _status_label: Label
var _rows: Array = []  # row dicts from get_rows(), in menu order


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	add_child(shape)

	# The shop: a little night-store stall sprite (was a ColorRect block).
	_marker = ColorRect.new()
	_marker.size = Vector2(96, 64)
	_marker.position = Vector2(-48, -64)
	_marker.color = CLOSED_COLOR
	_marker.hide()
	add_child(_marker)
	var spr := Sprite2D.new()
	spr.texture = load("res://placeholder art/Sprites/night_store.png")
	spr.position = Vector2(0, -22)
	add_child(spr)
	_visual_spr = spr

	var title := _make_label(store_title(), Vector2(-90, -72), Vector2(180, 28), 20)
	title.modulate = Color(1.0, 0.85, 0.4)
	add_child(title)
	_title_label = title
	if not show_title_label():
		title.hide()

	_prompt = _make_label("", Vector2(-110, -102), Vector2(220, 24), 16)
	_prompt.modulate = Color(1, 1, 0.6)
	_prompt.hide()
	add_child(_prompt)

	_build_menu()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.clock_changed.connect(_on_clock_changed)
	_was_open = is_open()
	_refresh_open_state()


func _process(_delta: float) -> void:
	# Opening hours follow the in-game clock; refresh visuals on change.
	var open := is_open()
	if open != _was_open:
		_was_open = open
		_refresh_open_state()
		_update_prompt()
		if not open and _menu_open:
			_close_menu()  # kicked out at closing time (== day end anyway)


func _input(event: InputEvent) -> void:
	if not _player_inside or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_E:
		if not is_open():
			_notify("Closed — " + store_hours_text(), Color(0.7, 0.7, 0.7))
		else:
			_toggle_menu()
		get_viewport().set_input_as_handled()
		return

	if _menu_open and key_event.keycode == KEY_ESCAPE:
		_close_menu()
		get_viewport().set_input_as_handled()
		return

	# Number keys buy while the menu is open.
	if _menu_open and key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		var number: int = key_event.keycode - KEY_0
		_buy_number(number)
		get_viewport().set_input_as_handled()


# --- Subclass contract (override these) ----------------------------------------

func store_title() -> String:
	return "STORE"


## The floating title above the store (e.g. "💻 LAPTOP"). The laptop stores
## hide it — the laptop sprite speaks for itself.
func show_title_label() -> bool:
	return true

func store_hours_text() -> String:
	return "opens 9pm"

func is_open() -> bool:
	return false

func wallet_text() -> String:
	return ""

func get_rows() -> Array:
	return []

func buy_row(_kind: String, _id: String) -> Dictionary:
	return {"ok": false, "msg": "Nothing to buy here."}


# --- Menu ----------------------------------------------------------------------

func _toggle_menu() -> void:
	if _menu_open:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	_refresh_menu()
	_menu_layer.show()
	_menu_open = true


func _close_menu() -> void:
	_menu_layer.hide()
	_menu_open = false
	_update_prompt()


func _buy_number(number: int) -> void:
	for row in _rows:
		if int(row["number"]) == number:
			var res: Dictionary = buy_row(String(row["kind"]), String(row["id"]))
			_status_label.text = String(res.get("msg", ""))
			_status_label.modulate = Color(0.5, 1.0, 0.6) if bool(res.get("ok", false)) \
				else Color(1.0, 0.6, 0.3)
			_refresh_menu()
			return


func _refresh_menu() -> void:
	for child in _menu_items.get_children():
		child.queue_free()
	_rows = get_rows()
	_wallet_label.text = wallet_text()
	var last_section := ""
	for row in _rows:
		var section := String(row.get("section", ""))
		if section != "" and section != last_section:
			last_section = section
			_menu_items.add_child(_make_menu_label(section, Color(1.0, 0.8, 0.35)))
		var status := String(row["status"])
		var line := "%d. %s — %s%s" % [
			int(row["number"]), String(row["name"]), String(row["price"]),
			(" — " + status) if status != "" else ""]
		var label := _make_menu_label(line, Color(1, 1, 1))
		if status == "OWNED" or status.begins_with("MAXED") or status.begins_with("ACTIVE"):
			label.modulate = Color(0.45, 0.45, 0.45)
		elif not bool(row["affordable"]):
			label.modulate = Color(1.0, 0.5, 0.5)
		_menu_items.add_child(label)
		var desc := _make_menu_label("     " + String(row["desc"]), Color(0.75, 0.75, 0.8))
		_menu_items.add_child(desc)


func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 10
	_menu_layer.hide()
	add_child(_menu_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := _make_menu_label(store_title() + " — number keys buy, E closes",
		Color(1.0, 0.85, 0.4))
	vbox.add_child(header)

	_wallet_label = _make_menu_label("", Color(0.6, 1.0, 0.6))
	vbox.add_child(_wallet_label)

	_menu_items = VBoxContainer.new()
	_menu_items.add_theme_constant_override("separation", 2)
	vbox.add_child(_menu_items)

	_status_label = _make_menu_label("", Color(1, 1, 1))
	vbox.add_child(_status_label)


# --- Shared bits -----------------------------------------------------------------

func _refresh_open_state() -> void:
	_marker.color = OPEN_COLOR if is_open() else CLOSED_COLOR
	if _visual_spr != null:
		# Gold glow when open, dimmed gray when closed (replaces the old
		# kiosk block colors).
		_visual_spr.modulate = Color(1.15, 1.05, 0.85) if is_open() else Color(0.55, 0.55, 0.62)


func _update_prompt() -> void:
	if not _player_inside:
		_prompt.hide()
		return
	if is_open():
		_prompt.text = "E — %s (OPEN!)" % store_title()
		_prompt.modulate = Color(0.5, 1.0, 0.6)
	else:
		_prompt.text = "%s — %s" % [store_title(), store_hours_text()]
		_prompt.modulate = Color(0.7, 0.7, 0.7)
	_prompt.show()


func _on_clock_changed(_time_string: String) -> void:
	_update_prompt()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_prompt.hide()
		_close_menu()


func _notify(text: String, color: Color) -> void:
	var world := get_parent()
	if world.has_method("spawn_float_text"):
		world.spawn_float_text(global_position + Vector2(0, -150), text, color)


func _make_label(text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_menu_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(440, 0)
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = color
	return label
