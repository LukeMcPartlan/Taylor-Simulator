extends Node
## MELTDOWN mode node. Survival-horror Taylor: cortisol pinned at 100 means an
## instant meltdown and 1 of 3 sanity lives lost. Three meltdowns = game over.
##
## - 5 coping mechanisms (permanent, bought with serotonin at the night store)
##   stack multiplicative relief: less cortisol gain, slower neglect, slower
##   baseline decay, bigger chore relief.
## - 3 venting trades: spend serotonin to dump cortisol NOW, with cooldowns.
## - Tighter pressure: neglect x1.5; a failed minigame costs +5 cortisol, so a
##   fumble can genuinely tip you into a meltdown.
## - Above 70 cortisol, Luke drops the act and goes mean (see luke.gd).
## - No save file: every run starts from zero. 3 lives. No mercy.

signal sanity_changed(lives: int)
signal coping_changed

const MAX_SANITY_LIVES: int = 3
const STORE_OPEN_HOUR: float = 21.0
const MELTDOWN_CORTISOL_RESET: float = 40.0

const COPING_DEFS: Array = [
	{"id": "headphones", "name": "Noise-cancelling Headphones", "blurb": "Cortisol gains -15%",
		"cost": 60.0, "mult": "cortisol_gain", "factor": 0.85},
	{"id": "mealprep", "name": "Meal Prep Sundays", "blurb": "Neglect pressure ticks 20% slower",
		"cost": 90.0, "mult": "neglect_speed", "factor": 0.80},
	{"id": "gym", "name": "Gym Membership (never used)", "blurb": "Chore cortisol relief +25%",
		"cost": 110.0, "mult": "task_relief", "factor": 1.25},
	{"id": "therapy", "name": "Therapy Fund", "blurb": "Baseline serotonin decay -50%",
		"cost": 120.0, "mult": "baseline_decay", "factor": 0.50},
	{"id": "whitenoise", "name": "Industrial White-Noise Fan", "blurb": "Cortisol gains -20%",
		"cost": 160.0, "mult": "cortisol_gain", "factor": 0.80},
]

# Spend serotonin to dump cortisol NOW. Cooldowns stop you from spamming the
# pillow into a stress-free utopia.
const VENT_DEFS: Array = [
	{"id": "pillow", "name": "Scream into a pillow", "cortisol_dump": 20.0,
		"serotonin_cost": 15.0, "cooldown": 30.0},
	{"id": "pantry", "name": "Cry in the pantry", "cortisol_dump": 35.0,
		"serotonin_cost": 25.0, "cooldown": 60.0},
	{"id": "bake", "name": "Stress-bake cookies", "cortisol_dump": 12.0,
		"serotonin_cost": 8.0, "cooldown": 20.0},
]

const MEAN_LINES: Array = [
	"taylor you look like a haunted house attraction, have you slept since 2019?",
	"the baby's been crying for an hour and you haven't moved. new record, honestly impressive",
	"is that smell the basement toilet or did something die in the laundry pile? no offense. some offense",
	"no rush but the dishes are starting to form their own civilization in there. i think they elected a king",
	"the bags under your eyes have bags now. iconic. very halloween",
	"i told the baby you'd feed it eventually. hope i wasn't lying lol",
	"you've sighed 40 times in the last minute. should i start counting out loud?",
]

var sanity_lives: int = MAX_SANITY_LIVES
var meltdowns_this_run: int = 0
var coping_owned: Dictionary = {}   # item id -> true (run-long, NOT persisted)
var vent_cooldowns: Dictionary = {} # vent id -> seconds left
var _sanity_label: Label = null
var _vignette: ColorRect = null


func _ready() -> void:
	var gs := get_parent()
	gs.day_started.connect(_on_day_started)
	_on_day_started(gs.day_number)


func _process(delta: float) -> void:
	var gs := get_parent()
	# Vent cooldowns tick in real seconds.
	for id in vent_cooldowns.keys():
		vent_cooldowns[id] = maxf(0.0, float(vent_cooldowns[id]) - delta)
	# Horror juice: the screen bleeds red as cortisol climbs.
	if _vignette != null and is_instance_valid(_vignette):
		var c := _vignette.color
		c.a = gs.cortisol / 100.0 * 0.45
		_vignette.color = c
	# The horror rule: cortisol pinned at 100 = instant meltdown.
	if gs.sim_running and gs.cortisol >= gs.METER_MAX:
		_trigger_meltdown(gs)


func _on_day_started(_day: int) -> void:
	# Venting cooldowns reset each morning. Coping items and lives persist.
	vent_cooldowns.clear()


# --- GameState hook queries ---------------------------------------------------

func mode_id() -> int:
	return ModeManager.Mode.MELTDOWN


func neglect_cortisol_rate() -> float:
	var mult: float = 1.5  # tighter pressure than classic
	if coping_owned.has("mealprep"):
		mult *= 0.80
	return GameState.CORTISOL_PER_TASK_PER_HOUR * mult


func neglect_serotonin_rate() -> float:
	var mult: float = 1.5
	if coping_owned.has("mealprep"):
		mult *= 0.80
	return GameState.SEROTONIN_DRAIN_PER_TASK_PER_HOUR * mult


func cortisol_multiplier() -> float:
	var mult: float = 1.0
	for def in COPING_DEFS:
		if coping_owned.has(String(def["id"])) and String(def["mult"]) == "cortisol_gain":
			mult *= float(def["factor"])
	return mult


