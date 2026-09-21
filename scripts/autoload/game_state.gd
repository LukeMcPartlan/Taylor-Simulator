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
##   all_birds_daily() -> bool             default false (practice: all 5)
##   minigames_always_open() -> bool       default false (practice: stations
##     always playable, never dim)
##   minigame_speed_mult() -> float        default 1.0
##   minigame_fail_cortisol() -> float     default 0.0
##   minigame_fail_text() -> String        default "Failed! Press E to retry."
##   task_auto_covered(task_id) -> bool    default false (proc scheduler skips
##     procs for fully automated chores, e.g. delegation's bought upgrades)
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
signal dollars_changed(dollars: float)
signal savings_changed(savings: float)
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
## Emitted when a chore procs (becomes active) during the day.
signal task_procced(task_id: String)
## Emitted when a mode ends the whole run (night-shift meltdown at 100
## cortisol, meltdown mode's third strike). The HUD shows the overlay with
## this title/stats instead of the normal day-over panel.
signal run_ended(title: String, stats: String, restart_kind: String)

# --- Tuning (base defaults; modes override via hooks) -----------------------
const SECONDS_PER_GAME_HOUR: float = 15.0
const DAY_START_HOUR: float = 6.0    # 6:00 AM — Luke needs waking at 6
const DAY_END_HOUR: float = 23.0     # 11:00 PM
const METER_MAX: float = 100.0  # caps CORTISOL only; serotonin is intentionally uncapped

const START_SEROTONIN: float = 60.0
const START_CORTISOL: float = 30.0

const CORTISOL_PER_TASK_PER_HOUR: float = 6.0
const SEROTONIN_DRAIN_PER_TASK_PER_HOUR: float = 3.0
const SEROTONIN_BASELINE_DECAY_PER_HOUR: float = 1.0

# --- Task proc scheduler tuning ------------------------------------------------
# One random chore procs every few REAL seconds (not game-hours, so pacing is
# identical across modes). Each def has its own daily cap (max_procs); once a
# task hits its cap it can't proc again until tomorrow. Ticks only activate a
# task that isn't already open — an open chore just sits there accruing
# neglect (see escalation below), it never double-procs.
const PROC_TICK_MIN_S: float = 3.0
const PROC_TICK_MAX_S: float = 8.0
const PROC_MAX_PER_DAY: int = 5

# --- Neglect escalation ---------------------------------------------------------
# Ignoring a chore gets worse the longer it sits open. Each open task's
# pressure weight grows by NEGLECT_ESCALATION_PER_HOUR for every game-hour it
# stays uncompleted, up to NEGLECT_ESCALATION_MAX_MULT. The clock resets every
# time the task procs — it's a new mess, not the old one.
const NEGLECT_ESCALATION_PER_HOUR: float = 0.5
const NEGLECT_ESCALATION_MAX_MULT: float = 5.0

