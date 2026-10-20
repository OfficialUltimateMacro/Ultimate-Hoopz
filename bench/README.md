# Ultimate 1v1 benchmark (scripted AI opponent)

`bench.py` runs one Auto-play game against a scripted opponent on the shared
mock world (`tests/sim_fixture.lua`); `suite.py` runs builds x profiles x
seeds and aggregates.

```
LUA_DLL=/path/to/liblua55.so python bench/bench.py Ultimate.lua honest 1 16
SEEDS=20 POSS=16 JOBS=2 OUT=result.json python bench/suite.py Ultimate.lua honest,lockdown,magger
```

## Model (mock physics; assumptions, not measured Hoopz values)
- Half court, one hoop; every change of possession resets to check ball
  (offense 99 studs out, defender 81). Live turnovers keep the ball in the
  new holder's hands 0.6 s before the reset. 24 s shot clock.
- Movement 16 studs/s for both players, 2.5-stud body collision.
- Jumper: wind-up ShotDelay + 0.12 s. Make chance 0.60 inside 55-74 flat
  studs (0.08 outside), x(0.55 + 0.45*gap/6) inside 6 studs, x0.6 if the
  defender is airborne. 3 points at >= 50 studs.
- Dunk: T within 12 studs of the rim, 0.5 s, 0.93 success; 0.75 with a
  defender inside 4 studs of the rim, 0.45 if that defender is airborne.
- Steals: hazard per second while the defender is in reach; dribble moves
  (F/G/R/V/C/B/H) cut it to 25% for 0.4-0.6 s and can freeze the defender
  for 0.4 s. Strip hazard during the jumper wind-up.
- Misses and blocks become loose balls 4-14 studs from the rim; pickup
  radius 3 studs.

## Opponent profiles
| profile | defense | steal | strip | pickup |
|---|---|---|---|---|
| honest | 3.5 studs in front, 0.25 s reaction | 4 studs, 0.5/s | 4.5 studs, 1.2/s | 3 studs |
| lockdown | 3.0 studs, 0.15 s, 17 studs/s | 4 studs, 0.8/s | 4.5 studs, 1.6/s | 3 studs |
| magger | 13 studs off, grabs from range | 18 studs, 0.5/s | 18 studs, 2.5/s | 18 studs |

The AI offense routes to a 62-stud spot, shoots with 6+ studs of space or
after 9 s, crosses over, and drives/dunks when the defender is not between
it and the rim.

## Results (20 seeds x 16 possessions each side)
| build | profile | wins | points/possession (us vs AI) | shot clock violations | stolen |
|---|---|---|---|---|---|
| 0a36ad83 | honest | 0/20 | 0.15 vs 1.60 | 251 | 0 |
| new | honest | 18/20 | 1.86 vs 1.52 | 0 | 1 |
| 0a36ad83 | lockdown | 0/20 | 0.00 vs 1.42 | 249 | 71 |
| new | lockdown | 15/20 | 1.42 vs 1.36 | 0 | 27 |
| 0a36ad83 | magger | 0/20 | 0.00 vs 1.45 | 9 | 311 |
| new | magger | 0/20 | 0.14 vs 1.52 | 0 | 233 |

Pickup detector: honest and lockdown 0/40 games flagged; magger 20/20
reached "suspected" (manual confirmation prompt). Nothing is ever reported as
confirmed cheating.

These numbers measure decision logic against fixed scripted behaviour only.
They are not live Hoopz results.
