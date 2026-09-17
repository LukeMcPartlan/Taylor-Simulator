extends Node
## COMBO-MOM mode node. The arcade layer: 4-minute days (15s per game hour),
## a x1–x8 combo multiplier for chaining chores, Taylor Points for everything,
## and a night store that spends points on perks.
##
## - COMBO: finishing tasks in quick succession chains a multiplier. Each
##   completion bumps the chain (x1 → x2 → … capped at x8) and refreshes a
##   real-time combo window (base 8s, extendable with Coffee IV). Let the
##   window drain and the chain resets — unless Second Wind is active, which
##   floors it at x2 for the rest of the day.
## - TAYLOR POINTS: each task scores relief x 10 x multiplier. Fun uses score
##   a small flat amount scaled by the multiplier and refresh an active combo
##   window (but never start or extend the chain). Points double as currency
##   at the Night Store — spending them lowers your day score, so every
##   purchase is a real tradeoff.
## - CLEAR-TIME BONUS: beating a minigame's par time extends the combo window
##   and awards bonus points (station.gd calls record_minigame_clear()).
## - HIGH SCORE: best day score + best combo persist in user://combo_save.cfg,
##   along with permanent perks (Coffee IV tiers, Comfy Shoes).

signal combo_changed(combo_count: int, window_left: float, window_max: float)
signal score_changed(day_score: int, best_score: int)

const SAVE_PATH := "user://combo_save.cfg"
const STORE_OPEN_HOUR: float = 21.0
const BASE_COMBO_WINDOW := 8.0  # real seconds per combo link, before perks
const COMBO_CAP := 8            # the multiplier never exceeds x8
const FUN_POINTS := 25          # flat points per fun use, scaled by multiplier

const CLEAR_PAR_SECONDS: Dictionary = {
	"dishes": 45.0, "microwave": 30.0, "laundry": 40.0, "mop": 60.0,
	"toilet": 45.0, "trash": 50.0, "feed_baby": 30.0, "change_baby": 40.0,
	"book": 35.0, "phone": 30.0,
}
const CLEAR_WINDOW_EXTEND_PER_SEC := 0.5  # combo window seconds per second under par
const CLEAR_WINDOW_EXTEND_MAX := 6.0      # extension can't exceed this, per clear
const CLEAR_BONUS_PER_SEC := 10           # bonus PTS per second under par, x current mult

const COFFEE_MAX_TIER := 3
const COFFEE_BASE_COST := 400   # doubles per tier: 400 / 800 / 1600
const COFFEE_WINDOW_BONUS := 3.0  # +combo-window seconds per tier, permanent
const SHOES_COST := 600
const SHOES_SPEED_BONUS := 1.15  # move-speed multiplier, permanent
const SECOND_WIND_COST := 500
const ADVIL_COST := 250
const ADVIL_RELIEF := 30.0

var combo_count: int = 0          # chain length; multiplier = min(count, 8)
var combo_window_left: float = 0.0  # real seconds left before the chain drops
var day_score: int = 0
var best_score: int = 0
var best_combo: int = 0
var day_was_new_best: bool = false
var second_wind_today: bool = false  # one-day perk: combo floors at x2
var coffee_tier: int = 0             # permanent perk, persisted
var shoes_owned: bool = false       # permanent perk, persisted
# Last award, so stations can pop "+N PTS (xM)" float text.
var last_points: int = 0
var last_mult: int = 1

var _combo_label: Label = null
var _score_label: Label = null


func _ready() -> void:
	load_save()
	var gs := get_parent()
	gs.task_completed.connect(_on_task_completed)
	gs.fun_used.connect(_on_fun_used)
	gs.day_ended.connect(_on_day_ended)
	gs.day_started.connect(_on_day_started)
	# GameState._ready() (and day 1's day_started) already fired before we were
	# added, so initialize today's arcade state explicitly.
	reset_day()


func _process(delta: float) -> void:
	# Drain the combo window in real time. Minigames take real seconds, so the
	# window is genuinely about speed.
	if combo_count > 0:
		combo_window_left -= delta
		if combo_window_left <= 0.0:
			_expire_combo()
		_tick_combo_label()


# --- GameState hook queries ---------------------------------------------------

func mode_id() -> int:
	return ModeManager.Mode.COMBO_MOM


func seconds_per_game_hour() -> float:
	# 16 game hours x 15s = a 4-minute day. Blink and you'll miss the store.
	return 15.0


func move_speed_multiplier() -> float:
	return SHOES_SPEED_BONUS if shoes_owned else 1.0


func hud_tag() -> String:
	return "⚡ COMBO-MOM"