# --- Fixed-clock tasks ----------------------------------------------------------
# These proc at fixed clock times instead of through the random proc
# scheduler (nobody procs "wake up Luke" at a random hour). Fired once per
# day when the clock crosses the hour.
const CLOCK_TASKS: Array = [
	{"hour": 6.0, "id": "wake_luke", "label": "Wake up Luke", "relief": 12.0},
	{"hour": 7.0, "id": "wake_chris", "label": "Wake up Chris", "relief": 12.0},
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

# --- Daily bird ---------------------------------------------------------------
# One random bird (see scripts/bird.gd; the five live in Main.tscn) is active
# each day. Touching it is worth a flat +50 serotonin, once per day.
const BIRD_IDS: Array = ["robin", "crow", "bluejay", "pigeon", "owl"]
const BIRD_REWARD_SEROTONIN: float = 50.0

const METER_EMIT_THROTTLE: float = 0.25

# Built-in chore defs. Each def is modular: id / label / relief / day_min plus
# optional overrides (max_procs — see the PROC_* defaults above). New tasks
# are added at runtime with register_task_def(); no core-logic edits needed.
const TASK_DEFS: Array = [
	{"id": "laundry", "label": "Do the laundry", "relief": 15.0, "day_min": 1, "max_procs": 5},
	{"id": "dishes", "label": "Wash the dishes", "relief": 12.0, "day_min": 1, "max_procs": 5},
	{"id": "feed_baby", "label": "Feed the baby", "relief": 18.0, "day_min": 1, "max_procs": 5},
	{"id": "change_baby", "label": "Change the baby", "relief": 14.0, "day_min": 1, "max_procs": 5},
	{"id": "basement_toilet", "label": "Clean the basement toilet", "relief": 20.0, "day_min": 1, "max_procs": 5},
	{"id": "mop_kitchen", "label": "Mop the kitchen", "relief": 10.0, "day_min": 2, "max_procs": 5},
	{"id": "take_out_trash", "label": "Take out the trash", "relief": 8.0, "day_min": 3, "max_procs": 5},
	{"id": "microwave", "label": "Clean the microwave", "relief": 10.0, "day_min": 2, "max_procs": 5},
	{"id": "amazon_boxes", "label": "Break down the Amazon boxes", "relief": 12.0, "day_min": 1, "max_procs": 5},
]
const REMIND_LUKE_TASK: Dictionary = {
	"id": "remind_luke", "label": "Remind Luke to get back to work", "relief": 12.0,
}

# --- State ------------------------------------------------------------------
var serotonin: float = START_SEROTONIN
var cortisol: float = START_CORTISOL
var dollars: float = 0.0  # earned at the work laptop (night-shift); swept into savings at day end
## Savings account: global, persists across days AND runs. Leftover dollars
## sweep here at day end; spent in the main-menu shop on permanent upgrades.
var savings: float = 0.0
## Permanent upgrades owned forever: upgrade id -> tier (1-3). Bought with
## savings in the main-menu shop. In-run tiers stack via upgrade_tier().
var permanent_upgrades: Dictionary = {}
const SAVINGS_PATH := "user://taylor_savings.cfg"
## Mode unlocks: PRACTICE is always open; CLASSIC is bought with dollars at
## the practice laptop; every other mode is locked for now. Persisted in the
## bank file alongside savings.
var unlocked_modes: Array = []


## PRACTICE is the front door (always unlocked). CLASSIC unlocks once bought
## in the practice store. Everything else is locked for now.
func is_mode_unlocked(mode: int) -> bool:
	if mode == ModeManager.Mode.PRACTICE:
		return true
	if mode == ModeManager.Mode.CLASSIC:
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
# `delegated`/`completed_by` only matter in DELEGATION mode; harmless elsewhere.
var tasks: Array = []
## All known task defs: built-in TASK_DEFS plus anything added at runtime via
## register_task_def(). The proc scheduler only manages defs listed here;
## dynamically registered tasks (Luke's remind_luke, delegation's fix task)
## bypass the scheduler entirely.
var task_defs: Array = TASK_DEFS.duplicate(true)
## Per-def successful proc counts today: id -> int. Reset every day.
var _proc_state: Dictionary = {}
## Countdown (real seconds) to the next global proc tick.
var _next_proc_in_s: float = 0.0
## Today's randomly picked bird (one of BIRD_IDS); "" before the first day.
var daily_bird_id: String = ""
## True once the daily bird has been touched today (reward is once per day).
var bird_collected_today: bool = false
var sim_running: bool = true
var day_pressure_mult: float = 1.0
var day_serotonin_integral: float = 0.0
## Why the current day ended: "" = reached 11pm, "cortisol" = hit 100 cortisol.
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

	_update_task_procs(delta)
	_check_clock_tasks()

	var game_hours: float = delta / sec_per_hour
	var pressure: float = 0.0
	for t in tasks:
		if not t["done"]:
			pressure += get_neglect_weight(String(t["id"])) \
				* get_task_neglect_mult(t)
	if pressure > 0.0:
		cortisol += get_neglect_cortisol_rate() * get_cortisol_gain_mult() \
			* day_pressure_mult * pressure * game_hours

	serotonin = maxf(serotonin, 0.0)  # nothing drains serotonin passively
	cortisol = clampf(cortisol, 0.0, METER_MAX)
	# Standard rule, every mode: nothing drains serotonin any more — open
	# tasks only ever push cortisol UP. But 100 cortisol ends the day on the
	# spot with serotonin zeroed. (Meltdown mode intercepts this with its own
	# sanity-lives meltdown via the intercept_cortisol_max hook.)
	if cortisol >= METER_MAX and not _hook("intercept_cortisol_max"):
		serotonin = 0.0
		_day_end_reason = "cortisol"
		_end_day()
		return
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


func get_start_cortisol() -> float:
	## Practice mode starts the day at 0 cortisol instead of START_CORTISOL.
	var v = _hook("start_cortisol")
	return float(v) if v != null else START_CORTISOL


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
	## Clear-time scoring (combo-mom): beating a minigame's par time extends
	## the combo window and awards Taylor Points. Returns bonus points.
	var v = _hook("record_minigame_clear", [game_id, elapsed_seconds])
	return int(v) if v != null else 0


func get_move_speed_mult() -> float:
	## Scales Taylor's move speed (combo-mom's Comfy Shoes 1.15x).
	var v = _hook("move_speed_multiplier")
	return float(v) if v != null else 1.0


func get_neglect_weight(task_id: String) -> float:
	## BASE neglect weight of one open task (delegation mode halves some with
	## upgrades). The live pressure is this times the escalation multiplier
	## (get_task_neglect_mult), which grows the longer the task sits open.
	## Queried per task every frame.
	var v = _hook("neglect_weight", [task_id])
	return float(v) if v != null else 1.0


func get_task_neglect_mult(task: Dictionary) -> float:
	## Escalation multiplier for one open task: 1.0 when it procs, growing by
	## NEGLECT_ESCALATION_PER_HOUR per game-hour it stays uncompleted, capped
	## at NEGLECT_ESCALATION_MAX_MULT. Resets whenever the task procs again.
	var open_h: float = maxf(
		time_hours - float(task.get("open_since_h", time_hours)), 0.0)
	return minf(1.0 + NEGLECT_ESCALATION_PER_HOUR * open_h,
		NEGLECT_ESCALATION_MAX_MULT)


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
		# Fresh neglect clock: escalation (get_task_neglect_mult) counts from
		# the moment the task appears.
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
			# Re-proc: flip a completed task back open with a FRESH neglect
			# clock — the escalation multiplier restarts at 1.0.
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
	# Serotonin caps at get_serotonin_cap() (raised by collectible upgrades).
	serotonin = clampf(serotonin + amount, 0.0, get_serotonin_cap())
	meters_changed.emit(serotonin, cortisol)
	fun_used.emit(amount)


func add_cortisol(amount: float) -> void:
	## All cortisol GAINS route through here so modes can scale them
	## (e.g. night-shift Headphones, meltdown coping items).
	cortisol = clampf(cortisol + amount * get_cortisol_gain_mult(), 0.0, METER_MAX)
	meters_changed.emit(serotonin, cortisol)


func add_dollars(amount: float) -> void:
	## Work-laptop earnings (night-shift). No cap; swept to savings at day end.
	dollars = maxf(dollars + amount, 0.0)
	dollars_changed.emit(dollars)


# --- Savings account + permanent upgrades -----------------------------------

func get_serotonin_cap() -> float:
	## Base cap plus collectible tier bonuses (permanent and in-run both count).
	var cap := BASE_SEROTONIN_CAP
	cap += _UPGRADE_DEFS.tier_fx("raquaza", upgrade_tier("raquaza"), "cap_bonus", 0.0)
	cap += _UPGRADE_DEFS.tier_fx("kh_boxset", upgrade_tier("kh_boxset"), "cap_bonus", 0.0)
	return cap


func upgrade_tier(id: String) -> int:
	## Effective tier of an upgrade: max(permanent tier, this run's tier).
	## 0 = not owned. Works in every mode (run tier is night-shift only).
	var perm := int(permanent_upgrades.get(id, 0))
	var run := 0
	var m := mode_node()
	if m != null and m.has_method("run_tier"):
		run = int(m.call("run_tier", id))
	return maxi(perm, run)


func permanent_tier(id: String) -> int:
	return int(permanent_upgrades.get(id, 0))


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
	## Move all leftover dollars into savings. Called at day end and run end.
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
	cfg.set_value("unlocks", "modes", unlocked_modes)
	cfg.save(SAVINGS_PATH)


func load_bank() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVINGS_PATH) != OK:
		return
	savings = float(cfg.get_value("bank", "savings", 0.0))
	var p: Variant = cfg.get_value("bank", "permanent_upgrades", {})
	if p is Dictionary:
		permanent_upgrades = p
	var m: Variant = cfg.get_value("unlocks", "modes", [])
	if m is Array:
		unlocked_modes = m


