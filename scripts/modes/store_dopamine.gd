extends "res://scripts/modes/store_cortisol.gd"
## Taylor's LAPTOP in Dopamine Mode: the same hardware and the same 6-product
## catalog as Cortisol Mode (it's the same game, only the dopamine drain is
## 5x). Thin subclass — only the mode gate differs.


func _store_mode_id() -> int:
	return ModeManager.Mode.DOPAMINE
