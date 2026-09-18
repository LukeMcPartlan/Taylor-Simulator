extends Node
## NIGHT-SHIFT mode node. A child of the GameState autoload (GameState adds it
## as `mode_hook`); GameState queries the optional hook methods below and
## otherwise runs the base sim untouched.
##
## What makes Night-Shift different:
## - Tighter clock: 30s per game hour (vs 45), neglect pressure x1.5,
##   cortisol gains x1.25. Days are short and mean.
## - The LAPTOP (walk-up, scripts/modes/store_night_shift.gd), open any time:
##   WORK tab = manage deranged employee emails (FIRE/HIRE: -10 serotonin,
##   +$10 each, new email every press); AMAZON tab = spend dollars on
##   one-per-game buffs (Roomba, Moon Shoes, Box Breaker upgrades...).
## - Babysitter buff: baby tasks grind themselves out in the background.
## - Sugar Rush trade: +30 serotonin now, then a 3-hour cortisol crash.
## - Cortisol hits 100: the RUN is over (not just the day). Bests persist in
##   user://nightshift_save.cfg — a roguelite meta-progression.
##
## Godot conventions:
## - get_parent() is the GameState autoload (it added us). We read/write its
##   sim vars directly — it's our owner, so this coupling is intentional.

signal buffs_changed
signal trades_changed

const SAVE_PATH: String = "user://nightshift_save.cfg"
const STORE_OPEN_HOUR: float = 21.0

# Permanent buffs: bought with serotonin, kept across days AND runs.
const BUFF_DEFS: Array = [
	{"id": "espresso", "short": "Espresso", "label": "Espresso Machine",
		"desc": "Chores 15% faster. Forever. Your heart will file a complaint.", "cost": 25},
	{"id": "headphones", "short": "Headphones", "label": "Noise-Canceling Headphones",
		"desc": "Cortisol gains -20%. Forever. Luke at half volume.", "cost": 45},
	{"id": "babysitter", "short": "Babysitter", "label": "Babysitter Contact",
		"desc": "Baby tasks complete themselves over ~2 in-game hours.", "cost": 70},
	{"id": "blanket", "short": "Blanket", "label": "Weighted Blanket",
		"desc": "Cortisol gains -10%. Forever. Like a hug that judges you.", "cost": 95},
]

# One-day trades: pay cortisol NOW for a buff that expires at the next morning.
const TRADE_DEFS: Array = [
	{"id": "panic_clean", "short": "Panic Clean",
		"desc": "+25 cortisol NOW, chores 2x faster today. Regret is also 2x."},
	{"id": "sugar_rush", "short": "Sugar Rush",
		"desc": "+30 serotonin NOW, then a 3-hour crash (cortisol climbs)."},
	{"id": "gremlin", "short": "Gremlin Mode",
		"desc": "+15 cortisol NOW, fun gives 2x serotonin today. 3am energy."},
]

# Amazon store inventory: bought with DOLLARS (earned at the work laptop),
# one per game, kept across days AND runs. Each one tweaks a minigame or
# spawns a helper.
const AMAZON_DEFS: Array = [
	{"id": "roomba", "short": "Roomba", "label": "Roomba",
		"desc": "A little guy patrols the floor and vacuums Chris's garbage on touch.", "cost": 60},
	{"id": "moon_shoes", "short": "Moon Shoes", "label": "2000s Moon Shoes",
		"desc": "Jump 35% higher. Pure playground technology.", "cost": 50},
	{"id": "extra_ball", "short": "Extra Hand", "label": "Extra \"Hand\"",
		"desc": "Box Breaker: TWO balls in play. Twice the chaos.", "cost": 40},
	{"id": "pipes", "short": "Stronger Pipes", "label": "Stronger Pipes",
		"desc": "Whack-a-Leak: leaks spread every 4s instead of 2s.", "cost": 40},
	{"id": "sponge", "short": "Big Sponge", "label": "Larger Sponge",
		"desc": "Microwave Wipe: 50% bigger wiping brush.", "cost": 30},
	{"id": "paddle", "short": "Paddle Ext.", "label": "Paddle Extender",
		"desc": "Box Breaker: 40% wider tape-gun paddle.", "cost": 25},
	{"id": "hamper", "short": "Hamper Magnets", "label": "Hamper Magnets",
		"desc": "Laundry Hoops: a noticeably wider hamper.", "cost": 25},
]

