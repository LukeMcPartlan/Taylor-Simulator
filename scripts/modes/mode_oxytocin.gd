extends "res://scripts/modes/mode_cortisol.gd"
## OXYTOCIN MODE node — Cortisol Mode with an oxytocin meter and a remote
## control for Luke. Press Q near him and he teleports to the nearest open
## chore and does it (costs 10 oxytocin); talking to him gives +10.
## Oxytocin starts at 50, drains at dopamine's rate, and the day ends on
## the spot at zero or at max.


func mode_id() -> int:
	return ModeManager.Mode.OXYTOCIN


func hud_tag() -> String:
	return "💞 OXYTOCIN"


func oxytocin_enabled() -> bool:
	## GameState.oxytocin_enabled() reads this hook: the meter drains and
	## can end the day only in this mode.
	return true


func luke_chore_duty() -> bool:
	## GameState.luke_chore_duty_enabled() reads this hook: Q near Luke
	## sends him to do a chore, only in this mode.
	return true
