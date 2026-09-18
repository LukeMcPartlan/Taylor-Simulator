extends Node
## Taylor Simulator (UNIFIED) — global simulation state (Autoload singleton).
##
## This is the base day-loop sim (meters, clock, tasks) PLUS a mode-hook
## system: each of the 5 game modes is a "mode node" (see scripts/modes/)
## created by ModeManager. GameState asks the mode node for tuning values
## through small hook methods; when no mode is active (CLASSIC) the base
## defaults apply, so this file behaves exactly like the original base game.
##
## Hook methods a mode node MAY implement (all optional; GameState checks
## with has_method() and falls back to the base default):
##   seconds_per_game_hour() -> float      default 30.0
##   neglect_cortisol_rate() -> float      default 6.0
##   neglect_serotonin_rate() -> float     default 3.0
##   baseline_decay_rate() -> float        default 1.0
##   cortisol_gain_mult() -> float         default 1.0
##   minigame_speed_mult() -> float        default 1.0
##   minigame_fail_cortisol() -> float     default 0.0
##   minigame_fail_text() -> String        default "Failed! Press E to retry."
##   day_summary_extras() -> Dictionary    default {}
##   hud_tag() -> String                   default "" (shown under the clock)
## Mode nodes can also connect to GameState's signals for their own logic
## (e.g. babysitter ticks, meltdown checks, combo scoring). Note: GameState
## _ready() runs start_new_day() BEFORE the mode node's _ready() connects, so
## mode nodes must initialize day-1 state explicitly (see combo-mom's scorer).
##
## Godot conventions used in this file:
## - Autoload: registered in project.godot under [autoload]; instantiated once
##   at startup. Reachable everywhere by its name, `GameState`.
## - Signals: Godot's observer pattern. `x.connect(_on_x)` subscribes;
##   `x.emit(...)` notifies.
## - `clampf` clamps a float; `%` string formatting works like printf.

# --- Signals ----------------------------------------------------------------
signal meters_changed(serotonin: float, cortisol: float)
signal clock_changed(time_string: String)
signal task_list_changed(tasks: Array)
signal day_ended
## Emitted when Luke (or anyone) says something; the HUD shows it in the dialogue box.
signal luke_said(speaker: String, line: String)
## Arcade/extended hooks. Emitted in every mode; only some modes listen.
signal task_completed(task_id: String, cortisol_relief: float, by: String)
signal fun_used(amount: float)
signal day_started(day: int)
signal minigame_failed
## Emitted when a mode ends the whole run (night-shift meltdown at 100
## cortisol, meltdown mode's third strike). The HUD shows the overlay with
## this title/stats instead of the normal day-over panel.
signal run_ended(title: String, stats: String, restart_kind: String)

# --- Tuning (base defaults; modes override via hooks) -----------------------
const SECONDS_PER_GAME_HOUR: float = 30.0
const DAY_START_HOUR: float = 7.0    # 7:00 AM
const DAY_END_HOUR: float = 23.0     # 11:00 PM
const METER_MAX: float = 100.0  # caps CORTISOL only; serotonin is intentionally uncapped

const START_SEROTONIN: float = 60.0
const START_CORTISOL: float = 30.0

const CORTISOL_PER_TASK_PER_HOUR: float = 6.0
const SEROTONIN_DRAIN_PER_TASK_PER_HOUR: float = 3.0
const SEROTONIN_BASELINE_DECAY_PER_HOUR: float = 1.0

const METER_EMIT_THROTTLE: float = 0.25

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
const REMIND_LUKE_TASK: Dictionary = {
	"id": "remind_luke", "label": "Remind Luke to get back to work", "relief": 12.0,
}

# --- State ------------------------------------------------------------------
var serotonin: float = START_SEROTONIN
var cortisol: float = START_CORTISOL
var time_hours: float = DAY_START_HOUR
var day_number: int = 0
# Task dicts: {id, label, cortisol_relief, done, delegated, completed_by}.
# `delegated`/`completed_by` only matter in DELEGATION mode; harmless elsewhere.
var tasks: Array = []
var sim_running: bool = true
var day_pressure_mult: float = 1.0
var day_serotonin_integral: float = 0.0
## The active mode node (null in CLASSIC). Created from ModeManager.
var mode_hook: Node = null

var _meter_emit_cooldown: float = 0.0
var _last_clock_string: String = ""


func _ready() -> void:
	# ModeManager is autoloaded BEFORE GameState, so current_mode is valid here.
	mode_hook = ModeManager.create_mode()
	if mode_hook != null:
		add_child(mode_hook)
	start_new_day()


## Returns the active mode node (null in CLASSIC). Mode UIs and NPCs use
## this to reach mode-specific APIs, e.g.:
##   var m := GameState.mode_node()
##   if m is ModeDelegation: m.try_delegate(id)
func mode_node() -> Node:
	return mode_hook