const BABY_TASK_IDS: Array = ["feed_baby", "change_baby"]
const BABYSITTER_PROGRESS_PER_GAME_HOUR: float = 0.5  # a baby task self-completes in ~2h
const BABYSITTER_LINES: Array = [
	"i got the kid, go touch grass",
	"diaper handled. you're welcome. venmo me",
	"baby's down. try not to wake it, hero",
]
const SUGAR_RUSH_CRASH_HOURS: float = 3.0
const SUGAR_RUSH_CRASH_CORTISOL_PER_HOUR: float = 6.0

var owned_buffs: Array = []        # buff ids, permanent across days and runs
var owned_amazon: Array = []       # amazon item ids, one per game, permanent
var active_trades: Dictionary = {} # trade id -> true, wiped every morning
var sugar_rush_crash_until: float = -1.0
var run_tasks_done: int = 0        # run-long (not reset each day)
var days_survived: int = 0        # fully completed days this run (variant parity)
var run_over: bool = false
var best_days_survived: int = 0
var best_score: int = 0
var _sitter_progress: Dictionary = {}  # baby task id -> 0..1
var _hud_buff_label: Label = null


func _ready() -> void:
	_load_save()
	var gs := get_parent()
	gs.day_started.connect(_on_day_started)
	gs.day_ended.connect(_on_day_ended)
	gs.task_completed.connect(_on_task_completed)
	# Keep the HUD buff/trade line fresh when trades expire each morning or
	# a purchase lands mid-day (the label may not exist yet — refresh guards).
	buffs_changed.connect(_refresh_hud_label)
	trades_changed.connect(_refresh_hud_label)
	# GameState._ready() already started day 1 before we were added (autoload
	# order), so initialize today's state explicitly.
	_on_day_started(gs.day_number)


func _process(delta: float) -> void:
	var gs := get_parent()
	if not gs.sim_running or run_over:
		return
	var game_hours: float = delta / GameState.get_seconds_per_game_hour()
	# Sugar rush crash: the bill comes due for a few in-game hours — as rising
	# cortisol, since nothing drains serotonin any more.
	if active_trades.has("sugar_rush") and gs.time_hours < sugar_rush_crash_until:
		gs.cortisol = minf(gs.cortisol + SUGAR_RUSH_CRASH_CORTISOL_PER_HOUR * game_hours, gs.METER_MAX)
	_update_babysitter(gs, game_hours)
	_check_meltdown(gs)


# --- GameState hook queries ---------------------------------------------------

func mode_id() -> int:
	return ModeManager.Mode.NIGHT_SHIFT


func seconds_per_game_hour() -> float:
	return 15.0


func neglect_cortisol_rate() -> float:
	# Night-shift pressure: every neglected task bites 1.5x harder.
	return GameState.CORTISOL_PER_TASK_PER_HOUR * 1.5


func neglect_serotonin_rate() -> float:
	return GameState.SEROTONIN_DRAIN_PER_TASK_PER_HOUR * 1.5


func cortisol_multiplier() -> float:
	# All cortisol GAINS go through this (neglect pressure, Luke, trades):
	# Headphones cuts them 20%, Weighted Blanket another 10%.
	var mult := 1.0
	if owned_buffs.has("headphones"):
		mult *= 0.8
	if owned_buffs.has("blanket"):
		mult *= 0.9
	return mult


func minigame_speed_mult() -> float:
	# Espresso (permanent, 1.15) x Panic Clean (today, 2.0), multiplicative.
	# Minigames read this as "higher = more forgiving timers".
	var mult: float = 1.0
	if owned_buffs.has("espresso"):
		mult *= 1.15
	if active_trades.has("panic_clean"):
		mult *= 2.0
	return mult


func fun_multiplier() -> float:
	# Gremlin mode: fun stations hit twice as hard today.
	return 2.0 if active_trades.has("gremlin") else 1.0


func serotonin_drain_multiplier() -> float:
	# Weighted Blanket used to slow serotonin drains; nothing drains
	# serotonin any more, so the buff now cuts cortisol gains (see
	# cortisol_multiplier). Kept returning 1.0 so old saves behave.
	return 1.0


