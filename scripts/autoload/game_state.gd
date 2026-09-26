extends Node
## Taylor Simulator (UNIFIED) — global simulation state (Autoload singleton).
##
## This is the base day-loop sim (meters, clock, tasks) PLUS a mode-hook
## system: each of the 6 game modes is a "mode node" (see scripts/modes/)
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
##   start_cortisol() -> float             default START_CORTISOL (practice: 0)
##   minigames_always_open() -> bool       default false (practice: stations
##     always playable, never dim)
##   minigame_speed_mult() -> float        default 1.0
##   minigame_fail_cortisol() -> float     default 0.0
##   minigame_fail_text() -> String        default "Failed! Press E to retry."
##   task_auto_covered(task_id) -> bool    default false (proc scheduler skips
##     procs for fully automated chores)
##   day_summary_extras() -> Dictionary    default {}
##   hud_tag() -> String                   default "" (shown under the clock)
## Mode nodes can also connect to GameState's signals for their own logic
## (custom per-mode logic). Note: GameState _ready() runs start_new_day()
## BEFORE the mode node's _ready() connects, so mode nodes must initialize
## day-1 state explicitly.
##
## Godot conventions used in this file:
## - Autoload: registered in project.godot under [autoload]; instantiated once
##   at startup. Reachable everywhere by its name, `GameState`.
## - Signals: Godot's observer pattern. `x.connect(_on_x)` subscribes;
##   `x.emit(...)` notifies.
## - `clampf` clamps a float; `%` string formatting works like printf.

# --- Signals ----------------------------------------------------------------
signal meters_changed(serotonin: float, cortisol: float)
signal dopamine_changed(value: float)
signal dollars_changed(dollars: float)
signal savings_changed(savings: float)
signal clock_changed(time_string: String)
signal task_list_changed(tasks: Array)
## Emitted each time open tasks generate cortisol (discrete pressure tick);
## the HUD flashes a "+x cortisol" indicator next to the task list.
signal cortisol_tick(amount: float)
signal day_ended
## Emitted when Luke (or anyone) says something; the HUD shows it in the dialogue box.
signal luke_said(speaker: String, line: String)
## Arcade/extended hooks. Emitted in every mode; only some modes listen.
signal task_completed(task_id: String, cortisol_relief: float, by: String)
signal fun_used(amount: float)
signal day_started(day: int)
signal minigame_failed
## Emitted when a chore procs (becomes active) during the day.
signal task_procced(task_id: String)
## Emitted when a mode ends the whole run (e.g. dopamine hitting 0).
## The HUD shows the overlay with this title/stats instead of the normal
## day-over panel.
signal run_ended(title: String, stats: String, restart_kind: String)

# --- Tuning (base defaults; modes override via hooks) -----------------------
const SECONDS_PER_GAME_HOUR: float = 15.0
const DAY_START_HOUR: float = 6.0    # 6:00 AM — Luke needs waking at 6
const DAY_END_HOUR: float = 23.0     # 11:00 PM — shops close, late night begins
const BEDTIME_HOUR: float = 21.0     # 9:00 PM — the "Go to bed" chore spawns
const DAY_LATEST_HOUR: float = 25.0  # 1:00 AM — up-all-night forced day end
const METER_MAX: float = 100.0  # caps CORTISOL only; serotonin is intentionally uncapped

const START_SEROTONIN: float = 60.0
const START_CORTISOL: float = 30.0
## Serotonin granted whenever TAYLOR personally completes a task. Delegated /
## auto completions (robots, Luke, babysitter) keep cortisol relief only.
const TASK_COMPLETION_SEROTONIN: float = 8.0
## Dopamine: the third meter. Starts full, drains over the day, and the
## phone tops it back up. Hitting zero ends the day on the spot — same
## severity as maxing cortisol. Tuning lives here; balance in playtesting.
const START_DOPAMINE: float = 100.0
const MAX_DOPAMINE: float = 100.0
const DOPAMINE_DRAIN_PER_HOUR: float = 4.0
## A run is 7 in-game days. Day 7's end completes the run: leftover dollars
## sweep to savings and the run-over screen shows. (Practice opts out via
## the endless_run hook — the sandbox never ends.)
const RUN_LENGTH_DAYS: int = 7

const CORTISOL_PER_TASK_PER_HOUR: float = 3.0
const SEROTONIN_DRAIN_PER_TASK_PER_HOUR: float = 3.0
const SEROTONIN_BASELINE_DECAY_PER_HOUR: float = 1.0