func baseline_decay_rate() -> float:
	# Therapy Fund halves BASELINE serotonin decay only — neglected-task
	# drain is untouched (that is what the variant's description promises).
	return GameState.SEROTONIN_BASELINE_DECAY_PER_HOUR * (0.50 if coping_owned.has("therapy") else 1.0)


func task_relief_multiplier() -> float:
	return 1.25 if coping_owned.has("gym") else 1.0


func minigame_fail_cortisol() -> float:
	# A fumbled minigame costs +5 cortisol — it can tip you into a meltdown.
	return 5.0


func minigame_fail_text() -> String:
	return "Failed! +5 cortisol. The house feeds on mistakes."


func hud_tag() -> String:
	return "😱 MELTDOWN"


func day_summary_extras() -> Dictionary:
	return {"extra_lines": "Sanity: %d/%d lives left\nMeltdowns this run: %d" % [
		sanity_lives, MAX_SANITY_LIVES, meltdowns_this_run]}


func mean_line() -> String:
	## Called by luke.gd when cortisol is over 70 in this mode.
	return MEAN_LINES[randi() % MEAN_LINES.size()]


# --- Meltdown / game over -----------------------------------------------------

func _trigger_meltdown(gs: Node) -> void:
	sanity_lives -= 1
	meltdowns_this_run += 1
	sanity_changed.emit(sanity_lives)
	_refresh_sanity_label()
	# The day's stress vents with the scream: cortisol drops back down so the
	# retry doesn't insta-meltdown on frame one.
	gs.cortisol = MELTDOWN_CORTISOL_RESET
	if sanity_lives <= 0:
		var stats := "The house wins. Taylor stares at the wall for a while.\nDays survived: %d" \
			% gs.day_number
		gs.end_run("😱 TOTAL MELTDOWN", stats, "run")
	else:
		var stats := "Sanity: %d/%d lives left.\nThe day restarts — coping items kept." % [
			sanity_lives, MAX_SANITY_LIVES]
		gs.end_run("😱 MELTDOWN!", stats, "day")


func reset_run() -> void:
	## Full wipe after game over: 3 fresh lives, coping items gone.
	sanity_lives = MAX_SANITY_LIVES
	meltdowns_this_run = 0
	coping_owned.clear()
	vent_cooldowns.clear()
	sanity_changed.emit(sanity_lives)
	_refresh_sanity_label()


# --- Store API (used by store_meltdown.gd) -------------------------------------

func store_open_now() -> bool:
	var gs := get_parent()
	return gs.sim_running and gs.time_hours >= STORE_OPEN_HOUR \
		and gs.time_hours < gs.DAY_END_HOUR


func buy_coping(item_id: String) -> Dictionary:
	var gs := get_parent()
	for def in COPING_DEFS:
		if String(def["id"]) == item_id:
			if coping_owned.has(item_id):
				return {"ok": false, "msg": "Already owned!"}
			var cost := float(def["cost"])
			if gs.serotonin < cost:
				return {"ok": false, "msg": "Need %d serotonin" % int(cost)}
			gs.serotonin = clampf(gs.serotonin - cost, 0.0, gs.METER_MAX)
			coping_owned[item_id] = true
			coping_changed.emit()
			gs.meters_changed.emit(gs.serotonin, gs.cortisol)
			return {"ok": true, "msg": "Bought %s!" % String(def["name"])}
	return {"ok": false, "msg": "Unknown item?!"}


func vent(vent_id: String) -> Dictionary:
	## Instant venting trade: spend serotonin to dump cortisol right now.
	var gs := get_parent()
	if not gs.sim_running:
		return {"ok": false, "msg": "Not right now."}
	for def in VENT_DEFS:
		if String(def["id"]) == vent_id:
			if float(vent_cooldowns.get(vent_id, 0.0)) > 0.0:
				return {"ok": false, "msg": "Still catching your breath…"}
			var cost := float(def["serotonin_cost"])
			if gs.serotonin < cost:
				return {"ok": false, "msg": "Need %d serotonin" % int(cost)}
			gs.serotonin = clampf(gs.serotonin - cost, 0.0, gs.METER_MAX)
			gs.cortisol = clampf(gs.cortisol - float(def["cortisol_dump"]), 0.0, gs.METER_MAX)
			vent_cooldowns[vent_id] = float(def["cooldown"])
			gs.meters_changed.emit(gs.serotonin, gs.cortisol)
			return {"ok": true, "msg": "Vented! -%d cortisol" % int(def["cortisol_dump"])}
	return {"ok": false, "msg": "Unknown vent?!"}


# --- HUD widgets ---------------------------------------------------------------

func build_hud_widgets(dock: VBoxContainer) -> void:
	# Sanity pips: hearts that empty out as meltdowns land.
	_sanity_label = Label.new()
	_sanity_label.add_theme_font_size_override("font_size", 22)
	_refresh_sanity_label()
	dock.add_child(_sanity_label)
	# Red vignette: a full-screen translucent red rect behind everything else
	# in the HUD canvas, alpha driven by cortisol in _process.
	_vignette = ColorRect.new()
	_vignette.color = Color(0.55, 0.02, 0.02, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_root: Node = dock.get_parent()
	hud_root.add_child(_vignette)
	hud_root.move_child(_vignette, 0)


func _refresh_sanity_label() -> void:
	if _sanity_label == null or not is_instance_valid(_sanity_label):
		return
	var pips := ""
	for i in MAX_SANITY_LIVES:
		pips += "❤️" if i < sanity_lives else "🖤"
	_sanity_label.text = "Sanity " + pips