func _process(delta: float) -> void:
	if not sim_running:
		return

	var sec_per_hour: float = get_seconds_per_game_hour()
	time_hours += delta / sec_per_hour
	if time_hours >= DAY_END_HOUR:
		time_hours = DAY_END_HOUR
		_emit_clock_if_changed()
		_end_day()
		return
	_emit_clock_if_changed()

	var game_hours: float = delta / sec_per_hour
	var pressure: float = 0.0
	for t in tasks:
		if not t["done"]:
			pressure += get_neglect_weight(String(t["id"]))
	if pressure > 0.0:
		cortisol += get_neglect_cortisol_rate() * get_cortisol_gain_mult() \
			* day_pressure_mult * pressure * game_hours
		serotonin -= get_neglect_serotonin_rate() * get_serotonin_drain_mult() \
			* day_pressure_mult * pressure * game_hours
	serotonin -= get_baseline_decay_rate() * get_serotonin_drain_mult() * game_hours

	serotonin = maxf(serotonin, 0.0)  # serotonin is UNCAPPED: bank it for expensive store items
	cortisol = clampf(cortisol, 0.0, METER_MAX)
	day_serotonin_integral += serotonin * game_hours

	_meter_emit_cooldown -= delta
	if _meter_emit_cooldown <= 0.0:
		_meter_emit_cooldown = METER_EMIT_THROTTLE
		meters_changed.emit(serotonin, cortisol)


# --- Mode hook queries (base defaults; mode nodes override) -----------------

func _hook(method: String, args: Array = []):
	if mode_hook != null and mode_hook.has_method(method):
		return mode_hook.callv(method, args)
	return null


func get_seconds_per_game_hour() -> float:
	var v = _hook("seconds_per_game_hour")
	return float(v) if v != null else SECONDS_PER_GAME_HOUR


func get_neglect_cortisol_rate() -> float:
	var v = _hook("neglect_cortisol_rate")
	return float(v) if v != null else CORTISOL_PER_TASK_PER_HOUR


func get_neglect_serotonin_rate() -> float:
	var v = _hook("neglect_serotonin_rate")
	return float(v) if v != null else SEROTONIN_DRAIN_PER_TASK_PER_HOUR


func get_baseline_decay_rate() -> float:
	var v = _hook("baseline_decay_rate")
	return float(v) if v != null else SEROTONIN_BASELINE_DECAY_PER_HOUR


func get_cortisol_gain_mult() -> float:
	var v = _hook("cortisol_multiplier")
	return float(v) if v != null else 1.0


func get_last_award() -> Dictionary:
	## Combo-mom's last points award {"points", "mult"} for "+N PTS (xM)" popups.
	var v = _hook("get_last_award")
	if v is Dictionary:
		return v
	return {"points": 0, "mult": 1}


func record_minigame_clear(game_id: String, elapsed_seconds: float) -> int:
	## Clear-time scoring (combo-mom): beating a minigame's par time extends
	## the combo window and awards Taylor Points. Returns bonus points.
	var v = _hook("record_minigame_clear", [game_id, elapsed_seconds])
	return int(v) if v != null else 0


func get_move_speed_mult() -> float:
	## Scales Taylor's move speed (combo-mom's Comfy Shoes 1.15x).
	var v = _hook("move_speed_multiplier")
	return float(v) if v != null else 1.0


func get_neglect_weight(task_id: String) -> float:
	## How much neglect pressure one open task exerts (delegation mode halves
	## some with upgrades). Queried per task every frame.
	var v = _hook("neglect_weight", [task_id])
	return float(v) if v != null else 1.0


func get_task_relief_mult() -> float:
	## Scales chore cortisol relief (meltdown's Gym Membership 1.25x).
	var v = _hook("task_relief_multiplier")
	return float(v) if v != null else 1.0


func get_fun_mult() -> float:
	## Scales serotonin gains from fun stations (night-shift Gremlin Mode 2x).
	var v = _hook("fun_multiplier")
	return float(v) if v != null else 1.0


func get_serotonin_drain_mult() -> float:
	## Scales serotonin DRAINS (night-shift Weighted Blanket 0.75x).
	var v = _hook("serotonin_drain_multiplier")
	return float(v) if v != null else 1.0


func get_minigame_speed_mult() -> float:
	var v = _hook("minigame_speed_mult")
	return float(v) if v != null else 1.0


func get_minigame_fail_cortisol() -> float:
	var v = _hook("minigame_fail_cortisol")
	return float(v) if v != null else 0.0


func minigame_fail_text() -> String:
	var v = _hook("minigame_fail_text")
	return String(v) if v != null else "Failed! Press E to retry."


