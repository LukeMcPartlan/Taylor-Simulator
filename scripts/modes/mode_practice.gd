extends Node
## PRACTICE mode node. A child of the GameState autoload (GameState adds it
## as `mode_hook`); GameState queries the optional hook methods below and
## otherwise runs the base sim untouched.
##
## The safe sandbox and the game's front door — always unlocked:
## - NO CORTISOL: neglect pressure zeroed AND every cortisol gain zeroed, so
##   the stress meter can never climb. The day can't be cut short.
## - ALL MINIGAMES OPEN: every chore/fun station plays its minigame on E,
##   task or no task. Stations never dim.
## - ALL 5 BIRDS, EVERY DAY: each bird is out and touchable once per day
##   (+50 serotonin each = +250/day to fund the work laptop).
## - THE LAPTOP (scripts/modes/store_practice.gd): WORK tab turns serotonin
##   into dollars (-10 serotonin, +$10 per verdict, same as night-shift);
##   the UNLOCK tab sells the only item in the store — CLASSIC MODE ($60).
##   Buying it unlocks Classic on the main menu forever.
## - The day still runs 6am–11pm; leftover dollars sweep to savings at day
##   end like everywhere else.
##
## Godot conventions:
## - get_parent() is the GameState autoload (it added us). We read/write its
##   sim vars directly — it's our owner, so this coupling is intentional.


func mode_id() -> int:
	return ModeManager.Mode.PRACTICE


func hud_tag() -> String:
	return "🌱 PRACTICE"


func start_cortisol() -> float:
	# Practice starts calm and stays calm.
	return 0.0


func neglect_cortisol_rate() -> float:
	# Open tasks push nothing in the sandbox.
	return 0.0


func cortisol_multiplier() -> float:
	# Every cortisol GAIN (Luke, trades, fails) is zeroed too. Belt and
	# suspenders with neglect_cortisol_rate() above.
	return 0.0


func all_birds_daily() -> bool:
	# All five birds are out every day, each collectible once.
	return true


func minigames_always_open() -> bool:
	# Every station's minigame is playable on E, no open task required.
	return true


func day_summary_extras() -> Dictionary:
	return {"extra_lines": "Practice day complete — pet all 5 birds (+250 serotonin) and work the laptop to save up for Classic mode!"}
