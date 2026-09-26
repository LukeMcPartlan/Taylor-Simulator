extends "res://scripts/modes/mode_cortisol.gd"
## DOPAMINE MODE node — Cortisol Mode with one twist: dopamine drains 5x
## faster. Same laptop, same catalog, same chores, same bird; the phone
## becomes life support. Everything else is inherited from mode_cortisol.gd.


func mode_id() -> int:
	return ModeManager.Mode.DOPAMINE


func dopamine_drain_mult() -> float:
	## GameState._dopamine_drain_mult() reads this hook: 5x the base drain.
	return 5.0
