extends "res://scripts/modes/store_cortisol.gd"
## Taylor's LAPTOP in Oxytocin Mode: the same hardware and the same
## 6-product catalog as Cortisol/Dopamine Mode (it's the same game, only
## the oxytocin meter and Luke's chore duty are new). Thin subclass — only
## the mode gate differs.


func _store_mode_id() -> int:
	return ModeManager.Mode.OXYTOCIN