func hud_tag() -> String:
	return "🌙 NIGHT-SHIFT"


func day_summary_extras() -> Dictionary:
	return {"extra_lines": "Run score: %d (best %d)\nDays survived: %d (best %d)" % [
		_run_score(), best_score, days_survived, best_days_survived]}


# --- Day / run lifecycle ------------------------------------------------------

func _on_day_started(_day: int) -> void:
	# One-day trades expire every morning; permanent buffs and run stats survive.
	active_trades.clear()
	sugar_rush_crash_until = -1.0
	_sitter_progress.clear()
	trades_changed.emit()


func _on_day_ended() -> void:
	# A day only counts as "survived" once Taylor actually reaches 11pm.
	days_survived += 1


func _on_task_completed(_task_id: String, _relief: float, _by: String) -> void:
	run_tasks_done += 1


func reset_run() -> void:
	## Called by GameState.new_run(): clear run-long state. Day state is
	## cleared by the day_started handler that start_new_day() emits next.
	run_over = false
	run_tasks_done = 0
	days_survived = 0
	set_process(true)


func _update_babysitter(gs: Node, game_hours: float) -> void:
	# The babysitter contact grinds baby tasks in the background.
	if not owned_buffs.has("babysitter"):
		return
	for t in gs.tasks:
		var tid := String(t["id"])
		if bool(t["done"]) or not tid in BABY_TASK_IDS:
			continue
		var p: float = float(_sitter_progress.get(tid, 0.0)) \
			+ BABYSITTER_PROGRESS_PER_GAME_HOUR * game_hours
		if p >= 1.0:
			_sitter_progress.erase(tid)
			gs.complete_task(tid)
			gs.say("BABYSITTER", BABYSITTER_LINES[randi() % BABYSITTER_LINES.size()])
		else:
			_sitter_progress[tid] = p


func _check_meltdown(gs: Node) -> void:
	# Cortisol hit 100: the run ends. Bank bests, save, tell the HUD.
	if run_over or not gs.sim_running:
		return
	if gs.cortisol < gs.METER_MAX:
		return
	run_over = true
	var new_best := false
	if days_survived > best_days_survived:
		best_days_survived = days_survived
		new_best = true
	var score := _run_score()
	if score > best_score:
		best_score = score
		new_best = true
	_save()
	var stats := "Days survived: %d (best %d)\nRun score: %d (best %d)%s" % [
		days_survived, best_days_survived, score, best_score,
		"\nNEW BEST RUN!" if new_best else ""]
	gs.end_run("🌙 MELTDOWN — RUN OVER", stats)


func _run_score() -> int:
	return days_survived * 100 + run_tasks_done * 10


# --- Amazon store API (used by store_night_shift.gd, the laptop) ----------------

func amazon_def(id: String) -> Dictionary:
	for def in AMAZON_DEFS:
		if String(def["id"]) == id:
			return def
	return {}


func owns_amazon_item(id: String) -> bool:
	# Queried by minigames / Taylor / the world. has_method-guarded at call sites.
	return id in owned_amazon


func buy_amazon_item(id: String) -> Dictionary:
	## Spend DOLLARS on a one-per-game Amazon item. Persists to disk.
	var gs := get_parent()
	var def := amazon_def(id)
	if def.is_empty():
		return {"ok": false, "msg": "Unknown item?!"}
	if owned_amazon.has(id):
		return {"ok": false, "msg": "Already owned!"}
	var cost: float = float(def["cost"])
	if gs.dollars < cost:
		return {"ok": false, "msg": "Need $%d" % int(cost)}
	gs.add_dollars(-cost)
	owned_amazon.append(id)
	_save()
	buffs_changed.emit()
	_refresh_hud_label()
	return {"ok": true, "msg": "Delivered! %s" % String(def["label"])}


# --- Store API (used by store_night_shift.gd) ----------------------------------

func store_open_now() -> bool:
	var gs := get_parent()
	return gs.sim_running and gs.time_hours >= STORE_OPEN_HOUR \
		and gs.time_hours < gs.DAY_END_HOUR


func buff_def(id: String) -> Dictionary:
	for def in BUFF_DEFS:
		if String(def["id"]) == id:
			return def
	return {}