func get_hud_tag() -> String:
	var v = _hook("hud_tag")
	return String(v) if v != null else ""


# --- Public API -------------------------------------------------------------

func register_task(id: String, label: String, cortisol_relief: float) -> void:
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
		"delegated": false,
		"completed_by": "",
	})
	task_list_changed.emit(tasks)


func complete_task(id: String, by: String = "taylor") -> bool:
	## Marks a task done, records WHO did it, applies cortisol relief.
	for t in tasks:
		if t["id"] == id and not t["done"]:
			t["done"] = true
			t["delegated"] = false
			t["completed_by"] = by
			var relief: float = float(t["cortisol_relief"]) * get_task_relief_mult()
			cortisol = clampf(cortisol - relief, 0.0, METER_MAX)
			task_list_changed.emit(tasks)
			meters_changed.emit(serotonin, cortisol)
			task_completed.emit(id, relief, by)
			return true
	return false


func add_serotonin(amount: float) -> void:
	# No upper cap on serotonin (cortisol stays capped at METER_MAX).
	serotonin = maxf(serotonin + amount, 0.0)
	meters_changed.emit(serotonin, cortisol)
	fun_used.emit(amount)


func add_cortisol(amount: float) -> void:
	## All cortisol GAINS route through here so modes can scale them
	## (e.g. night-shift Headphones, meltdown coping items).
	cortisol = clampf(cortisol + amount * get_cortisol_gain_mult(), 0.0, METER_MAX)
	meters_changed.emit(serotonin, cortisol)


func interact_luke() -> void:
	## Talking to Luke: +10 joy AND +10 stress.
	add_serotonin(10.0)
	add_cortisol(10.0)


func interact_luke_mean() -> void:
	## MELTDOWN mode: when cortisol is over 70 Luke drops the act and roasts
	## you. Still funny (+10 serotonin) but it stings (+15 cortisol).
	add_serotonin(10.0)
	add_cortisol(15.0)


func apply_minigame_fail() -> void:
	var penalty: float = get_minigame_fail_cortisol()
	if penalty > 0.0:
		cortisol = clampf(cortisol + penalty, 0.0, METER_MAX)
		meters_changed.emit(serotonin, cortisol)
	minigame_failed.emit()


func start_new_day() -> void:
	day_number += 1
	_begin_day()


func _begin_day() -> void:
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
	day_started.emit(day_number)


func get_time_string() -> String:
	return _format_time()


func say(speaker: String, line: String) -> void:
	luke_said.emit(speaker, line)


func get_day_summary() -> Dictionary:
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
	var summary := {
		"day": day_number,
		"tasks_done": done,
		"tasks_total": tasks.size(),
		"avg_serotonin": avg_serotonin,
		"rating": rating,
	}
	# Modes can inject extra lines (e.g. combo-mom's score).
	var extras = _hook("day_summary_extras")
	if extras is Dictionary:
		for k in (extras as Dictionary).keys():
			summary[k] = (extras as Dictionary)[k]
	return summary


# --- Internal ---------------------------------------------------------------

func _register_default_tasks() -> void:
	for def in TASK_DEFS:
		if day_number >= int(def["day_min"]):
			register_task(String(def["id"]), String(def["label"]), float(def["relief"]))


func _emit_clock_if_changed() -> void:
	var clock_string := _format_time()
	if clock_string != _last_clock_string:
		_last_clock_string = clock_string
		clock_changed.emit(clock_string)


func _end_day() -> void:
	sim_running = false
	set_process(false)
	day_ended.emit()


func end_run(title: String, stats: String, restart_kind: String = "run") -> void:
	## A mode ends the whole RUN (not just the day). Same freeze as _end_day,
	## but the HUD shows the run-over panel instead of the day-over one.
	## restart_kind: "run" = R starts a fresh run from day 1 (night-shift
	## meltdown, meltdown x3); "day" = R retries the SAME day (meltdown's
	## non-fatal meltdowns, lives and coping kept).
	sim_running = false
	set_process(false)
	run_ended.emit(title, stats, restart_kind)


func new_run() -> void:
	## Start a fresh run in the current mode: reset the day counter, let the
	## mode clear its run-long state, then start day 1.
	day_number = 0
	_hook("reset_run")
	start_new_day()


func retry_day() -> void:
	## Restart the CURRENT day (meltdown mode): clock/tasks/meters reset,
	## day_number kept, mode keeps its run-long state (lives, coping items).
	_begin_day()


func _format_time() -> String:
	var total_minutes: int = int(round(time_hours * 60.0))
	var h24: int = total_minutes / 60
	var m: int = total_minutes % 60
	var suffix: String = "AM" if h24 < 12 else "PM"
	var h12: int = h24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]
