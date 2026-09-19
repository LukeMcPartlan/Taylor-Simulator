class_name UpgradeDefs
extends RefCounted

## Shared upgrade catalog for the laptop AMAZON tab (in-run, dollars, lasts
## the run) and the main-menu savings shop (permanent, savings, forever).
## Each upgrade has 3 escalating tiers. Effective tier = max(permanent, run).

const DEFS: Array = [
	{
		"id": "roomba", "name": "Roomba", "kind": "gadget",
		"tiers": [
			{"label": "Roomba", "desc": "Patrols the ground floor, vacuums Chris's garbage on contact.",
				"run_cost": 60.0, "perm_cost": 200.0, "fx": {"speed": 110.0, "radius": 42.0}},
			{"label": "Roomba Turbo", "desc": "Faster patrol, wider vacuum. It hungers.",
				"run_cost": 120.0, "perm_cost": 400.0, "fx": {"speed": 160.0, "radius": 55.0}},
			{"label": "Roomba Swarm", "desc": "Maximum velocity. Maximum suction. Zero mercy.",
				"run_cost": 240.0, "perm_cost": 800.0, "fx": {"speed": 220.0, "radius": 70.0}},
		],
	},
	{
		"id": "moon_shoes", "name": "Moon Shoes", "kind": "gadget",
		"tiers": [
			{"label": "2000s Moon Shoes", "desc": "+35% jump velocity. Banned in 3 states.",
				"run_cost": 50.0, "perm_cost": 175.0, "fx": {"jump_mult": 1.35}},
			{"label": "Moon Shoes XL", "desc": "+60% jump. The floor is a suggestion.",
				"run_cost": 100.0, "perm_cost": 350.0, "fx": {"jump_mult": 1.6}},
			{"label": "Moon Shoes: Lunar Edition", "desc": "+90% jump. Taylor can see her house from up here.",
				"run_cost": 200.0, "perm_cost": 700.0, "fx": {"jump_mult": 1.9}},
		],
	},
	{
		"id": "extra_ball", "name": "Extra Hand", "kind": "gadget",
		"tiers": [
			{"label": "Extra \"Hand\"", "desc": "Box Breaker runs with 2 balls at once.",
				"run_cost": 40.0, "perm_cost": 150.0, "fx": {"balls": 2}},
			{"label": "Extra \"Hands\"", "desc": "3 balls. Nobody knows where the hands come from.",
				"run_cost": 80.0, "perm_cost": 300.0, "fx": {"balls": 3}},
			{"label": "\"Many Hands\"", "desc": "4 balls. Do not ask about the hands.",
				"run_cost": 160.0, "perm_cost": 600.0, "fx": {"balls": 4}},
		],
	},
	{
		"id": "pipes", "name": "Stronger Pipes", "kind": "gadget",
		"tiers": [
			{"label": "Stronger Pipes", "desc": "Whack-a-Leak spread interval 3s -> 4s.",
				"run_cost": 40.0, "perm_cost": 150.0, "fx": {"spread": 4.0}},
			{"label": "Titanium Pipes", "desc": "Spread interval 6s. Leaks fear commitment now.",
				"run_cost": 80.0, "perm_cost": 300.0, "fx": {"spread": 6.0}},
			{"label": "Pipes of Adamantium", "desc": "Spread interval 8s. The toilet has accepted defeat.",
				"run_cost": 160.0, "perm_cost": 600.0, "fx": {"spread": 8.0}},
		],
	},
	{
		"id": "sponge", "name": "Larger Sponge", "kind": "gadget",
		"tiers": [
			{"label": "Larger Sponge", "desc": "Microwave Wipe brush radius 34 -> 51.",
				"run_cost": 30.0, "perm_cost": 100.0, "fx": {"brush_mult": 1.5}},
			{"label": "XL Sponge", "desc": "Brush radius x2.0. One swipe, whole shelf.",
				"run_cost": 60.0, "perm_cost": 200.0, "fx": {"brush_mult": 2.0}},
			{"label": "The Spongenator", "desc": "Brush radius x2.5. The microwave fears you.",
				"run_cost": 120.0, "perm_cost": 400.0, "fx": {"brush_mult": 2.5}},
		],
	},
	{
		"id": "paddle", "name": "Paddle Extender", "kind": "gadget",
		"tiers": [
			{"label": "Paddle Extender", "desc": "Box Breaker paddle 120 -> 168 wide.",
				"run_cost": 25.0, "perm_cost": 90.0, "fx": {"width_mult": 1.4}},
			{"label": "Paddle Extender Pro", "desc": "Paddle x1.7 wide. Practically a wall.",
				"run_cost": 50.0, "perm_cost": 180.0, "fx": {"width_mult": 1.7}},
			{"label": "Paddle Extender Max", "desc": "Paddle x2.0 wide. The ball has nowhere to go but up.",
				"run_cost": 100.0, "perm_cost": 360.0, "fx": {"width_mult": 2.0}},
		],
	},
	{
		"id": "hamper", "name": "Hamper Magnets", "kind": "gadget",
		"tiers": [
			{"label": "Hamper Magnets", "desc": "Laundry Hoops hamper goes wider.",
				"run_cost": 25.0, "perm_cost": 90.0, "fx": {"width": 150.0}},
			{"label": "Hamper Electromagnets", "desc": "Even wider. Garments feel a pull.",
				"run_cost": 50.0, "perm_cost": 180.0, "fx": {"width": 180.0}},
			{"label": "Hamper Tractor Beam", "desc": "Widest. Laundry practically files itself.",
				"run_cost": 100.0, "perm_cost": 360.0, "fx": {"width": 210.0}},
		],
	},
	{
		"id": "raquaza", "name": "Shiny Raquaza Card", "kind": "collectible",
		"tiers": [
			{"label": "shiny raquaza pokemon card", "desc": "+50 serotonin cap. It's definitely real.",
				"run_cost": 100.0, "perm_cost": 300.0, "fx": {"cap_bonus": 50.0}},
			{"label": "shiny raquaza pokemon card (first edition)", "desc": "+100 serotonin cap. Smells like 2003.",
				"run_cost": 200.0, "perm_cost": 600.0, "fx": {"cap_bonus": 100.0}},
			{"label": "shiny raquaza pokemon card (PSA 10, cased)", "desc": "+150 serotonin cap. Never touching it. Ever.",
				"run_cost": 400.0, "perm_cost": 1200.0, "fx": {"cap_bonus": 150.0}},
		],
	},
	{
		"id": "kh_boxset", "name": "KH Mirror World Box Set", "kind": "collectible",
		"tiers": [
			{"label": "kingdom hearts mirror world complete box set devine destiny devolution heartless remix eddition part 2",
				"desc": "+50 serotonin cap. All 47 discs included.",
				"run_cost": 100.0, "perm_cost": 300.0, "fx": {"cap_bonus": 50.0}},
			{"label": "kingdom hearts mirror world complete box set devine destiny devolution heartless remix eddition part 2: director's cut",
				"desc": "+100 serotonin cap. Still part 2. There was never a part 1.",
				"run_cost": 200.0, "perm_cost": 600.0, "fx": {"cap_bonus": 100.0}},
			{"label": "kingdom hearts mirror world complete box set devine destiny devolution heartless remix eddition part 2: the final part 2 (for real this time)",
				"desc": "+150 serotonin cap. The shelf groans under its weight.",
				"run_cost": 400.0, "perm_cost": 1200.0, "fx": {"cap_bonus": 150.0}},
		],
	},
]


static func def(id: String) -> Dictionary:
	for d in DEFS:
		if String(d["id"]) == id:
			return d
	return {}


static func max_tier() -> int:
	return 3


## Tier bonus lookup: fx value of the tier's params dict, or a default.
static func tier_fx(id: String, tier: int, key: String, fallback: float) -> float:
	var d := def(id)
	if d.is_empty() or tier <= 0:
		return fallback
	var tiers: Array = d["tiers"]
	var t: Dictionary = tiers[clampi(tier - 1, 0, tiers.size() - 1)]
	return float((t["fx"] as Dictionary).get(key, fallback))