func day_summary_extras() -> Dictionary:
	var lines := "Score: %s (best %s)\nBest combo: x%d\nRank: %s" % [
		fmt_points(day_score), fmt_points(best_score), best_combo, score_tier(day_score)]
	if day_was_new_best:
		lines += "\nNEW BEST!"
	return {"extra_lines": lines}


func record_minigame_clear(game_id: String, elapsed_seconds: float) -> int:
	## Clear-time bonus, called by station.gd after every minigame win (AFTER
	## complete_task(), so the combo window was just refreshed and combo_mult
	## is already the new chain's multiplier). Beats the game's par time:
	##   1. the active combo window grows by (par - elapsed) * 0.5s, capped
	##      at CLEAR_WINDOW_EXTEND_MAX — fast clears keep the chain alive;
	##   2. a Taylor Points bonus of int((par - elapsed) * 10) x current
	##      multiplier, added to the day score.
	## Slower-than-par clears (or unknown game ids) get nothing extra.
	var par := float(CLEAR_PAR_SECONDS.get(game_id, -1.0))
	if par <= 0.0 or elapsed_seconds >= par:
		return 0
	var under_par := par - elapsed_seconds
	if combo_count > 0:
		combo_window_left = minf(combo_window_left + under_par * CLEAR_WINDOW_EXTEND_PER_SEC,
			combo_window_max() + CLEAR_WINDOW_EXTEND_MAX)
		combo_changed.emit(combo_count, combo_window_left, combo_window_max())
	var bonus := int(under_par * CLEAR_BONUS_PER_SEC) * combo_mult()
	if bonus > 0:
		day_score += bonus
		last_points = bonus
		last_mult = combo_mult()
		score_changed.emit(day_score, best_score)
	return bonus


func get_last_award() -> Dictionary:
	return {"points": last_points, "mult": last_mult}


func reset_run() -> void:
	# Day score resets every day anyway; nothing run-long to clear except the
	# live chain (day 1 starts fresh).
	combo_count = 0
	combo_window_left = 0.0


# --- Arcade systems -------------------------------------------------------------

func _on_task_completed(_task_id: String, relief: float, _by: String) -> void:
	# Chain math: the completion scores at the NEW chain length, so the first
	# chore of a chain is x1, the second within the window is x2, and so on.
	combo_count += 1
	var mult := mini(combo_count, COMBO_CAP)
	var pts := int(round(relief * 10.0)) * mult
	day_score += pts
	last_points = pts
	last_mult = mult
	best_combo = maxi(best_combo, mult)
	combo_window_left = combo_window_max()
	combo_changed.emit(combo_count, combo_window_left, combo_window_max())
	score_changed.emit(day_score, best_score)


func _on_fun_used(_amount: float) -> void:
	# Fun scores a little and refreshes an active window, but never extends
	# the chain — combos are for chores, not TikTok.
	var mult := combo_mult()
	var pts := FUN_POINTS * mult
	day_score += pts
	last_points = pts
	last_mult = mult
	if combo_count > 0:
		combo_window_left = combo_window_max()
		combo_changed.emit(combo_count, combo_window_left, combo_window_max())
	score_changed.emit(day_score, best_score)


func _on_day_ended() -> void:
	finalize_day()


func _on_day_started(_day: int) -> void:
	reset_day()


func reset_day() -> void:
	combo_count = 0
	combo_window_left = 0.0
	day_score = 0
	day_was_new_best = false
	second_wind_today = false
	last_points = 0
	last_mult = 1
	combo_changed.emit(0, 0.0, combo_window_max())
	score_changed.emit(0, best_score)


func finalize_day() -> void:
	## Called when the day ends: check for a new best and persist.
	day_was_new_best = day_score > best_score and day_score > 0
	if day_was_new_best:
		best_score = day_score
	save_game()
	score_changed.emit(day_score, best_score)


func _expire_combo() -> void:
	if second_wind_today:
		# Second Wind: the chain floors at x2 instead of dying.
		combo_count = 2
		combo_window_left = combo_window_max()
	else:
		combo_count = 0
		combo_window_left = 0.0
	combo_changed.emit(combo_count, combo_window_left, combo_window_max())


func combo_mult() -> int:
	return mini(maxi(combo_count, 1), COMBO_CAP)


func combo_window_max() -> float:
	return BASE_COMBO_WINDOW + COFFEE_WINDOW_BONUS * float(coffee_tier)


func score_tier(score: int) -> String:
	if score >= 10000:
		return "ULTIMATE MOMMY"
	if score >= 6000:
		return "Turbo Mom"
	if score >= 3500:
		return "Combo Queen"
	if score >= 1500:
		return "Solid Mommin'"
	return "Nap Needed"