# --- Task proc scheduler tuning ------------------------------------------------
# One random chore procs every few REAL seconds (not game-hours, so pacing is
# identical across modes). Each def has its own daily cap (max_procs); once a
# task hits its cap it can't proc again until tomorrow. Ticks only activate a
# task that isn't already open — an open chore just sits there generating
# cortisol at its flat rate (see pressure ticks below), it never double-procs.
const PROC_TICK_MIN_S: float = 3.0
const PROC_TICK_MAX_S: float = 8.0
const PROC_MAX_PER_DAY: int = 3

# --- Cortisol pressure ticks ------------------------------------------------------
# Open tasks push cortisol up in discrete ticks every CORTISOL_TICK_SECONDS
# (real seconds), not continuously — each tick emits cortisol_tick(amount) so
# the HUD can flash a "+x cortisol" indicator next to the task list. Every
# open task generates a FLAT rate: its neglect weight (get_neglect_weight)
# times CORTISOL_PER_TASK_PER_HOUR. No escalation over time.
const CORTISOL_TICK_SECONDS: float = 3.0

# --- Fixed-clock tasks ----------------------------------------------------------
# These proc at fixed clock times instead of through the random proc
# scheduler (nobody procs "wake up Luke" at a random hour). Fired once per
# day when the clock crosses the hour.
const CLOCK_TASKS: Array = [
	{"hour": 6.0, "id": "wake_luke", "label": "Wake up Luke", "relief": 12.0},
	{"hour": 7.0, "id": "wake_chris", "label": "Wake up Chris", "relief": 12.0},
	{"hour": 21.0, "id": "go_to_bed", "label": "Go to bed", "relief": 0.0},
	{"hour": 22.0, "id": "bed_luke", "label": "Put Luke to bed", "relief": 12.0},
]
var _clock_tasks_fired: Dictionary = {}  # task id -> day_number


func _check_clock_tasks() -> void:
	for def in CLOCK_TASKS:
		var id := String(def["id"])
		if int(_clock_tasks_fired.get(id, -1)) == day_number:
			continue
		if time_hours >= float(def["hour"]):
			_clock_tasks_fired[id] = day_number
			register_task(id, String(def["label"]), float(def["relief"]))

# --- One-time bird collectibles ------------------------------------------------
# One fixed species per real mode (GameState.MODE_BIRDS; the five Bird nodes
# live in Main.tscn). Touching a species collects it FOREVER: +50 serotonin
# cap, banked in the save.
const BIRD_IDS: Array = ["robin", "crow", "bluejay", "pigeon", "owl"]
const BIRD_REWARD_SEROTONIN: float = 50.0

const METER_EMIT_THROTTLE: float = 0.25

# Built-in chore defs. Each def is modular: id / label / relief / day_min plus
# optional overrides (max_procs — see the PROC_* defaults above). New tasks
# are added at runtime with register_task_def(); no core-logic edits needed.
const TASK_DEFS: Array = [
	{"id": "laundry", "label": "Do the laundry", "relief": 15.0, "day_min": 1, "max_procs": 3},
	{"id": "dishes", "label": "Wash the dishes", "relief": 12.0, "day_min": 1, "max_procs": 3},
	{"id": "feed_baby", "label": "Feed the baby", "relief": 18.0, "day_min": 1, "max_procs": 3},
	{"id": "change_baby", "label": "Change the baby", "relief": 14.0, "day_min": 1, "max_procs": 3},
	{"id": "basement_toilet", "label": "Clean the basement toilet", "relief": 20.0, "day_min": 1, "max_procs": 3},
	{"id": "take_out_trash", "label": "Take out the trash", "relief": 8.0, "day_min": 3, "max_procs": 3},
	{"id": "microwave", "label": "Clean the microwave", "relief": 10.0, "day_min": 2, "max_procs": 3},
	{"id": "amazon_boxes", "label": "Break down the Amazon boxes", "relief": 12.0, "day_min": 1, "max_procs": 3},
]
const REMIND_LUKE_TASK: Dictionary = {
	"id": "remind_luke", "label": "Remind Luke to get back to work", "relief": 12.0,
}

# --- State ------------------------------------------------------------------
var serotonin: float = START_SEROTONIN
var cortisol: float = START_CORTISOL
var dopamine: float = START_DOPAMINE
var dollars: float = 0.0  # earned at the work laptop; swept into savings at day end
## Savings account: global, persists across days AND runs. Leftover dollars
## sweep here at day end; spent in the main-menu shop on permanent upgrades.
var savings: float = 0.0
## Permanent upgrades owned forever: upgrade id -> tier (1-3). Bought with
## savings in the main-menu shop. In-run tiers stack via upgrade_tier().
var permanent_upgrades: Dictionary = {}
const SAVINGS_PATH := "user://taylor_savings.cfg"
## Master volume 0.0-1.0 (options menu slider). No SFX exist yet — this is
## stored for later, and applied to the Master bus live when SFX land.
signal volume_changed(volume: float)
var volume: float = 1.0
## Mode unlocks: PRACTICE is always open; CLASSIC is bought with dollars at
## the practice laptop; every other mode is locked for now. Persisted in the
## bank file alongside savings.
var unlocked_modes: Array = []


