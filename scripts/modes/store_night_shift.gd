extends ModeStoreBase
## Taylor's LAPTOP (night-shift). Walk up, press E — open any time, and the
## clock keeps ticking while you use it.
##
## Two tabs:
## - WORK: manage the inbox. Deranged employee emails roll in; FIRE or HIRE
##   each one. Every press costs 10 serotonin and pays $10. New email each
##   press, forever. (F/H keys work too.)
## - AMAZON: spend dollars on upgrade tiers (3 each). In-run only — they last
##   the run, not the save. Permanent versions are sold in the main menu.

const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")

const WORK_SEROTONIN_COST: float = 10.0
const WORK_DOLLAR_PAY: float = 10.0

# {from, subject, body} — the staff are, legally speaking, a liability.
const WORK_EMAILS: Array = [
	{"from": "bigmike@staff", "subject": "quick question",
		"body": "uhhh boss i was smoking weed in the cancer ward a now their saying i cant work here? what gives???"},
	{"from": "jennyrn@staff", "subject": "just double checking",
		"body": "hey boss, i recorded all my patients hippa info on my iphone so i could feed it into AI, just doubble checking if thats cool???"},
	{"from": "deshawn@staff", "subject": "UNFAIR WRITE UP",
		"body": "you are a RACIST boss that patient had it coming i had every right to bust his ass"},
	{"from": "kev@staff", "subject": "break question",
		"body": "boss i left a patient on the toilet for 6 hours because the game was on. he's fine. probably. do i still get my break?"},
	{"from": "priya@staff", "subject": "marketing idea",
		"body": "quick q: is it against policy to venmo patients for good reviews? asking for me"},
	{"from": "tiff@staff", "subject": "HR is overreacting",
		"body": "i told a lady her baby was ugly and she cried. HR says thats 'unprofessional'. thoughts???"},
	{"from": "marcus@staff", "subject": "family business",
		"body": "i've been clocking in my cousin for 3 months, he doesn't work here, we split the checks 50/50. wanted you to hear it from me first"},
	{"from": "anonymous (dave)", "subject": "mop bucket",
		"body": "someone pissed in the mop bucket again. it was me. i panicked. can we just rinse it"},
	{"from": "jaylen@staff", "subject": "discharge papers",
		"body": "i gave a patient my mixtape instead of their discharge papers. the mixtape slaps tho"},
	{"from": "linda@staff", "subject": "office supplies",
		"body": "is it stealing if i take the good pens home? asking because i took 40"},
	{"from": "nightgreg@staff", "subject": "shift swap?",
		"body": "i fell asleep during night shift and a guy flatlined. he's back now. anyway can i switch to days"},
	{"from": "soph@staff", "subject": "team building",
		"body": "i told the new hire the break room fridge is a urinal. he believed me for a week. team building??"},
	{"from": "ronnie@staff", "subject": "vending machine",
		"body": "boss the vending machine ate my dollar so i tipped it over. it landed on kevin. kevin's fine"},
	{"from": "amanda@staff", "subject": "personal printing",
		"body": "i've been using the office printer for my wedding invitations. 300 copies. double sided"},
	{"from": "chris_e@staff", "subject": "hydration",
		"body": "a patient asked for water and i gave him a white claw. he seemed happier honestly"},
	{"from": "pat@staff", "subject": "front desk",
		"body": "i let my emotional support ferret run the front desk tuesday. bookings are up 20%"},
	{"from": "dave@staff", "subject": "microwave",
		"body": "i super glued the break room microwave shut because linda kept burning fish. linda is HR now"},
	{"from": "vince@staff", "subject": "billing innovation",
		"body": "i billed a guy for 'premium air' during his stay. $400. he paid it. can i get a raise"},
	{"from": "mia@staff", "subject": "waiting room",
		"body": "i told everyone in the waiting room the doctor is running late because he's 'vibing'. he was napping"},
	{"from": "tony@staff", "subject": "sanitizer",
		"body": "i replaced all the hand sanitizer with tequila. morale is up. infections also up"},
	{"from": "rob@staff", "subject": "timesaver",
		"body": "i've been signing YOUR name on write-ups to save time. hope thats cool. it wasnt cool was it"},
	{"from": "jess@staff", "subject": "supply closet",
		"body": "i locked myself in the supply closet to avoid a meeting and now i live here. send snacks"},
	{"from": "derrick@staff", "subject": "promotion",
		"body": "i gave myself a promotion in the system. i'm regional manager now. congrats to me"},
]