func trade_def(id: String) -> Dictionary:
	for def in TRADE_DEFS:
		if String(def["id"]) == id:
			return def
	return {}


func buy_buff(id: String) -> Dictionary:
	## Spend serotonin on a permanent buff. Currency IS the meter, so this is
	## a real tradeoff: every purchase is paid in happiness. Persists to disk.
	var gs := get_parent()
	var def := buff_def(id)
	if def.is_empty():
		return {"ok": false, "msg": "Unknown buff?!"}
	if owned_buffs.has(id):
		return {"ok": false, "msg": "Already owned!"}
	var cost: float = float(def["cost"])
	if gs.serotonin < cost:
		return {"ok": false, "msg": "Need %d serotonin" % int(cost)}
	gs.serotonin = maxf(gs.serotonin - cost, 0.0)  # uncapped: no METER_MAX clamp
	owned_buffs.append(id)
	_save()
	buffs_changed.emit()
	gs.meters_changed.emit(gs.serotonin, gs.cortisol)
	_refresh_hud_label()
	return {"ok": true, "msg": "Bought %s!" % String(def["label"])}


func activate_trade(id: String) -> Dictionary:
	## Voluntary cortisol hit for a buff that lasts until the next morning.
	## Panic Clean can absolutely cause a meltdown on the spot. That's the game.
	var gs := get_parent()
	if trade_def(id).is_empty() or active_trades.has(id):
		return {"ok": false, "msg": "Can't do that right now."}
	match id:
		"panic_clean":
			active_trades[id] = true
			gs.say("TAYLOR", "PANIC CLEANING. EVERYTHING. NOW.")
			gs.add_cortisol(25.0)
		"sugar_rush":
			active_trades[id] = true
			sugar_rush_crash_until = gs.time_hours + SUGAR_RUSH_CRASH_HOURS
			gs.say("TAYLOR", "candy for dinner was a great decision and i will not be taking questions")
			gs.add_serotonin(30.0)
		"gremlin":
			active_trades[id] = true
			gs.say("TAYLOR", "it's 3am somewhere. gremlin mode engaged.")
			gs.add_cortisol(15.0)
		_:
			return {"ok": false, "msg": "Unknown trade?!"}
	trades_changed.emit()
	_refresh_hud_label()
	return {"ok": true, "msg": "Trade accepted!"}


# --- HUD widget ----------------------------------------------------------------

func build_hud_widgets(dock: VBoxContainer) -> void:
	_hud_buff_label = Label.new()
	_hud_buff_label.add_theme_font_size_override("font_size", 15)
	_hud_buff_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_refresh_hud_label()
	dock.add_child(_hud_buff_label)


func _refresh_hud_label() -> void:
	if _hud_buff_label == null or not is_instance_valid(_hud_buff_label):
		return
	var parts: Array = []
	for id in owned_buffs:
		parts.append(String(buff_def(String(id)).get("short", id)))
	for id in owned_amazon:
		parts.append(String(amazon_def(String(id)).get("short", id)))
	for id in active_trades.keys():
		parts.append(String(trade_def(String(id)).get("short", id)) + "*")
	_hud_buff_label.text = "Buffs: " + (", ".join(parts) if not parts.is_empty() else "none (*=today)")


# --- Save ----------------------------------------------------------------------

func _save() -> void:
	var cfg := ConfigFile.new()
	for id in owned_buffs:
		cfg.set_value("buffs", String(id), true)
	for id in owned_amazon:
		cfg.set_value("amazon", String(id), true)
	cfg.set_value("meta", "best_days", best_days_survived)
	cfg.set_value("meta", "best_score", best_score)
	cfg.save(SAVE_PATH)


func _load_save() -> void:
	owned_buffs.clear()
	owned_amazon.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # no save yet — fresh player
	for def in BUFF_DEFS:
		var id := String(def["id"])
		if bool(cfg.get_value("buffs", id, false)):
			owned_buffs.append(id)
	for def in AMAZON_DEFS:
		var aid := String(def["id"])
		if bool(cfg.get_value("amazon", aid, false)):
			owned_amazon.append(aid)
	best_days_survived = int(cfg.get_value("meta", "best_days", 0))
	best_score = int(cfg.get_value("meta", "best_score", 0))
