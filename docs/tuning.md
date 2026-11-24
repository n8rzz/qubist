# Tuning: scoring and dealing

The values in `config/game.json` and `config/pieces.json`, how they were picked, and how to check them again. First pass: #21, November 2026.

## Target

From the PRD: short sessions of 3–10 minutes, with a median of 5 minutes or more. At an assumed 4 seconds a move, that is about 45–150 moves, with a median of 75 or more.

## How to measure

`tools/simulate.gd` plays many games through the real core and prints the spread of moves, score, lines, longest streak and best combo:

```sh
godot --headless --path . --script res://tools/simulate.gd -- --games=200 --bots=random,mixed
```

The options are listed at the top of the script. Config values can be overridden per run (`--rerolls=`, `--ppc=`, `--streak=`, `--weight=bar2:0.5`) without editing the JSON. Each game is seeded, so runs repeat exactly.

Three bots stand in for a range of players:

| Bot | Plays | Stands in for |
| --- | --- | --- |
| `random` | a random tray piece on a random legal spot | a careless or brand-new player |
| `mixed` | the greedy move half the time, a random one otherwise | a typical player (best guess) |
| `greedy` | tries every piece on every spot; most cubes cleared, then low and tightly packed | a strong player who can see every spot |

Real players sit somewhere between `random` and `greedy`. They are probably closer to `mixed`, since spots hidden inside the tower are hard to see.

## Chosen values

| Setting | Before | Now | Why |
| --- | --- | --- | --- |
| `bar2` weight | 1.0 | **0.5** | Small pieces almost always fit, so they set how long games last. Halving them shortens `mixed` games by about 22% and `random` games by about 10% (below). |
| `corner3` weight | 1.0 | **0.5** | Same reason as `bar2`. |
| `cube2`, `bar4`, `L4` weights | 1.0 | 1.0 | Unchanged. The PRD keeps the cube's weight as a late-game challenge. With the small pieces halved, its share of deals rises from 20% to 25%. |
| `dealer.max_rerolls` | 5 | 5 | No measurable effect (below). Kept as cheap insurance against an unplayable deal. |
| `points_per_cube_cleared` | 10 | 10 | Gives a wide, readable score spread (below). |
| `streak_bonus` | 50 | 50 | Rewards skill without swamping casual scores (below). |

Changing weights does not change the save signature, so saved games still resume.

## Results

200 games per bot, seeds 1–200, `--max-moves=3000` for `mixed` (no game reached it). The `greedy` rows are from 6 games capped at 1,500 moves, since its games don't end.

### Before (all weights 1.0)

| Bot | Moves p10 / median / p90 | Score p10 / median / p90 | Streak share of score |
| --- | --- | --- | --- |
| random | 68 / 86 / 107 | 780 / 2,130 / 4,000 | 13% |
| mixed | 152 / 214 / 293 | 8,030 / 13,270 / 20,490 | 30% |
| greedy | never lost (6 of 6 games hit 1,500 moves) | about 140,000 at move 1,500 | 49% |

### After (`bar2` and `corner3` at 0.5)

| Bot | Moves p10 / median / p90 | Score p10 / median / p90 | Streak share of score |
| --- | --- | --- | --- |
| random | 62 / 77 / 98 | 930 / 2,150 / 4,110 | 12% |
| mixed | 118 / 167 / 239 | 6,650 / 11,110 / 18,470 | 29% |

At 4 seconds a move, a `random` game is now about 5 minutes and a `mixed` game about 11, down from about 6 and 14.

### What was tried

- **Reroll limit.** 0, 2, 5 and 10 rerolls gave the same results to within one game in 200, for both `random` and `mixed`. A reroll only happens when no piece in a fresh tray fits anywhere. With 2- and 3-cube pieces in the mix that almost never happens before the game is already lost.
- **Small-piece weights at 0.25.** `mixed` games drop to a median of about 146 moves, and `random` games would fall below the 5-minute median. That's past the target for casual players, for little extra gain.
- **Doubling `bar4` or `L4`.** No clear change to game length.

### Scoring

- The score spread is wide at every skill level: p90 is about 4× p10 for `random` and 2.5× for `mixed`, so a better game shows clearly as a better score.
- The streak bonus is 12% of a casual score, about 30% of a typical one and about half of a strong one. It's the main thing that separates good play from long play, which is what a leaderboard should reward. No change.

## Open issue: strong play never ends

The `greedy` bot never lost a game, under any config tried: no small pieces at all, the cube at 3× weight, and no rerolls all still reached the move cap. A 6×6 floor is easy to keep clearing when every spot is visible. So no config value can bound a game for a player who plays close to perfectly. Ending those games needs a rule change, such as difficulty that ramps up over time. That is out of scope for the MVP's "no new rules", so it is left for a product decision.

## When to re-run

After any change to the piece list (for example #177) or to the scoring rules. Re-run `random` and `mixed` at 200 games and update the tables above.