var _tab: String = "work"  # "work" | "amazon"
var _email: Dictionary = {}
var _work_panel: VBoxContainer
var _amazon_panel: VBoxContainer
var _tab_work_btn: Button
var _tab_amazon_btn: Button
var _from_label: Label
var _subject_label: Label
var _body_label: Label
var _work_note: Label


func _ready() -> void:
	super._ready()
	# The laptop is a small sprite now (was a stack of ColorRects) — it sits
	# on the floor at the marker, much smaller than before.
	_marker.hide()
	var spr := Sprite2D.new()
	spr.texture = load("res://placeholder art/Sprites/laptop.png")
	spr.position = Vector2(0, -14)
	add_child(spr)
	_new_email()
	# Pull the title/prompt down to sit just above the little laptop.
	if _title_label != null:
		_title_label.position = Vector2(-90, -58)
	if _prompt != null:
		_prompt.position = Vector2(-110, -88)


func store_title() -> String:
	return "💻 LAPTOP"


func show_title_label() -> bool:
	return false


func store_hours_text() -> String:
	return "always open"


func is_open() -> bool:
	# The laptop never closes — but the clock keeps ticking while you use it.
	var m := _mode()
	return m != null and GameState.sim_running


func wallet_text() -> String:
	return "Your dollars: $%d (swept to savings at day end)" % int(GameState.dollars)


func get_rows() -> Array:
	var m := _mode()
	if m == null:
		return []
	var rows: Array = []
	var number := 0
	for def in _UPGRADE_DEFS.DEFS:
		number += 1
		var id := String(def["id"])
		var section := "UPGRADES — in-run tiers, last the run"
		if String(def["kind"]) == "collectible":
			section = "COLLECTIBLES — raise your serotonin cap"
		var run_t := int(m.call("run_tier", id))
		var perm_t := int(GameState.permanent_tier(id))
		var maxed := run_t >= _UPGRADE_DEFS.max_tier()
		var name := ""
		var desc := ""
		var price := ""
		var status := ""
		var affordable := true
		if maxed:
			var owned_td: Dictionary = (def["tiers"] as Array)[run_t - 1]
			name = "%s — run T%d/3" % [String(owned_td["label"]), run_t]
			desc = String(owned_td["desc"])
			price = "—"
			status = "MAXED"
		else:
			var next_td: Dictionary = (def["tiers"] as Array)[run_t]
			var cost := float(next_td["run_cost"])
			name = "next: %s — run T%d/3" % [String(next_td["label"]), run_t]
			desc = String(next_td["desc"])
			price = "$%d" % int(cost)
			affordable = GameState.dollars >= cost
		if perm_t > 0:
			var perm_note := "PERM T%d" % perm_t
			status = (status + " · " + perm_note) if status != "" else perm_note
		rows.append({
			"number": number, "kind": "upgrade", "id": id, "section": section,
			"name": name, "desc": desc,
			"price": price,
			"status": status,
			"affordable": affordable,
		})
	return rows


func buy_row(kind: String, id: String) -> Dictionary:
	var m := _mode()
	if m == null:
		return {"ok": false, "msg": "The laptop bluescreens."}
	if kind != "upgrade":
		return {"ok": false, "msg": "Click a tab, boss."}
	var res: Dictionary = m.buy_run_upgrade(id)
	if bool(res.get("ok", false)) and id == "roomba":
		var world := get_parent()
		if world != null and world.has_method("spawn_roomba"):
			world.spawn_roomba()
	return res


func _mode() -> Node:
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") \
			and m.mode_id() == ModeManager.Mode.NIGHT_SHIFT:
		return m
	return null


func _input(event: InputEvent) -> void:
	# F = FIRE, H = HIRE while the work tab is open.
	if _menu_open and _tab == "work" and _player_inside and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F:
				_do_work("FIRED")
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_H:
				_do_work("HIRED")
				get_viewport().set_input_as_handled()
				return
	super._input(event)


# --- Work tab ---------------------------------------------------------------

func _new_email() -> void:
	_email = WORK_EMAILS[randi() % WORK_EMAILS.size()]
	_refresh_work_panel()


func _do_work(verdict: String) -> void:
	if GameState.serotonin < WORK_SEROTONIN_COST:
		_status_label.text = "Too dead inside to manage anyone (need 10 serotonin)."
		_status_label.modulate = Color(1.0, 0.6, 0.3)
		return
	GameState.add_serotonin(-WORK_SEROTONIN_COST)
	GameState.add_dollars(WORK_DOLLAR_PAY)
	var who := String(_email.get("from", "staff"))
	GameState.say("TAYLOR", "%s. %s. +$10." % [verdict, who])
	_status_label.text = "%s %s — -$10 serotonin, +$10." % [verdict, who]
	_status_label.modulate = Color(0.5, 1.0, 0.6)
	_new_email()


