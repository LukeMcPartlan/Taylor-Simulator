extends Node
## Taylor Simulator — global simulation state (Autoload singleton).
##
## Godot conventions used in this file:
## - Autoload: this script is registered in project.godot under [autoload], so
##   Godot instantiates it once at startup before the main scene loads. It is
##   reachable from any other script by its name, `GameState` — like a singleton.
## - Signals: Godot's observer pattern. Nodes call `GameState.meters_changed.connect(_on_meters_changed)`
##   and Godot invokes that method whenever we call `meters_changed.emit(...)`.
## - `_ready()` runs once when the node enters the tree; `_process(delta)` runs
##   every rendered frame, with `delta` = real seconds since the previous frame.
## - `clampf` clamps a float; `%` string formatting works like printf.

# --- Signals ----------------------------------------------------------------
signal meters_changed(serotonin: float, cortisol: float)
signal clock_changed(time_string: String)
signal task_list_changed(tasks: Array)
signal day_ended
## Emitted when Luke (or anyone) says something; the HUD shows it in the dialogue box.
signal luke_said(speaker: String, line: String)

# --- Tuning -----------------------------------------------------------------
# One in-game hour = this many real seconds. A full 16h day = 16 * 30 = 480s (8 min).
const SECONDS_PER_GAME_HOUR: float = 30.0
const DAY_START_HOUR: float = 7.0    # 7:00 AM
const DAY_END_HOUR: float = 23.0     # 11:00 PM
const METER_MAX: float = 100.0

const START_SEROTONIN: float = 60.0
const START_CORTISOL: float = 30.0

# Neglect pressure, per incomplete task, per in-game hour.
# With 4 starter tasks: cortisol +24/h, serotonin -12/h while everything is ignored.
const CORTISOL_PER_TASK_PER_HOUR: float = 6.0
const SEROTONIN_DRAIN_PER_TASK_PER_HOUR: float = 3.0
# Serotonin always decays a little even with zero open tasks — living is hard.
const SEROTONIN_BASELINE_DECAY_PER_HOUR: float = 1.0

# How often the HUD gets meter updates (real seconds). Throttled so we don't
# redraw UI every frame; completion/fun/Luke events emit immediately anyway.
const METER_EMIT_THROTTLE: float = 0.25

# Task definitions. `day_min` = the first day this task can appear — later days
# add chores (escalation), so the sim gets harder the longer you survive.
const TASK_DEFS: Array = [
	{"id": "laundry", "label": "Do the laundry", "relief": 15.0, "day_min": 1},
	{"id": "dishes", "label": "Wash the dishes", "relief": 12.0, "day_min": 1},
	{"id": "feed_baby", "label": "Feed the baby", "relief": 18.0, "day_min": 1},
	{"id": "change_baby", "label": "Change the baby", "relief": 14.0, "day_min": 1},
	{"id": "basement_toilet", "label": "Clean the basement toilet", "relief": 20.0, "day_min": 1},
	{"id": "mop_kitchen", "label": "Mop the kitchen", "relief": 10.0, "day_min": 2},
	{"id": "take_out_trash", "label": "Take out the trash", "relief": 8.0, "day_min": 3},
	{"id": "microwave", "label": "Clean the microwave", "relief": 10.0, "day_min": 2},
]
# Registered dynamically when Luke starts gaming (see luke.gd).
const REMIND_LUKE_TASK: Dictionary = {
	"id": "remind_luke", "label": "Remind Luke to get back to work", "relief": 12.0,
}

# --- State ------------------------------------------------------------------
var serotonin: float = START_SEROTONIN
var cortisol: float = START_CORTISOL
var time_hours: float = DAY_START_HOUR  # float hours, 7.0 -> 23.0
var day_number: int = 0                 # incremented by start_new_day(); first day is 1
var tasks: Array = []                   # Array of Dictionaries: {id, label, cortisol_relief, done}
var sim_running: bool = true
# Escalation: each new day multiplies neglect pressure a little.
var day_pressure_mult: float = 1.0
# Serotonin integrated over game-hours — divided by day length for the day average.
var day_serotonin_integral: float = 0.0

var _meter_emit_cooldown: float = 0.0
var _last_clock_string: String = ""


func _ready() -> void:
	start_new_day()


func _process(delta: float) -> void:
	if not sim_running:
		return

	# Advance the clock.
	time_hours += delta / SECONDS_PER_GAME_HOUR
	if time_hours >= DAY_END_HOUR:
		time_hours = DAY_END_HOUR
		_emit_clock_if_changed()
		_end_day()
		return
	_emit_clock_if_changed()

	# Neglect pressure: each open task pushes cortisol up and serotonin down.
	var game_hours: float = delta / SECONDS_PER_GAME_HOUR
	var incomplete: int = 0
	for t in tasks:
		if not t["done"]:
			incomplete += 1
	if incomplete > 0:
		cortisol += CORTISOL_PER_TASK_PER_HOUR * day_pressure_mult * incomplete * game_hours
		serotonin -= SEROTONIN_DRAIN_PER_TASK_PER_HOUR * day_pressure_mult * incomplete * game_hours
	serotonin -= SEROTONIN_BASELINE_DECAY_PER_HOUR * game_hours

	serotonin = clampf(serotonin, 0.0, METER_MAX)
	cortisol = clampf(cortisol, 0.0, METER_MAX)
	day_serotonin_integral += serotonin * game_hours

	# Throttled broadcast.
	_meter_emit_cooldown -= delta
	if _meter_emit_cooldown <= 0.0:
		_meter_emit_cooldown = METER_EMIT_THROTTLE
		meters_changed.emit(serotonin, cortisol)