## Daily bird: touch the active bird for a flat serotonin reward, once per
## day. Returns true if this was the first touch today (the bird plays its
## fly-away); false if already collected.
func collect_daily_bird(amount: float = BIRD_REWARD_SEROTONIN) -> bool:
	if bird_collected_today:
		return false
	bird_collected_today = true
	add_serotonin(amount)
	return true


## Practice mode: ALL FIVE birds are out every day, each touchable once
## (+50 serotonin each). Tracked separately from the single daily bird.
var birds_collected_today: Array = []


func all_birds_daily() -> bool:
	var v = _hook("all_birds_daily")
	return v is bool and bool(v)


func bird_active_today(bird_id: String) -> bool:
	if all_birds_daily():
		return not (bird_id in birds_collected_today)
	return daily_bird_id == bird_id and not bird_collected_today


func collect_bird(bird_id: String, amount: float = BIRD_REWARD_SEROTONIN) -> bool:
	## Route a bird touch through the right daily rule for the active mode.
	if all_birds_daily():
		if bird_id in birds_collected_today:
			return false
		birds_collected_today.append(bird_id)
		add_serotonin(amount)
		return true
	return collect_daily_bird(amount)


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
	cortisol = get_start_cortisol()
	_day_end_reason = ""
	day_pressure_mult = 1.0 + 0.15 * float(day_number - 1)
	day_serotonin_integral = 0.0
	_last_clock_string = ""
	_meter_emit_cooldown = 0.0
	tasks.clear()
	_clock_tasks_fired.clear()
	_reset_proc_state()
	daily_bird_id = String(BIRD_IDS[randi_range(0, BIRD_IDS.size() - 1)])
	bird_collected_today = false
	birds_collected_today.clear()
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
	# Leftover dollars sweep into the savings account; spent days are broke.
	sweep_to_savings()
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
	# Run over: sweep any leftover dollars into savings, then reset.
	sweep_to_savings()
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