## PRACTICE is the front door (always unlocked). CLASSIC and DOPAMINE unlock
## once bought in the practice store. Everything else is locked for now.
func is_mode_unlocked(mode: int) -> bool:
	if mode == ModeManager.Mode.PRACTICE:
		return true
	if mode == ModeManager.Mode.CLASSIC:
		return mode in unlocked_modes
	if mode == ModeManager.Mode.DOPAMINE:
		return mode in unlocked_modes
	return false


func unlock_mode(mode: int) -> void:
	if mode in unlocked_modes:
		return
	unlocked_modes.append(mode)
	save_bank()
## Base serotonin cap. Collectible upgrades (raquaza, kh_boxset) raise it.
const BASE_SEROTONIN_CAP := 200.0
const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")
var time_hours: float = DAY_START_HOUR
var day_number: int = 0
# Task dicts: {id, label, cortisol_relief, done, delegated, completed_by}.
# `delegated`/`completed_by` are inert data (kept for save compatibility).
var tasks: Array = []
## All known task defs: built-in TASK_DEFS plus anything added at runtime via
## register_task_def(). The proc scheduler only manages defs listed here;
## dynamically registered tasks (Luke's remind_luke) bypass the scheduler
## entirely.
var task_defs: Array = TASK_DEFS.duplicate(true)
## Per-def successful proc counts today: id -> int. Reset every day.
var _proc_state: Dictionary = {}
## Countdown (real seconds) to the next global proc tick.
var _next_proc_in_s: float = 0.0
## Accumulator (real seconds) for the discrete cortisol pressure ticks.
var _cortisol_tick_t: float = 0.0
## One-time bird collectibles: species ids found EVER (persisted in the
## bank). Touching a bird collects it once; afterwards it's yours forever.
var birds_found: Array = []
## Each real game mode has one fixed bird species (its collectible).
## PRACTICE (5) has the robin; DOPAMINE (6) shares the robin too.
## ModeManager.Mode ints: CLASSIC 0, PRACTICE 5, DOPAMINE 6.
const MODE_BIRDS := {0: "robin", 5: "robin", 6: "robin"}
var sim_running: bool = true
var day_pressure_mult: float = 1.0
var day_serotonin_integral: float = 0.0
## Why the current day ended: "" = reached 11pm, "cortisol" = hit 100 cortisol,
## "dopamine" = hit 0 dopamine.
var _day_end_reason: String = ""
## The active mode node (null in CLASSIC). Created from ModeManager.
var mode_hook: Node = null

var _meter_emit_cooldown: float = 0.0
var _last_clock_string: String = ""


func _ready() -> void:
	# Load the global savings account before the mode is created, so modes
	# can migrate old saves against permanent_upgrades in their _ready().
	load_bank()
	# ModeManager is autoloaded BEFORE GameState, so current_mode is valid here.
	mode_hook = ModeManager.create_mode()
	if mode_hook != null:
		add_child(mode_hook)
	start_new_day()


## Returns the active mode node (null in CLASSIC). Mode UIs and NPCs use
## this to reach mode-specific APIs, e.g.:
##   var m := GameState.mode_node()
##   if m != null and m.has_method("run_tier"): m.run_tier(id)
func mode_node() -> Node:
	return mode_hook


