extends Node
## DELEGATION mode node. Taylor the manager: press Q at a chore station to
## hand it to Luke. He works it slowly (2x the station's work time, off-screen
## in his DELEGATED state — see luke.gd) and refuses while mid-match, so the
## loop is: nag him off the games, THEN put him to work.
##
## - Basement toilet is NOT delegatable. Luke won't go near the pond.
## - One job at a time. Delegated chores glow orange on the task list.
## - 30%: Luke breaks something and a "Fix what Luke broke" task appears —
##   hold E at ANY chore station for 2s to fix it.
## - The Night Store (a Station of Kind.STORE, see station.gd) sells 3
##   PERMANENT upgrades for serotonin: dishwasher, baby monitor, robot mop.
##   Upgrades persist in user://delegation_save.cfg across days AND runs.

const SAVE_PATH: String = "user://delegation_save.cfg"
const STORE_OPEN_HOUR: float = 21.0
const STORE_CLOSE_HOUR: float = 23.0
const FIX_TASK_ID: String = "fix_luke_mess"
const FIX_WORK_SECONDS: float = 2.0
const BREAK_CHANCE: float = 0.30
const NON_DELEGATABLE: Array = ["basement_toilet"]
const AUTO_HOUR: float = 8.0  # robots do their thing one game-hour after day start

const UPGRADES: Array = [
	{"id": "dishwasher", "name": "Dishwasher", "emoji": "🍽️", "cost": 25.0,
		"desc": "Dishes auto-complete at 8:00 AM."},
	{"id": "baby_monitor", "name": "Baby Monitor", "emoji": "🍼", "cost": 45.0,
		"desc": "Feed/change baby cause HALF the neglect stress."},
	{"id": "robot_mop", "name": "Robot Mop", "emoji": "🧹", "cost": 70.0,
		"desc": "Mop auto-completes at 8:00 AM. Trash causes half stress."},
]
# task_id -> upgrade id that auto-completes it at AUTO_HOUR.
const AUTO_TASK_UPGRADES: Dictionary = {
	"dishes": "dishwasher",
	"mop_kitchen": "robot_mop",
}

var owned_upgrades: Array = []
var done_by_taylor: int = 0
var done_by_luke: int = 0
var done_by_robots: int = 0
var _auto_done_today: bool = false
var _luke_label: Label = null


func _ready() -> void:
	_load_upgrades()
	var gs := get_parent()
	gs.day_started.connect(_on_day_started)
	gs.task_completed.connect(_on_task_completed)
	_on_day_started(gs.day_number)


func _process(_delta: float) -> void:
	var gs := get_parent()
	if not gs.sim_running:
		return
	# Robots do their thing one game-hour after day start.
	if not _auto_done_today and gs.time_hours >= AUTO_HOUR:
		_auto_done_today = true
		for task_id in AUTO_TASK_UPGRADES.keys():
			var upgrade_id := String(AUTO_TASK_UPGRADES[task_id])
			if owned_upgrades.has(upgrade_id):
				if gs.complete_task(String(task_id), "robots"):
					gs.say("ROBOTS", "beep boop. %s handled." % String(task_id).replace("_", " "))
	# Luke status widget follows him around.
	_refresh_luke_label()


func _on_day_started(_day: int) -> void:
	_auto_done_today = false
	# The day summary shows TODAY's breakdown, so the counters reset daily.
	done_by_taylor = 0
	done_by_luke = 0
	done_by_robots = 0


func _on_task_completed(_task_id: String, _relief: float, by: String) -> void:
	# Robot auto-completions arrive with by == "robots" — they are neither
	# Taylor's nor Luke's work, so they get their own counter.
	match by:
		"luke":
			done_by_luke += 1
		"robots":
			done_by_robots += 1
		_:
			done_by_taylor += 1


# --- GameState hook queries ---------------------------------------------------

func mode_id() -> int:
	return ModeManager.Mode.DELEGATION


func neglect_weight(task_id: String) -> float:
	## Baby monitor halves baby-task stress; robot mop halves trash stress.
	if task_id in ["feed_baby", "change_baby"] and owned_upgrades.has("baby_monitor"):
		return 0.5
	if task_id == "take_out_trash" and owned_upgrades.has("robot_mop"):
		return 0.5
	return 1.0


func hud_tag() -> String:
	return "🤝 DELEGATION"


func day_summary_extras() -> Dictionary:
	return {"extra_lines": "Done by Taylor: %d · by Luke: %d · by robots: %d" % [
		done_by_taylor, done_by_luke, done_by_robots]}


func reset_run() -> void:
	# Upgrades persist across runs (that's the point of buying them).
	done_by_taylor = 0
	done_by_luke = 0
	done_by_robots = 0