static func fmt_points(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# --- Store API (used by store_combo_mom.gd) --------------------------------------

func store_open_now() -> bool:
	var gs := get_parent()
	return gs.sim_running and gs.time_hours >= STORE_OPEN_HOUR \
		and gs.time_hours < gs.DAY_END_HOUR


func get_shop_items() -> Array:
	## Night Store catalog. cost < 0 means unavailable (maxed/owned/active).
	return [
		{"id": "coffee_iv", "name": "Coffee IV",
			"desc": "Combo window +3s, forever. Mommy's little IV drip.",
			"cost": _item_cost("coffee_iv"),
			"status": "Tier %d/%d" % [coffee_tier, COFFEE_MAX_TIER]},
		{"id": "comfy_shoes", "name": "Comfy Shoes",
			"desc": "+15% move speed, forever. Gotta go fast.",
			"cost": _item_cost("comfy_shoes"),
			"status": "OWNED" if shoes_owned else ""},
		{"id": "second_wind", "name": "Second Wind",
			"desc": "Combo never drops below x2 for the rest of today.",
			"cost": _item_cost("second_wind"),
			"status": "ACTIVE TODAY" if second_wind_today else "1-DAY"},
		{"id": "advil", "name": "Industrial Advil",
			"desc": "-30 cortisol right now. For the screaming-baby headache.",
			"cost": _item_cost("advil"), "status": "USE NOW"},
	]


func buy_item(item_id: String) -> Dictionary:
	## Spend day score on a perk. Returns {"ok", "msg"} for the shop UI.
	## Spending lowers your score — the arcade tradeoff.
	var gs := get_parent()
	var cost := _item_cost(item_id)
	if cost < 0:
		return {"ok": false, "msg": "Already maxed out!"}
	if day_score < cost:
		return {"ok": false, "msg": "Need %s PTS (have %s)" % [
			fmt_points(cost), fmt_points(day_score)]}
	match item_id:
		"coffee_iv":
			coffee_tier += 1
		"comfy_shoes":
			shoes_owned = true
		"second_wind":
			second_wind_today = true
		"advil":
			gs.cortisol = clampf(gs.cortisol - ADVIL_RELIEF, 0.0, gs.METER_MAX)
			gs.meters_changed.emit(gs.serotonin, gs.cortisol)
		_:
			return {"ok": false, "msg": "Unknown item?!"}
	day_score -= cost
	save_game()
	score_changed.emit(day_score, best_score)
	return {"ok": true, "msg": "Purchased! (-%s PTS)" % fmt_points(cost)}


func _item_cost(item_id: String) -> int:
	match item_id:
		"coffee_iv":
			if coffee_tier >= COFFEE_MAX_TIER:
				return -1
			return COFFEE_BASE_COST * int(pow(2, coffee_tier))
		"comfy_shoes":
			return -1 if shoes_owned else SHOES_COST
		"second_wind":
			return -1 if second_wind_today else SECOND_WIND_COST
		"advil":
			return ADVIL_COST
	return -1


# --- HUD widgets -------------------------------------------------------------------

func build_hud_widgets(dock: VBoxContainer) -> void:
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 26)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	dock.add_child(_combo_label)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	dock.add_child(_score_label)
	# Live refresh: every scoring event and every combo expiry re-ticks the
	# labels (the tickers guard against the labels being freed already).
	combo_changed.connect(_tick_combo_label)
	score_changed.connect(_tick_score_label)
	_tick_combo_label()
	_tick_score_label()


func _tick_combo_label() -> void:
	if _combo_label == null or not is_instance_valid(_combo_label):
		return
	if combo_count > 0:
		_combo_label.text = "x%d COMBO (%.0fs)" % [combo_mult(), combo_window_left]
	else:
		_combo_label.text = "no combo — go do a chore!"


func _tick_score_label() -> void:
	if _score_label == null or not is_instance_valid(_score_label):
		return
	_score_label.text = "%s PTS (best %s)" % [fmt_points(day_score), fmt_points(best_score)]


# --- Save ----------------------------------------------------------------------------

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best_score", best_score)
	cfg.set_value("scores", "best_combo", best_combo)
	cfg.set_value("perks", "coffee_tier", coffee_tier)
	cfg.set_value("perks", "shoes_owned", shoes_owned)
	cfg.save(SAVE_PATH)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first run: no save yet, defaults stand
	best_score = int(cfg.get_value("scores", "best_score", 0))
	best_combo = maxi(int(cfg.get_value("scores", "best_combo", 0)), 0)
	coffee_tier = clampi(int(cfg.get_value("perks", "coffee_tier", 0)), 0, COFFEE_MAX_TIER)
	shoes_owned = bool(cfg.get_value("perks", "shoes_owned", false))
