extends Node
## ModeManager — picks which of the 5 Taylor Simulator game modes is active.
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

enum Mode { CLASSIC, NIGHT_SHIFT, MELTDOWN, DELEGATION, COMBO_MOM }

## The mode currently selected. The main menu sets this before loading Main.
var current_mode: int = Mode.CLASSIC

const MODE_SCRIPT_PATHS: Dictionary = {
	Mode.NIGHT_SHIFT: "res://scripts/modes/mode_night_shift.gd",
	Mode.MELTDOWN: "res://scripts/modes/mode_meltdown.gd",
	Mode.DELEGATION: "res://scripts/modes/mode_delegation.gd",
	Mode.COMBO_MOM: "res://scripts/modes/mode_combo_mom.gd",
}

## Display data for the main menu cards (in selection order).
const MODE_CARDS: Array = [
	{
		"mode": Mode.CLASSIC,
		"name": "☀️ Classic Taylor",
		"desc": "The original 16-hour day. Chores, fun, Luke. No gimmicks — just vibes.",
	},
	{
		"mode": Mode.NIGHT_SHIFT,
		"name": "🌙 Night-Shift Taylor",
		"desc": "The night store opens 9–11pm. Buy permanent buffs, one-day trades, even a babysitter. Sugar rush now, sugar crash later. Meltdown at 100 cortisol = run over.",
	},
	{
		"mode": Mode.MELTDOWN,
		"name": "😱 Meltdown Taylor",
		"desc": "3 sanity lives. Cortisol hits 100 = instant meltdown, lose a life. Buy coping mechanisms and vent at the night store. 3 meltdowns = game over.",
	},
	{
		"mode": Mode.DELEGATION,
		"name": "🤝 Delegation Taylor",
		"desc": "Press Q to delegate chores to Luke (he's slow). Buy permanent upgrades: dishwasher, baby monitor, robot mop. Hope he doesn't break things.",
	},
	{
		"mode": Mode.COMBO_MOM,
		"name": "⚡ Combo-Mom Taylor",
		"desc": "4-minute days. Chain chores for a x1–x8 combo multiplier and rack up Taylor Points. Coffee and speed perks persist between runs.",
	},
]


func create_mode() -> Node:
	## Builds the mode node for the currently selected mode, or null for
	## Classic (Classic needs no overrides — the base game IS Classic).
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
		Mode.NIGHT_SHIFT:
			return "Night-Shift"
		Mode.MELTDOWN:
			return "Meltdown"
		Mode.DELEGATION:
			return "Delegation"
		Mode.COMBO_MOM:
			return "Combo-Mom"
	return "Classic"


func set_mode(mode: int) -> void:
	current_mode = mode