# --- Delegation API (used by station.gd on Q) -----------------------------------

func try_delegate(id: String) -> Dictionary:
	## Attempt to hand task `id` to Luke. Returns {"ok", "reason"}. Only one
	## delegation at a time; station.gd calls Luke's assign_delegation() next
	## and cancel_delegation() if he refuses.
	var gs := get_parent()
	if not gs.sim_running:
		return {"ok": false, "reason": "day's over"}
	if id in NON_DELEGATABLE:
		return {"ok": false, "reason": "Luke won't go near the pond"}
	if is_auto_covered(id):
		return {"ok": false, "reason": "the robots have that one"}
	for t in gs.tasks:
		if String(t["id"]) != id:
			continue
		if bool(t["done"]):
			return {"ok": false, "reason": "already done"}
		if bool(t.get("delegated", false)):
			return {"ok": false, "reason": "already Luke's job"}
		for other in gs.tasks:
			if bool(other.get("delegated", false)) and not bool(other["done"]):
				return {"ok": false, "reason": "he's already doing something"}
		t["delegated"] = true
		gs.task_list_changed.emit(gs.tasks)
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "no such task"}


func cancel_delegation(id: String) -> void:
	## Un-marks a delegated task (used when Luke refuses the job, mid-match).
	var gs := get_parent()
	for t in gs.tasks:
		if String(t["id"]) == id:
			t["delegated"] = false
			gs.task_list_changed.emit(gs.tasks)
			return


func maybe_spawn_break(station_title: String) -> bool:
	## Called by luke.gd when Luke finishes a delegated job. 30%: he broke
	## something and a "Fix what Luke broke" task appears (hold E at ANY chore
	## station, 2s).
	if randf() < BREAK_CHANCE:
		get_parent().register_task(FIX_TASK_ID,
			"Fix what Luke broke (%s)" % station_title, 10.0)
		return true
	return false


func fix_task_id() -> String:
	return FIX_TASK_ID


func fix_task_open() -> bool:
	for t in get_parent().tasks:
		if String(t["id"]) == FIX_TASK_ID and not bool(t["done"]):
			return true
	return false


func fix_work_seconds() -> float:
	return FIX_WORK_SECONDS


# --- Store API (used by station.gd's STORE kind) --------------------------------

func store_open_now() -> bool:
	var gs := get_parent()
	return gs.sim_running and gs.time_hours >= STORE_OPEN_HOUR \
		and gs.time_hours < STORE_CLOSE_HOUR


func is_auto_covered(task_id: String) -> bool:
	return AUTO_TASK_UPGRADES.has(task_id) \
		and owned_upgrades.has(String(AUTO_TASK_UPGRADES[task_id]))


## Proc-scheduler hook (see GameState): automated chores never proc.
func task_auto_covered(task_id: String) -> bool:
	return is_auto_covered(task_id)


func get_upgrades() -> Array:
	return UPGRADES


func has_upgrade(id: String) -> bool:
	return owned_upgrades.has(id)


func buy_upgrade(id: String) -> Dictionary:
	## Permanent upgrades, bought with serotonin. Persisted to disk.
	var gs := get_parent()
	for def in UPGRADES:
		if String(def["id"]) == id:
			if owned_upgrades.has(id):
				return {"ok": false, "reason": "Already owned!"}
			var cost := float(def["cost"])
			if gs.serotonin < cost:
				return {"ok": false, "reason": "Need %d serotonin" % int(cost)}
			gs.serotonin = maxf(gs.serotonin - cost, 0.0)  # uncapped: no METER_MAX clamp
			owned_upgrades.append(id)
			_save_upgrades()
			gs.meters_changed.emit(gs.serotonin, gs.cortisol)
			return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "Unknown upgrade?!"}


# --- HUD widget ------------------------------------------------------------------

func build_hud_widgets(dock: VBoxContainer) -> void:
	_luke_label = Label.new()
	_luke_label.add_theme_font_size_override("font_size", 16)
	_luke_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	dock.add_child(_luke_label)
	_refresh_luke_label()


func _refresh_luke_label() -> void:
	if _luke_label == null or not is_instance_valid(_luke_label):
		return
	var luke := get_tree().get_first_node_in_group("luke")
	if luke != null and luke.has_method("delegation_status"):
		_luke_label.text = String(luke.delegation_status())
	else:
		_luke_label.text = "💤 Luke: vibing"


# --- Save ------------------------------------------------------------------------

func _save_upgrades() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("upgrades", "owned", PackedStringArray(owned_upgrades))
	cfg.save(SAVE_PATH)


func _load_upgrades() -> void:
	owned_upgrades.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for u in cfg.get_value("upgrades", "owned", PackedStringArray()):
			owned_upgrades.append(String(u))
