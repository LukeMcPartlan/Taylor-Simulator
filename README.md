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
| Change baby | Diaper Catch | Catch diapers, dodge rubber ducks (A/D); 8 diapers |
| Book | Reading Focus | Hold SPACE to read, release before restlessness maxes |
| Phone | TikTok Swipe | Hit the matching arrow key in time; 10 hits |

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
  at the top.
- `scripts/world.gd` — spawns stations + Luke into the tilemap level.
- `scripts/station.gd` — walk-up interactable (chore with hold-E progress bar,
  or fun with press-E serotonin).
- `scripts/luke.gd` — Luke NPC: wander AI, gaming/nagging, verbatim voice lines.
- `scenes/ui/hud.tscn` + `hud.gd` — meters, clock, task list, dialogue box,
  day-over report.
- `taylor.gd` — player controller. `Main.tscn` — main scene + hand-built tilemap.

## Pushing to GitHub

This repo already exists as `LukeMcPartlan/Taylor-Simulator` (remote `origin`).
Once GitHub auth is set up on your machine:

```
git push origin main
```

## Known issues

- Headless runs print `Grass9Tile.png ... Unable to open file` / tile-creation
  errors. Pre-existing: the repo references an imported texture whose source PNG
  isn't in the repo. Cosmetic only — no gameplay impact, no script errors.
- The tilemap has no basement interior, so the "basement toilet" chore was
  adapted: the leaking toilet flooded the low yard pond, and Taylor cleans it
  up there.