func _process(delta: float) -> void:
	if not sim_running:
		return

	var sec_per_hour: float = get_seconds_per_game_hour()
	time_hours += delta / sec_per_hour
	if time_hours >= DAY_LATEST_HOUR:
		# Up all night: 1 AM without going to bed wipes serotonin and
		# ends the day on the spot — same severity as maxing cortisol.
		time_hours = DAY_LATEST_HOUR
		_emit_clock_if_changed()
		serotonin = 0.0
		_day_end_reason = "past_bedtime"
		_wipe_run_dollars()
		_end_day()
		return
	_emit_clock_if_changed()

	_update_task_procs(delta)
	_check_clock_tasks()

	# --- Cortisol pressure ticks ------------------------------------------------
	# Discrete ticks (see consts above): each open task adds its flat rate,
	# and cortisol_tick(amount) tells the HUD to flash "+x cortisol".
	_cortisol_tick_t += delta
	while _cortisol_tick_t >= CORTISOL_TICK_SECONDS:
		_cortisol_tick_t -= CORTISOL_TICK_SECONDS
		_fire_cortisol_tick(sec_per_hour)

	var game_hours: float = delta / sec_per_hour

	serotonin = maxf(serotonin, 0.0)  # nothing drains serotonin passively
	cortisol = clampf(cortisol, 0.0, METER_MAX)
	# Standard rule, every mode: nothing drains serotonin any more — open
	# tasks only ever push cortisol UP. But 100 cortisol ends the day on the
	# spot with serotonin zeroed. (A mode node may intercept this with its
	# own flow via the intercept_cortisol_max hook.)
	if cortisol >= METER_MAX and not _hook("intercept_cortisol_max"):
		serotonin = 0.0
		_day_end_reason = "cortisol"
		_wipe_run_dollars()
		_end_day()
		return
	# Dopamine drains over the day; the phone tops it back up. Hitting zero
	# ends the day on the spot — same severity as maxing cortisol.
	# (Dopamine Mode multiplies the drain 5x via the dopamine_drain_mult hook.)
	dopamine = clampf(dopamine - DOPAMINE_DRAIN_PER_HOUR * _dopamine_drain_mult() * game_hours, 0.0, MAX_DOPAMINE)
	if dopamine <= 0.0:
		_day_end_reason = "dopamine"
		_wipe_run_dollars()
		_end_day()
		return
	day_serotonin_integral += serotonin * game_hours

	_meter_emit_cooldown -= delta
	if _meter_emit_cooldown <= 0.0:
		_meter_emit_cooldown = METER_EMIT_THROTTLE
		meters_changed.emit(serotonin, cortisol)
		dopamine_changed.emit(dopamine)


# --- Mode hook queries (base defaults; mode nodes override) -----------------

func _hook(method: String, args: Array = []):
	if mode_hook != null and mode_hook.has_method(method):
		return mode_hook.callv(method, args)
	return null


func get_seconds_per_game_hour() -> float:
	var v = _hook("seconds_per_game_hour")
	return float(v) if v != null else SECONDS_PER_GAME_HOUR


func _dopamine_drain_mult() -> float:
	## Dopamine drain multiplier. Dopamine Mode returns 5.0; everything
	## else drains at the base rate.
	var v = _hook("dopamine_drain_mult")
	return float(v) if v != null else 1.0


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


func get_start_cortisol() -> float:
	## Practice mode starts the day at 0 cortisol instead of START_CORTISOL.
	var v = _hook("start_cortisol")
	return float(v) if v != null else START_CORTISOL


func get_start_serotonin() -> float:
	## Practice mode starts the day at 0 serotonin instead of
	## START_SEROTONIN — earn it before working the laptop.
	var v = _hook("start_serotonin")
	return float(v) if v != null else START_SEROTONIN


func minigames_always_open() -> bool:
	## Practice mode: every station's minigame is playable on E, no open
	## task required.
	var v = _hook("minigames_always_open")
	return v is bool and bool(v)


func get_last_award() -> Dictionary:
	## Combo-mom's last points award {"points", "mult"} for "+N PTS (xM)" popups.
	var v = _hook("get_last_award")
	if v is Dictionary:
		return v
	return {"points": 0, "mult": 1}


func record_minigame_clear(game_id: String, elapsed_seconds: float) -> int:
	## Clear-time scoring hook: a mode may award bonus points for beating a
	## minigame's par time. Returns bonus points.
	var v = _hook("record_minigame_clear", [game_id, elapsed_seconds])
	return int(v) if v != null else 0


func get_move_speed_mult() -> float:
	## Scales Taylor's move speed (a mode may raise it via upgrades).
	var v = _hook("move_speed_multiplier")
	return float(v) if v != null else 1.0


func _fire_cortisol_tick(sec_per_hour: float) -> void:
	## One discrete pressure tick: every open task generates its FLAT rate
	## (neglect weight x per-task hourly rate x tick length in game-hours),
	## scaled by the mode's cortisol hooks and the day pressure multiplier.
	## Emits cortisol_tick(amount) so the HUD can flash "+x cortisol".
	var tick_hours: float = CORTISOL_TICK_SECONDS / sec_per_hour
	var task_hours: float = 0.0
	for t in tasks:
		if not t["done"]:
			task_hours += get_neglect_weight(String(t["id"])) * tick_hours
	if task_hours <= 0.0:
		return
	var amt: float = get_neglect_cortisol_rate() * get_cortisol_gain_mult() \
		* day_pressure_mult * task_hours
	if amt <= 0.0:
		return
	cortisol = clampf(cortisol + amt, 0.0, METER_MAX)
	cortisol_tick.emit(amt)