# --- Public API -------------------------------------------------------------

func register_task(id: String, label: String, cortisol_relief: float) -> void:
	## Adds a task, or updates it if `id` is already registered (idempotent, so
	## day restarts can re-register safely). Emits task_list_changed.
	for t in tasks:
		if t["id"] == id:
			t["label"] = label
			t["cortisol_relief"] = cortisol_relief
			task_list_changed.emit(tasks)
			return
	tasks.append({
		"id": id,
		"label": label,
		"cortisol_relief": cortisol_relief,
		"done": false,
	})
	task_list_changed.emit(tasks)


func complete_task(id: String) -> bool:
	## Marks a task done and applies its cortisol relief. Returns false if the
	## id is unknown or already done.
	for t in tasks:
		if t["id"] == id and not t["done"]:
			t["done"] = true
			cortisol = clampf(cortisol - float(t["cortisol_relief"]), 0.0, METER_MAX)
			task_list_changed.emit(tasks)
			meters_changed.emit(serotonin, cortisol)
			return true
	return false


func add_serotonin(amount: float) -> void:
	## Phase 2 hook: fun stations (reading, TikTok) call this.
	serotonin = clampf(serotonin + amount, 0.0, METER_MAX)
	meters_changed.emit(serotonin, cortisol)


func interact_luke() -> void:
	## Phase 3 stub. Real Luke gets wander AI + a dialogue tree; for now,
	## talking to him is equal parts joy and stress: both meters jump.
	serotonin = clampf(serotonin + 10.0, 0.0, METER_MAX)
	cortisol = clampf(cortisol + 10.0, 0.0, METER_MAX)
	meters_changed.emit(serotonin, cortisol)


func start_new_day() -> void:
	## Resets everything for a fresh 7am start and resumes the sim.
	## Later days hit harder: more tasks and a pressure multiplier.
	day_number += 1
	time_hours = DAY_START_HOUR
	serotonin = START_SEROTONIN
	cortisol = START_CORTISOL
	day_pressure_mult = 1.0 + 0.15 * float(day_number - 1)
	day_serotonin_integral = 0.0
	_last_clock_string = ""
	_meter_emit_cooldown = 0.0
	tasks.clear()
	_register_default_tasks()
	sim_running = true
	set_process(true)
	clock_changed.emit(get_time_string())
	task_list_changed.emit(tasks)
	meters_changed.emit(serotonin, cortisol)


func get_time_string() -> String:
	## Public read of the formatted clock ("7:00 AM", "11:00 PM", ...).
	return _format_time()


# Minigame variant hooks. Stations call these so variants can tune the
# minigame experience without touching station.gd:
# - get_minigame_speed_mult(): night-shift returns >1.0 with buffs (timers
#   get more forgiving). Base game: 1.0.
# - MINIGAME_FAIL_CORTISOL / minigame_fail_text(): meltdown punishes failed
#   minigames with +5 cortisol and a meaner message. Base: no punishment.
const MINIGAME_FAIL_CORTISOL: float = 0.0


func get_minigame_speed_mult() -> float:
	return 1.0


func minigame_fail_text() -> String:
	return "Failed! Press E to retry."


func apply_minigame_fail() -> void:
	if MINIGAME_FAIL_CORTISOL > 0.0:
		cortisol = clampf(cortisol + MINIGAME_FAIL_CORTISOL, 0.0, METER_MAX)
		meters_changed.emit(serotonin, cortisol)


func say(speaker: String, line: String) -> void:
	## Route a line of dialogue through GameState so the HUD can display it.
	## Keeps NPCs decoupled from UI: they don't need a reference to the HUD.
	luke_said.emit(speaker, line)


func get_day_summary() -> Dictionary:
	## End-of-day report card, read by the HUD when day_ended fires.
	var done: int = 0
	for t in tasks:
		if t["done"]:
			done += 1
	var day_length: float = DAY_END_HOUR - DAY_START_HOUR
	var avg_serotonin: float = day_serotonin_integral / maxf(day_length, 0.01)
	var rating: String = "Total meltdown"
	if avg_serotonin >= 70.0:
		rating = "Blessed day"
	elif avg_serotonin >= 50.0:
		rating = "Held it together"
	elif avg_serotonin >= 30.0:
		rating = "Rough one"
	return {
		"day": day_number,
		"tasks_done": done,
		"tasks_total": tasks.size(),
		"avg_serotonin": avg_serotonin,
		"rating": rating,
	}


# --- Internal ---------------------------------------------------------------

func _register_default_tasks() -> void:
	# Day 1 starts with the core five; mop and trash join on days 2 and 3.
	for def in TASK_DEFS:
		if day_number >= int(def["day_min"]):
			register_task(String(def["id"]), String(def["label"]), float(def["relief"]))


func _emit_clock_if_changed() -> void:
	# Only broadcast when the displayed minute actually changes (~2/sec at
	# default speed), not every frame.
	var clock_string := _format_time()
	if clock_string != _last_clock_string:
		_last_clock_string = clock_string
		clock_changed.emit(clock_string)


func _end_day() -> void:
	sim_running = false
	set_process(false)
	day_ended.emit()


func _format_time() -> String:
	var total_minutes: int = int(round(time_hours * 60.0))
	var h24: int = total_minutes / 60
	var m: int = total_minutes % 60
	var suffix: String = "AM" if h24 < 12 else "PM"
	var h12: int = h24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]
