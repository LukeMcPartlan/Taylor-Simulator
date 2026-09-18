# Taylor Simulator

A 2D Godot platformer where you live Taylor's life: manage a 16-hour household
day (7am–11pm) by balancing two meters — **serotonin** and **cortisol**.

- **Incomplete tasks** make cortisol rise and serotonin drain.
- **Completing chores** (hold E at their stations) reduces cortisol.
- **Fun** — reading a book, scrolling TikTok — raises serotonin.
- **Luke** (the "pet retard" NPC) wanders the house spouting unhinged wisdom.
  Talking to him raises *both* meters. Sometimes he starts gaming instead of
  working, which spawns a task: remind him to get back to work.
- At 11pm the day ends with a report card (tasks done, average serotonin, day
  rating). Press R for the next day — later days add chores and crank up the
  pressure.

## Controls

| Input | Action |
|---|---|
| ←/→ or A/D | Move |
| Space / Enter / W | Jump |
| E (near a station) | Play that station's minigame |
| R (on the day-over screen) | Start the next day |

Win a station's minigame to complete its task (chores) or earn serotonin
(fun). Losing costs nothing — just press E and retry.

Chores don't all start active: one random chore procs every few seconds, each
up to 5 times per day. Ignoring a chore gets worse over time — its neglect
penalty grows the longer it sits open (up to 5x). New tasks can be added
modularly with `GameState.register_task_def()` (+ `World.register_station_def()`).

Each day one random bird (robin, crow, bluejay, pigeon, or owl) appears
somewhere in the world — walk into it for +50 serotonin, once per day.
The five birds live in Main.tscn under World: drag them around the editor
and swap their sprites in the inspector.

## Minigames

| Station | Minigame | How it works |
|---|---|---|
| Dishes | Dish Tetris | Falling-block; clear 3 rows (A/D move, S drop, Z rotate) |
| Microwave | Microwave Wipe | Drag the mouse to wipe grime; 90% clean wins |
| Laundry | Laundry Hoops | Hold SPACE to charge, release to shoot; 5 baskets |
| Mop closet | Mop Pong | Breakout with a mop; scrub all dirt tiles (A/D) |
| Basement toilet | Whack-a-Leak | Click leaks to plug them; plug 10, don't flood |
| Trash bins | Trash Sort | ← recycle / → trash while the item is in the zone; 10 right |
| Feed baby | Spoon Timing | SPACE when the marker is in the green; 5 spoonfuls |
| Change baby | Diaper Catch | Catch diapers, dodge poop/pee/vomit (A/D); 8 diapers |
| Book | Reading Focus | Hold SPACE to read, release before restlessness maxes |
| Phone | TikTok Swipe | Hit the matching arrow key in time; 10 hits |

## Game modes

This is the **unified playtest build**: one repo, five games behind a single
menu. Pick a mode card (arrow keys / mouse, Enter to start) and the same house,
stations, and minigames get re-skinned by that mode's rules. **M** at any time
returns to the menu; **R** on a day-over / run-over screen starts the next day
(or a new run / retries the day, depending on the mode).

| Mode | Twist |
|---|---|
| **Classic** | The original game. Survive 7am–11pm, keep cortisol down, serotonin up. |
| **🌙 Night-Shift** | 30-second game hours, 1.5× neglect pressure, cortisol 100 = run over. Spend serotonin at the night store on permanent buffs (Espresso, Weighted Blanket…) and one-day trades (Sugar Rush, Panic Clean…). Babysitter buff auto-completes baby tasks. Best days-survived and run score persist. |
| **😱 Meltdown** | You have 3 sanity lives. Cortisol 100 = instant meltdown: lose a life, retry the same day; lose all 3 and the run ends. Failed minigames +5 cortisol, Luke gets mean above 70. The night store sells coping mechanisms (permanent) and venting trades (cooldown-based cortisol dumps). No save — every run is fresh. |
| **🤝 Delegation** | Press **Q** near a chore station to make Luke do it (2× station time, 30% chance he takes a break instead). He refuses the basement toilet ("the pond") and won't stop gaming. Hold **E** to repair him when he breaks. The store sells persistent upgrades: Dishwasher, Robot Mop, Baby Monitor (these auto-complete their tasks daily). Day summary breaks down who did what. |
| **⚡ Combo-Mom** | 15-second game hours — a 4-minute day. Chain chores for a ×1–×8 combo multiplier and Taylor Points; fast minigame clears extend the combo window and pay speed bonuses. Spend points at the store (Second Wind, Advil, Coffee IV, Comfy Shoes). High score and best combo persist. |