func get_neglect_weight(task_id: String) -> float:
	## FLAT neglect weight of one open task. Queried per task every pressure tick.
	var v = _hook("neglect_weight", [task_id])
	return float(v) if v != null else 1.0


func get_task_neglect_mult(_task: Dictionary) -> float:
	## Flat now (was: escalation multiplier growing the longer a task sat
	## open). Kept returning 1.0 for compatibility.
	return 1.0


func get_task_relief_mult() -> float:
	## Scales chore cortisol relief.
	var v = _hook("task_relief_multiplier")
	return float(v) if v != null else 1.0


func get_fun_mult() -> float:
	## Scales serotonin gains from fun stations.
	var v = _hook("fun_multiplier")
	return float(v) if v != null else 1.0


func get_serotonin_drain_mult() -> float:
	## Scales serotonin DRAINS (stores/vents spend serotonin).
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
		# Each task generates cortisol at a flat rate while open.
		"open_since_h": time_hours,
	})
	task_list_changed.emit(tasks)


## Modular task defs ---------------------------------------------------------
## A task def is a Dictionary with required keys "id" and "label", plus
## optional tuning (defaults shown):
##   relief: 10.0     cortisol relief when the chore's minigame is won
##   day_min: 1       first day this task may proc
##   max_procs: 5     daily cap on successful activations
## The global proc tick (every PROC_TICK_MIN_S..PROC_TICK_MAX_S real seconds)
## picks one random eligible def — day unlocked, under its daily cap, not
## already open, not auto-covered by a mode — and activates it.
## Example:
##   GameState.register_task_def({"id": "walk_dog", "label": "Walk the dog",
##       "relief": 12.0, "max_procs": 3})
## A chore also needs a station to be completable — see
## World.register_station_def() (station_id must match the task id).
## Same id twice = upsert: the def is replaced (handy for re-tuning).
func register_task_def(def: Dictionary) -> bool:
	if not def.has("id") or not def.has("label"):
		push_error("GameState.register_task_def: def needs 'id' and 'label'.")
		return false
	var id := String(def["id"])
	var full := {
		"id": id,
		"label": String(def["label"]),
		"relief": float(def.get("relief", 10.0)),
		"day_min": int(def.get("day_min", 1)),
		"max_procs": int(def.get("max_procs", PROC_MAX_PER_DAY)),
	}
	for i in task_defs.size():
		if String(task_defs[i]["id"]) == id:
			task_defs[i] = full
			_proc_state[id] = int(_proc_state.get(id, 0))
			return true
	task_defs.append(full)
	_proc_state[id] = int(_proc_state.get(id, 0))
	return true


## Read-only view of all known task defs (built-in + registered).
func get_task_defs() -> Array:
	return task_defs.duplicate(true)


func _get_task_def(id: String) -> Dictionary:
	for def in task_defs:
		if String(def["id"]) == id:
			return def
	return {}


func _is_task_open(id: String) -> bool:
	for t in tasks:
		if String(t["id"]) == id:
			return not bool(t["done"])
	return false


# --- Task proc scheduler ------------------------------------------------------
# One global tick (every few real seconds) activates a single random eligible
# task. Eligibility: day unlocked, under its daily cap, not already open, not
# auto-covered by a mode. Only successful activations count against the cap.

func _reset_proc_state() -> void:
	_proc_state.clear()
	for def in task_defs:
		_proc_state[String(def["id"])] = 0
	_next_proc_in_s = randf_range(PROC_TICK_MIN_S, PROC_TICK_MAX_S)


func _update_task_procs(delta: float) -> void:
	# PRACTICE mode: the full list opened at dawn — nothing left to proc,
	# and completed tasks stay done all day.
	var no_proc = _hook("disable_task_procs")
	if no_proc is bool and bool(no_proc):
		return
	_next_proc_in_s -= delta
	if _next_proc_in_s > 0.0:
		return
	_next_proc_in_s = randf_range(PROC_TICK_MIN_S, PROC_TICK_MAX_S)
	var candidates: Array = []
	for def in task_defs:
		var id := String(def["id"])
		if day_number < int(def.get("day_min", 1)):
			continue
		if int(_proc_state.get(id, 0)) >= int(def.get("max_procs", PROC_MAX_PER_DAY)):
			continue
		if _is_task_open(id):
			continue
		# Optional mode hook: fully automated chores never proc.
		var auto = _hook("task_auto_covered", [id])
		if auto is bool and bool(auto):
			continue
		candidates.append(def)
	if candidates.is_empty():
		return
	var picked: Dictionary = candidates[randi_range(0, candidates.size() - 1)]
	_activate_task(picked)
	var picked_id := String(picked["id"])
	_proc_state[picked_id] = int(_proc_state.get(picked_id, 0)) + 1


