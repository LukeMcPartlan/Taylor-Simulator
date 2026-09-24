extends SceneTree
## Headless verification for one-time bird collectibles:
##  - each real mode has one fixed species (MODE_BIRDS), active until found
##  - collect_bird() banks the species forever: second touch gives nothing
##  - found birds persist across day starts (no daily reset)
##  - practice shows all five as a gallery (active while uncollected)
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
const MODE_NIGHT_SHIFT: int = 1
const MODE_PRACTICE: int = 5


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
	_check(String(GS.MODE_BIRDS.get(1, "")) == "crow", "birds: night shift's bird is the crow")
	_check(GS.MODE_BIRDS.size() == 5, "birds: five real modes have a fixed species")
	_check(not GS.MODE_BIRDS.has(MODE_PRACTICE), "birds: practice has no single species (gallery)")

	# --- Active until found ----------------------------------------------------
	_check(GS.call("bird_active_today", "robin"), "birds: classic's robin active before collection")
	_check(not GS.call("bird_active_today", "crow"), "birds: other species inactive in classic")

	# --- One-time collection ----------------------------------------------------
	var s0: float = GS.get("serotonin")
	_check(GS.call("collect_bird", "robin", 50.0), "birds: first touch collects")
	_check(float(GS.get("serotonin")) == s0 + 50.0, "birds: collection grants +50 serotonin")
	_check(not GS.call("collect_bird", "robin", 50.0), "birds: second touch gives nothing")
	_check(float(GS.get("serotonin")) == s0 + 50.0, "birds: no double serotonin")
	_check(GS.call("bird_found", "robin"), "birds: robin marked found")
	_check(not GS.call("bird_active_today", "robin"), "birds: found bird no longer active in its mode")

	# --- Practice gallery --------------------------------------------------------
	_attach_mode_hook(MODE_PRACTICE)
	_check(GS.call("bird_active_today", "crow"), "birds: practice shows uncollected species")
	_check(GS.call("bird_active_today", "robin"), "birds: practice gallery includes found birds")
	_check(GS.call("collect_bird", "crow", 50.0), "birds: practice touch collects new species")
	_check(not GS.call("collect_bird", "crow", 50.0), "birds: practice re-touch gives nothing")

	# --- Product progress ----------------------------------------------------------
	var pp: Array = GS.call("product_progress", MODE_PRACTICE)
	_check(int(pp[1]) == 1, "birds: practice inventory is 1 product (classic unlock)")
	pp = GS.call("product_progress", MODE_NIGHT_SHIFT)
	_check(int(pp[1]) == 9, "birds: night shift inventory is 9 products")
	pp = GS.call("product_progress", 2)
	_check(int(pp[1]) == 5, "birds: meltdown inventory is 5 durable coping products (vents excluded)")
	pp = GS.call("product_progress", 3)
	_check(int(pp[1]) == 3, "birds: delegation inventory is 3 upgrades")
	pp = GS.call("product_progress", 4)
	_check(int(pp[1]) == 4, "birds: combo mom inventory is 4 items")
	pp = GS.call("product_progress", MODE_CLASSIC)
	_check(int(pp[0]) == 0 and int(pp[1]) == 0, "birds: classic has no inventory yet (line hidden)")

	# --- Shared permanent products work in every mode ---------------------------
	# The night-shift Amazon catalog is shared: permanent tiers resolve
	# through GameState.upgrade_tier() regardless of the active mode hook.
	_attach_mode_hook(MODE_CLASSIC)
	var perms: Dictionary = GS.get("permanent_upgrades")
	for pid in ["roomba", "moon_shoes", "extra_ball", "pipes", "sponge",
			"paddle", "hamper", "raquaza", "kh_boxset"]:
		perms[pid] = 2
	_check(int(GS.call("upgrade_tier", "moon_shoes")) == 2,
		"birds: moon shoes tier resolves in classic mode")
	_check(int(GS.call("upgrade_tier", "pipes")) == 2,
		"birds: stronger pipes tier resolves in classic mode")
	_check(int(GS.call("upgrade_tier", "raquaza")) == 2,
		"birds: raquaza tier resolves in classic mode")
	pp = GS.call("product_progress", MODE_NIGHT_SHIFT)
	_check(int(pp[0]) == 9, "birds: night shift shows 9/9 products when all owned")
	for pid in ["roomba", "moon_shoes", "extra_ball", "pipes", "sponge",
			"paddle", "hamper", "raquaza", "kh_boxset"]:
		perms.erase(pid)

	# Restore clean state for other tests (and the bank file we touched via
	# collect_bird -> save_bank).
	GS.set("birds_found", [])
	GS.call("save_bank")

	print("=== birds: %d/%d checks passed ===" % [_checks - _failures.size(), _checks])
	quit(1 if not _failures.is_empty() else 0)