# --- Tabbed menu (overrides the base single-list menu) ------------------------

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

	vbox.add_child(_make_menu_label("💻 TAYLOR'S LAPTOP — E closes, clock keeps ticking",
		Color(0.55, 0.85, 1.0)))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_tab_work_btn = _make_tab_button("💼 WORK")
	_tab_work_btn.pressed.connect(_switch_tab.bind("work"))
	tabs.add_child(_tab_work_btn)
	_tab_amazon_btn = _make_tab_button("📦 AMAZON")
	_tab_amazon_btn.pressed.connect(_switch_tab.bind("amazon"))
	tabs.add_child(_tab_amazon_btn)

	# WORK panel.
	_work_panel = VBoxContainer.new()
	_work_panel.add_theme_constant_override("separation", 4)
	vbox.add_child(_work_panel)
	_from_label = _make_menu_label("", Color(0.6, 1.0, 0.6))
	_work_panel.add_child(_from_label)
	_subject_label = _make_menu_label("", Color(1.0, 0.9, 0.5))
	_work_panel.add_child(_subject_label)
	_body_label = _make_menu_label("", Color(1, 1, 1))
	_work_panel.add_child(_body_label)
	var verdicts := HBoxContainer.new()
	verdicts.add_theme_constant_override("separation", 16)
	_work_panel.add_child(verdicts)
	var fire := _make_tab_button("🔥 FIRE  (F)")
	fire.pressed.connect(_do_work.bind("FIRED"))
	verdicts.add_child(fire)
	var hire := _make_tab_button("🤝 HIRE  (H)")
	hire.pressed.connect(_do_work.bind("HIRED"))
	verdicts.add_child(hire)
	_work_note = _make_menu_label(
		"Each verdict: -10 serotonin, +$10. A new email lands every time.",
		Color(0.75, 0.75, 0.8))
	_work_panel.add_child(_work_note)

	# AMAZON panel.
	_amazon_panel = VBoxContainer.new()
	_amazon_panel.add_theme_constant_override("separation", 2)
	vbox.add_child(_amazon_panel)
	_wallet_label = _make_menu_label("", Color(0.6, 1.0, 0.6))
	_amazon_panel.add_child(_wallet_label)
	_menu_items = VBoxContainer.new()
	_menu_items.add_theme_constant_override("separation", 2)
	_amazon_panel.add_child(_menu_items)

	_status_label = _make_menu_label("", Color(1, 1, 1))
	vbox.add_child(_status_label)

	_switch_tab("work")


func _make_tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(180, 44)
	return b


func _switch_tab(tab: String) -> void:
	_tab = tab
	_tab_work_btn.disabled = tab == "work"
	_tab_amazon_btn.disabled = tab == "amazon"
	_work_panel.visible = tab == "work"
	_amazon_panel.visible = tab == "amazon"
	_refresh_menu()


func _refresh_menu() -> void:
	if _tab == "work":
		_refresh_work_panel()
	else:
		for child in _menu_items.get_children():
			child.queue_free()
		_rows = get_rows()
		_wallet_label.text = wallet_text()
		for row in _rows:
			var status := String(row["status"])
			var line := "%d. %s — %s%s" % [
				int(row["number"]), String(row["name"]), String(row["price"]),
				(" — " + status) if status != "" else ""]
			var label := _make_menu_label(line, Color(1, 1, 1))
			if status == "OWNED":
				label.modulate = Color(0.45, 0.45, 0.45)
			elif not bool(row["affordable"]):
				label.modulate = Color(1.0, 0.5, 0.5)
			_menu_items.add_child(label)
			var desc := _make_menu_label("     " + String(row["desc"]), Color(0.75, 0.75, 0.8))
			_menu_items.add_child(desc)


func _refresh_work_panel() -> void:
	if _from_label == null:
		return  # menu not built yet (first email picked in _ready)
	_from_label.text = "From: " + String(_email.get("from", "staff"))
	_subject_label.text = "Subject: " + String(_email.get("subject", "(no subject)"))
	_body_label.text = "\"" + String(_email.get("body", "...")) + "\""


func _refresh_open_state() -> void:
	# The laptop is always open; keep its look instead of the kiosk colors.
	if _marker != null:
		_marker.color = Color(0.07, 0.09, 0.15)