func _activate_task(def: Dictionary) -> void:
	var id := String(def["id"])
	var label := String(def.get("label", id))
	var relief := float(def.get("relief", 10.0))
	for t in tasks:
		if String(t["id"]) == id:
			# Re-proc: flip a completed task back open.
			t["done"] = false
			t["delegated"] = false
			t["completed_by"] = ""
			t["cortisol_relief"] = relief
			t["open_since_h"] = time_hours
			task_list_changed.emit(tasks)
			task_procced.emit(id)
			return
	tasks.append({
		"id": id,
		"label": label,
		"cortisol_relief": relief,
		"done": false,
		"delegated": false,
		"completed_by": "",
		"open_since_h": time_hours,
	})
	task_list_changed.emit(tasks)
	task_procced.emit(id)


func complete_task(id: String, by: String = "taylor") -> bool:
	## Marks a task done, records WHO did it, applies cortisol relief.
	## Taylor's own completions also grant serotonin — every finished task
	## feels good. Delegated/auto completions skip the serotonin.
	for t in tasks:
		if t["id"] == id and not t["done"]:
			t["done"] = true
			t["delegated"] = false
			t["completed_by"] = by
			var relief: float = float(t["cortisol_relief"]) * get_task_relief_mult()
			cortisol = clampf(cortisol - relief, 0.0, METER_MAX)
			if by == "taylor":
				add_serotonin(TASK_COMPLETION_SEROTONIN)
			task_list_changed.emit(tasks)
			meters_changed.emit(serotonin, cortisol)
			task_completed.emit(id, relief, by)
			return true
	return false


func go_to_bed() -> void:
	## The 9pm "Go to bed" chore: Taylor turns in for the night. The day
	## ends normally with serotonin kept — the kind end, as opposed to the
	## 1am forced end which wipes it.
	complete_task("go_to_bed")
	_day_end_reason = "bedtime"
	_end_day()


func add_serotonin(amount: float) -> void:
	# Serotonin caps at get_serotonin_cap() (raised by collectible upgrades).
	serotonin = clampf(serotonin + amount, 0.0, get_serotonin_cap())
	meters_changed.emit(serotonin, cortisol)
	fun_used.emit(amount)


func add_dopamine(amount: float) -> void:
	## The phone's whole job: tops up the dopamine bar (clamped 0..MAX).
	dopamine = clampf(dopamine + amount, 0.0, MAX_DOPAMINE)
	dopamine_changed.emit(dopamine)


func add_cortisol(amount: float) -> void:
	## All cortisol GAINS route through here so modes can scale them.
	cortisol = clampf(cortisol + amount * get_cortisol_gain_mult(), 0.0, METER_MAX)
	meters_changed.emit(serotonin, cortisol)


func add_dollars(amount: float) -> void:
	## Work-laptop earnings. No cap; dollars live in-run now — they carry
	## across days and sweep to savings only when the run ends.
	dollars = maxf(dollars + amount, 0.0)
	dollars_changed.emit(dollars)


# --- Savings account + permanent upgrades -----------------------------------

func get_serotonin_cap() -> float:
	## Base cap plus collectible tier bonuses (permanent and in-run both
	## count), plus 50 per collected bird species (banked forever).
	var cap := BASE_SEROTONIN_CAP
	cap += _UPGRADE_DEFS.tier_fx("raquaza", upgrade_tier("raquaza"), "cap_bonus", 0.0)
	cap += _UPGRADE_DEFS.tier_fx("kh_boxset", upgrade_tier("kh_boxset"), "cap_bonus", 0.0)
	cap += 50.0 * float(birds_found.size())
	return cap


func upgrade_tier(id: String) -> int:
	## Effective tier of an upgrade: max(permanent tier, this run's tier).
	## 0 = not owned. Works in every mode.
	var perm := int(permanent_upgrades.get(id, 0))
	var run := 0
	var m := mode_node()
	if m != null and m.has_method("run_tier"):
		run = int(m.call("run_tier", id))
	return maxi(perm, run)


func permanent_tier(id: String) -> int:
	return int(permanent_upgrades.get(id, 0))


## Purchased-product progress for a mode's main-menu card: [owned, total].
## Counts from the per-mode inventory in UpgradeDefs.products_for_mode().
## Shared-catalog products count as owned if any tier is held (permanent or
## run); mode-specific items read that mode's own save/state. Modes with no
## inventory yet return [0, 0] and the card hides the line.
func product_progress(mode: int) -> Array:
	var prods: Array = _UPGRADE_DEFS.products_for_mode(mode)
	if prods.is_empty():
		return [0, 0]
	var owned := 0
	for p in prods:
		if _product_owned(mode, String(p["id"])):
			owned += 1
	return [owned, prods.size()]