Save files (per-mode, in the Godot user folder): `user://nightshift_save.cfg`,
`user://delegation_save.cfg`, `user://combo_save.cfg`. Meltdown deliberately
saves nothing.

## Controls

| Input | Action |
|---|---|
| ←/→ or A/D | Move |
| Space / Enter / W | Jump |
| E (near a station) | Play that station's minigame |
| Q (Delegation, near a chore) | Delegate the chore to Luke |
| E (Delegation, near broken Luke) | Repair Luke |
| R (on a day-over / run-over screen) | Next day / new run / retry day (mode-dependent) |
| M (anytime) | Back to the mode menu |

## How to run

You need a Godot 4.7+ editor or headless binary:

```
<path-to-godot> --path .
```

e.g. with the binary at `~/workspace/tools/godot/`:

```
~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path .
```

Or open the project folder in the Godot editor and press Play.

## Project layout

- `scripts/autoload/game_state.gd` — GameState singleton: meters, 7am–11pm clock,
  task list, day loop, scoring. Tuning constants (drain rates, clock speed) live
  at the top. Optional **mode hooks** (queried with `has_method`, so Classic
  implements nothing): `seconds_per_game_hour()`, `neglect_cortisol_rate()`,
  `cortisol_multiplier()`, `hud_tag()`, `day_summary_extras()`, etc. — the full
  contract is documented at the top of the file.
- `scripts/modes/mode_manager.gd` — ModeManager autoload: the five mode ids,
  creates the mode node for the selected mode.
- `scripts/modes/mode_night_shift.gd`, `mode_meltdown.gd`, `mode_delegation.gd`,
  `mode_combo_mom.gd` — the four variant rule sets, each a plain Node child of
  GameState that overrides only the hooks it needs.
- `scripts/modes/store_base.gd` + `store_night_shift.gd`, `store_meltdown.gd`,
  `store_combo_mom.gd` — walk-up night stores (Delegation reuses the
  station-based store).
- `scripts/modes/main_menu.gd` + `scenes/ui/main_menu.tscn` — the mode-select
  menu (main scene).
- `scripts/world.gd` — spawns stations + Luke into the tilemap level, plus the
  mode's store when it has one.
- `scripts/station.gd` — walk-up interactable (chore with hold-E progress bar,
  or fun with press-E serotonin).
- `scripts/luke.gd` — Luke NPC: wander AI, gaming/nagging, verbatim voice lines.
- `scenes/ui/hud.tscn` + `hud.gd` — meters, clock, task list, dialogue box,
  mode tag + mode widget dock, day-over / run-over report (R/M shortcuts).
- `taylor.gd` — player controller. `Main.tscn` — main scene + hand-built tilemap.

## Pushing to GitHub

This repo is meant to live at `LukeMcPartlan/Taylor-Simulator-Unified`
(suggested name; no remote is configured yet and nothing has been pushed).
Once GitHub auth is set up on your machine:

```
git remote add origin git@github.com:LukeMcPartlan/Taylor-Simulator-Unified.git
git push -u origin main
```

## Known issues

- Headless runs print `Grass9Tile.png ... Unable to open file` / tile-creation
  errors. Pre-existing: the repo references an imported texture whose source PNG
  isn't in the repo. Cosmetic only — no gameplay impact, no script errors.
- The tilemap has no basement interior, so the "basement toilet" chore was
  adapted: the leaking toilet flooded the low yard pond, and Taylor cleans it
  up there.
