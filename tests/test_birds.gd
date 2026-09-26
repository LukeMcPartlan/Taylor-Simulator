extends SceneTree
## Headless verification for one-time bird collectibles:
##  - each real mode has one fixed species (MODE_BIRDS), active until found
##  - collect_bird() banks the species forever: second touch gives nothing
##  - found birds persist across day starts (no daily reset)
##  - practice has one bird (the robin), active while uncollected
##  - GameState.product_progress() counts per-mode inventories
##
## Run: godot --headless --script tests/test_birds.gd
##
## NOTE: bare autoload names (GameState, ModeManager) do not resolve when a
## script is compiled as the --script main loop, so we look the singletons up
## as untyped vars and dispatch dynamically.

var _failures: Array = []
var _checks: int = 0
var GS = null         # /root/GameState
var MM = null         # /root/ModeManager
const MODE_CLASSIC: int = 0
const MODE_PRACTICE: int = 5
const MODE_DOPAMINE: int = 6


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		printerr("FAIL: ", name)


func _initialize() -> void:
	# _initialize runs before the tree is active (autoloads not resolvable
	# yet), so the real boot happens on the first _process frame.
	pass


var _booted := false


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	_attach_mode_hook(MODE_CLASSIC)
	_run()
	return false


func _attach_mode_hook(mode: int) -> void:
	MM.set_mode(mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	if hook != null:
		GS.add_child(hook)
		GS.set("mode_hook", hook)


func _run() -> void:
	# Start from a clean slate (don't touch the real bank file).
	GS.set("birds_found", [])

	# --- Fixed species per mode ------------------------------------------------
	MM.set_mode(MODE_CLASSIC)
	_check(String(GS.MODE_BIRDS.get(0, "")) == "robin", "birds: classic's bird is the robin")
	_check(GS.MODE_BIRDS.size() == 3, "birds: three modes have a fixed species")
	_check(String(GS.MODE_BIRDS.get(6, "")) == "robin", "birds: dopamine's bird is the robin")
	_check(String(GS.MODE_BIRDS.get(MODE_PRACTICE, "")) == "robin", "birds: practice's bird is the robin")

	# --- Active until found ----------------------------------------------------
	_check(GS.call("bird_active_today", "robin"), "birds: classic's robin active before collection")
	_check(not GS.call("bird_active_today", "crow"), "birds: other species inactive in classic")

	# --- One-time collection: the reward is +50 serotonin CAP, banked forever --
	var cap0: float = GS.call("get_serotonin_cap")
	var s0: float = GS.get("serotonin")
	_check(GS.call("collect_bird", "robin"), "birds: first touch collects")
	_check(float(GS.call("get_serotonin_cap")) == cap0 + 50.0, "birds: collection grants +50 serotonin cap")
	_check(float(GS.get("serotonin")) == s0, "birds: collection grants no instant serotonin")
	_check(not GS.call("collect_bird", "robin"), "birds: second touch gives nothing")
	_check(float(GS.call("get_serotonin_cap")) == cap0 + 50.0, "birds: no double cap")
	_check(GS.call("bird_found", "robin"), "birds: robin marked found")
	_check(not GS.call("bird_active_today", "robin"), "birds: found bird no longer active in its mode")

	# --- Practice has one bird: the robin ---------------------------------------
	_attach_mode_hook(MODE_PRACTICE)
	GS.set("birds_found", [])
	_check(GS.call("bird_active_today", "robin"), "birds: practice's robin active before collection")
	_check(not GS.call("bird_active_today", "crow"), "birds: other species inactive in practice")
	_check(GS.call("collect_bird", "robin"), "birds: practice touch collects the robin")
	_check(not GS.call("bird_active_today", "robin"), "birds: found robin no longer active in practice")

	# --- Product progress ----------------------------------------------------------
	var pp: Array = GS.call("product_progress", MODE_PRACTICE)
	_check(int(pp[1]) == 2, "birds: practice inventory is 2 products (both mode unlocks)")
	pp = GS.call("product_progress", MODE_CLASSIC)
	_check(int(pp[0]) == 0 and int(pp[1]) == 6, "birds: classic inventory is the 6-product cortisol catalog")
	pp = GS.call("product_progress", MODE_DOPAMINE)
	_check(int(pp[1]) == 6, "birds: dopamine inventory is the same 6-product catalog")

	# --- Shared permanent products work in every mode ---------------------------
	# The Amazon catalog is shared: permanent tiers resolve
	# through GameState.upgrade_tier() regardless of the active mode hook.
	_attach_mode_hook(MODE_CLASSIC)
	var perms: Dictionary = GS.get("permanent_upgrades")
	for pid in ["moon_shoes", "extra_ball", "pipes", "sponge", "good_drops",
			"green_zone"]:
		perms[pid] = 2
	_check(int(GS.call("upgrade_tier", "moon_shoes")) == 2,
		"birds: moon shoes tier resolves in classic mode")
	_check(int(GS.call("upgrade_tier", "pipes")) == 2,
		"birds: stronger pipes tier resolves in classic mode")
	_check(int(GS.call("upgrade_tier", "green_zone")) == 2,
		"birds: steady hands tier resolves in classic mode")
	pp = GS.call("product_progress", MODE_CLASSIC)
	_check(int(pp[0]) == 6, "birds: classic shows 6/6 products when all owned")
	for pid in ["moon_shoes", "extra_ball", "pipes", "sponge", "good_drops",
			"green_zone"]:
		perms.erase(pid)

	# Restore clean state for other tests (and the bank file we touched via
	# collect_bird -> save_bank).
	GS.set("birds_found", [])
	GS.call("save_bank")

	print("=== birds: %d/%d checks passed ===" % [_checks - _failures.size(), _checks])
	quit(1 if not _failures.is_empty() else 0)