func _product_owned(mode: int, pid: String) -> bool:
	# ModeManager.Mode ints: CLASSIC 0, PRACTICE 5, DOPAMINE 6.
	match mode:
		0, 6:  # CLASSIC / DOPAMINE: any tier held (permanent or this run).
			return upgrade_tier(pid) > 0
		5:  # PRACTICE: the two mode unlocks.
			if pid == "classic_unlock":
				return is_mode_unlocked(0)
			if pid == "dopamine_unlock":
				return is_mode_unlocked(6)
			return false
	return false


func grant_permanent_tier(id: String, tier: int) -> void:
	## Set a permanent tier without charging (save migrations).
	permanent_upgrades[id] = clampi(tier, 0, _UPGRADE_DEFS.max_tier())
	savings_changed.emit(savings)
	save_bank()


func buy_permanent_upgrade(id: String) -> Dictionary:
	## Spend SAVINGS on the next permanent tier. One-per-call, in order.
	## Returns {"ok": bool, "reason": String, "tier": int}.
	var def := _UPGRADE_DEFS.def(id)
	if def.is_empty():
		return {"ok": false, "reason": "no such upgrade", "tier": 0}
	var cur := permanent_tier(id)
	if cur >= _UPGRADE_DEFS.max_tier():
		return {"ok": false, "reason": "already maxed", "tier": cur}
	var tier_def: Dictionary = (def["tiers"] as Array)[cur]
	var cost := float(tier_def["perm_cost"])
	if savings < cost:
		return {"ok": false, "reason": "not enough savings", "tier": cur}
	savings -= cost
	permanent_upgrades[id] = cur + 1
	savings_changed.emit(savings)
	save_bank()
	return {"ok": true, "reason": "", "tier": cur + 1}


func sweep_to_savings() -> void:
	## Move all leftover dollars into savings. Called at run end (and at
	## day end in endless modes like practice, which have no run end).
	if dollars > 0.0:
		savings += dollars
		dollars = 0.0
		savings_changed.emit(savings)
		dollars_changed.emit(dollars)
		save_bank()


func save_bank() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bank", "savings", savings)
	cfg.set_value("bank", "permanent_upgrades", permanent_upgrades)
	cfg.set_value("bank", "birds_found", birds_found)
	cfg.set_value("unlocks", "modes", unlocked_modes)
	cfg.set_value("settings", "volume", volume)
	cfg.save(SAVINGS_PATH)


func load_bank() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVINGS_PATH) != OK:
		return
	savings = float(cfg.get_value("bank", "savings", 0.0))
	var p: Variant = cfg.get_value("bank", "permanent_upgrades", {})
	if p is Dictionary:
		permanent_upgrades = p
	var b: Variant = cfg.get_value("bank", "birds_found", [])
	if b is Array:
		birds_found = b
	var m: Variant = cfg.get_value("unlocks", "modes", [])
	if m is Array:
		unlocked_modes = m
	set_volume(float(cfg.get_value("settings", "volume", 1.0)))


## Master volume 0.0-1.0. Persists to the bank file and applies to the
## Master bus live (matters once SFX exist).
func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	var db := linear_to_db(maxi(volume, 0.0001))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	volume_changed.emit(volume)


