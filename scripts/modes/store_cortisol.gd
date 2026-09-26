extends StoreLaptop
## Taylor's LAPTOP in Cortisol Mode: the same laptop hardware as every mode
## (WORK tab: deranged employee emails, FIRE/HIRE for dollars), but Cortisol
## Mode's AMAZON tab sells its own 6-product catalog:
##   Extra Ball (Box Breaker), Bigger Sponge (microwave),
##   Slower Leaks (toilet), Lucky Diapers (Diaper Catch good-item spawns),
##   Steady Hands (wider baby-feeding green zone), Moon Shoes (charge jump).
## Purchases are in-run tiers here; their effects apply in EVERY mode via
## GameState.upgrade_tier(), and permanent tiers are sold in the main menu.

const _CORTISOL_IDS: Array = [
	"extra_ball", "sponge", "pipes", "good_drops", "green_zone", "moon_shoes",
]


func _store_mode_id() -> int:
	return ModeManager.Mode.CLASSIC


func _amazon_defs() -> Array:
	var defs: Array = []
	for pid in _CORTISOL_IDS:
		var d: Dictionary = _UPGRADE_DEFS.def(pid)
		if not d.is_empty():
			defs.append(d)
	return defs
