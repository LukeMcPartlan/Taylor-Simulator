extends Node
## ModeManager — picks which of the 4 Taylor Simulator game modes is active.
##
## This is an Autoload singleton (registered in project.godot BEFORE GameState,
## so GameState can read the chosen mode in its own _ready()). The main menu
## sets `current_mode`; GameState._ready() calls `create_mode()` to build the
## matching mode node, which becomes GameState.mode_hook.
##
## How modes customize the game (gating, not duplication):
## GameState calls optional methods on the mode node — query methods like
## seconds_per_game_hour(), neglect_cortisol_rate(), hud_tag() — only if the mode
## implements them (checked with has_method()). The CLASSIC mode implements
## nothing, so it behaves exactly like the original game.

## Mode IDs are persisted in save files — never reuse or shift them.
enum Mode { CLASSIC = 0, PRACTICE = 5, DOPAMINE = 6, OXYTOCIN = 7 }

## The mode currently selected. The main menu sets this before loading Main.
var current_mode: int = Mode.CLASSIC

const MODE_SCRIPT_PATHS: Dictionary = {
	Mode.CLASSIC: "res://scripts/modes/mode_cortisol.gd",
	Mode.PRACTICE: "res://scripts/modes/mode_practice.gd",
	Mode.DOPAMINE: "res://scripts/modes/mode_dopamine.gd",
	Mode.OXYTOCIN: "res://scripts/modes/mode_oxytocin.gd",
}

## Display data for the main menu cards (in selection order). PRACTICE is
## the front door — always unlocked. CLASSIC is bought in the practice
## laptop store; DOPAMINE is bought in the cortisol laptop store.
const MODE_CARDS: Array = [
	{
		"mode": Mode.PRACTICE,
		"name": "☀️ Serotonin Mode",
		"desc": "The safe sandbox. All minigames open, zero cortisol, one bird to find. Earn serotonin, work the laptop for dollars, buy Cortisol Mode.",
	},
	{
		"mode": Mode.CLASSIC,
		"name": "😰 Cortisol Mode",
		"desc": "Complete your tasks as fast as possible to keep your cortisol down and finish the day.",
		"locked_desc": "Locked — buy it for $500 from the laptop in Serotonin Mode (🔓 UNLOCK tab).",
	},
	{
		"mode": Mode.DOPAMINE,
		"name": "📱 Dopamine Mode",
		"desc": "Cortisol Mode, but dopamine drains 5x faster. The phone is life support — keep swiping or the day ends early.",
		"locked_desc": "Locked — buy it for $500 at the cortisol laptop (📦 AMAZON tab).",
	},
	{
		"mode": Mode.OXYTOCIN,
		"name": "💞 Oxytocin Mode",
		"desc": "Cortisol Mode with an oxytocin meter. Press Q near Luke to teleport him to a chore (-10 oxytocin); talking to him gives +10. Day ends at 0 or 100.",
		"locked_desc": "Locked — buy it for $500 at the dopamine laptop (📦 AMAZON tab).",
	},
]


func create_mode() -> Node:
	## Builds the mode node for the currently selected mode. Cortisol Mode's
	## node (mode_cortisol.gd) adds no gameplay overrides — the base game IS
	## Cortisol Mode — it only carries the laptop's run-tier upgrade shelf.
	var path: String = String(MODE_SCRIPT_PATHS.get(current_mode, ""))
	if path == "":
		return null
	var script: Script = load(path)
	if script == null:
		push_error("ModeManager: could not load mode script " + path)
		return null
	return script.new()


func mode_name() -> String:
	match current_mode:
		Mode.PRACTICE:
			return "Serotonin"
		Mode.DOPAMINE:
			return "Dopamine"
		Mode.OXYTOCIN:
			return "Oxytocin"
	return "Cortisol"


func set_mode(mode: int) -> void:
	current_mode = mode