## Wipes every save file (bank + per-mode saves) and resets in-memory state
## to a fresh game. The main menu's "clear save data" button calls this.
func clear_all_save_data() -> void:
	for path in [SAVINGS_PATH, "user://nightshift_save.cfg",
			"user://delegation_save.cfg", "user://combo_save.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	savings = 0.0
	permanent_upgrades = {}
	birds_found = []
	unlocked_modes = []  # practice is always unlocked; classic re-locks
	# Note: no save_bank() here — the files stay deleted until the next save.
	# In-memory state is already reset, and load_bank() tolerates missing files.


## One-time bird collectibles. Each real mode has one fixed species
## (MODE_BIRDS); touching it collects it forever (banked). Every collected
## species permanently raises the serotonin cap by 50 — that's the reward,
## no instant serotonin. Returns true
## if this touch was the first ever for the species (the bird plays its
## fly-away); false if the species was already found.
func bird_active_today(bird_id: String) -> bool:
	if bird_id in birds_found:
		# A found bird never appears again — one touch per species, ever.
		return false
	return String(MODE_BIRDS.get(ModeManager.current_mode, "")) == bird_id


func collect_bird(bird_id: String) -> bool:
	if bird_id in birds_found:
		return false
	birds_found.append(bird_id)
	save_bank()
	meters_changed.emit(serotonin, cortisol)  # the cap just rose
	return true


func bird_found(bird_id: String) -> bool:
	return bird_id in birds_found


func interact_luke() -> void:
	## Talking to Luke: +10 serotonin, +3 cortisol, +5 dopamine.
	add_serotonin(10.0)
	add_cortisol(3.0)
	add_dopamine(5.0)



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
	serotonin = get_start_serotonin()
	cortisol = get_start_cortisol()
	dopamine = START_DOPAMINE
	_day_end_reason = ""
	day_pressure_mult = 1.0 + 0.15 * float(day_number - 1)
	day_serotonin_integral = 0.0
	_last_clock_string = ""
	_meter_emit_cooldown = 0.0
	tasks.clear()
	_clock_tasks_fired.clear()
	_reset_proc_state()
	# PRACTICE mode: every chore task opens the moment the day starts — the
	# task list is a full checklist from dawn. (Clock tasks keep their fixed
	# schedule; they're tied to NPC states, not the checklist.)
	var all_open = _hook("open_all_tasks_at_dawn")
	if all_open is bool and bool(all_open):
		for def in task_defs:
			_activate_task(def)
	# Birds are one-time collectibles now: no daily reset. Each mode's own
	# unfound species appears.
	sim_running = true
	set_process(true)
	clock_changed.emit(get_time_string())
	task_list_changed.emit(tasks)
	meters_changed.emit(serotonin, cortisol)
	dopamine_changed.emit(dopamine)
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
	var day_length: float = maxf(time_hours - DAY_START_HOUR, 0.01)
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
		"end_reason": _day_end_reason,
	}
	# Modes can inject extra lines (e.g. combo-mom's score).
	var extras = _hook("day_summary_extras")
	if extras is Dictionary:
		for k in (extras as Dictionary).keys():
			summary[k] = (extras as Dictionary)[k]
	return summary


# --- Internal ---------------------------------------------------------------


func _emit_clock_if_changed() -> void:
	var clock_string := _format_time()
	if clock_string != _last_clock_string:
		_last_clock_string = clock_string
		clock_changed.emit(clock_string)


func _end_day() -> void:
	# Dollars live in-run now: they carry across days and only sweep into
	# savings when the whole run ends. (Losses wipe them first — see the
	# _wipe_run_dollars() calls in _process.)
	sim_running = false
	set_process(false)
	if _hook("endless_run"):
		# Endless modes (practice) have no run end: keep the old daily sweep.
		sweep_to_savings()
		day_ended.emit()
		return
	if day_number >= RUN_LENGTH_DAYS:
		# 7-day run complete: sweep leftovers, run over.
		var swept := dollars
		sweep_to_savings()
		var summary := get_day_summary()
		var stats := "Days survived: %d\nTasks: %d/%d\nAvg serotonin: %d\nRating: %s\n$%d swept to savings" % [
			RUN_LENGTH_DAYS,
			int(summary["tasks_done"]), int(summary["tasks_total"]),
			int(round(float(summary["avg_serotonin"]))), String(summary["rating"]),
			int(swept),
		]
		end_run("🏁 7 DAYS COMPLETE", stats, "run")
		return
	day_ended.emit()


func _wipe_run_dollars() -> void:
	## A lost day (cortisol maxed, dopamine zeroed, up past 1 AM): the
	## in-run dollars are wiped — never swept. Savings are untouched.
	if dollars > 0.0:
		dollars = 0.0
		dollars_changed.emit(dollars)


func end_run(title: String, stats: String, restart_kind: String = "run") -> void:
	## A mode ends the whole RUN (not just the day). Same freeze as _end_day,
	## but the HUD shows the run-over panel instead of the day-over one.
	## restart_kind: "run" = R starts a fresh run from day 1 (dopamine loss);
	## "day" = R retries the SAME day (day_number kept).
	sim_running = false
	set_process(false)
	run_ended.emit(title, stats, restart_kind)


func new_run() -> void:
	## Start a fresh run in the current mode: reset the day counter, let the
	## mode clear its run-long state, then start day 1.
	day_number = 0
	# Run over: sweep any leftover dollars into savings, then reset.
	sweep_to_savings()
	_hook("reset_run")
	start_new_day()


func retry_day() -> void:
	## Restart the CURRENT day: clock/tasks/meters reset, day_number kept,
	## mode keeps its run-long state.
	_begin_day()


func _format_time() -> String:
	var total_minutes: int = int(round(time_hours * 60.0))
	var h24: int = (total_minutes / 60) % 24  # wrap past midnight (25:00 -> 1 AM)
	var m: int = total_minutes % 60
	var suffix: String = "AM" if h24 < 12 else "PM"
	var h12: int = h24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]
