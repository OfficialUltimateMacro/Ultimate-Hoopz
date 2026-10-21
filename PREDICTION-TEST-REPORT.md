# Auto-play prediction: test report

Generated artifact: `Ultimate.Blessed.decoded.lua`
SHA-256: `a88805d4b09eac64f399a868c4f995f903769924e55433186d9ac2ff9593f75c`
Branch `codex/autoplay-prediction` on top of 094feb1. Not committed, not published. Not live-tested.

## Reproduce
```
python rebuild.py
set LUA_DLL=C:\Lua\lua55.dll        (or export LUA_DLL=/path/liblua55.so)
for %f in (tests\test_*.py) do python %f
```
Every `tests/test_*.py` must exit 0. The simulated startup check
(`work/test_ultimate_preferences.py` from the release workspace) also passed on
this artifact; it caught the slider `Suffix` crash described below.

## Results
- 25/25 suites pass (23 existing + `test_autoplay_prediction.py` + `test_toss_tracking.py`).
- `test_toss_tracking.py` fails on the published 094feb1 build (it idles while the ball is up), passes here.
- `test_rim_strategy.py` was updated on purpose: the rim strategy now closes out a
  shooter in range instead of camping under the rim.
- Synthetic prediction error 0.3 s ahead (mean studs, old blend -> new):
  straight 0.00 -> 0.00, crossover 2.49 -> 2.45, stop-and-go 0.90 -> 0.88.
  These measure the motion read only and are close to the old method.

## 1v1 mock benchmark (bench/, scripted AI; not live results)
| condition | 094feb1 | this build |
|---|---|---|
| rim strategy forced on, honest shooter (8 games) | 2/8 wins, 1.60 vs 1.88 PPP | 7/8 wins, 1.75 vs 1.57 PPP |
| honest (8-10 games) | 7/8, 1.82 vs 1.40 | 9/10, 1.88 vs 1.34 |
| lockdown (20 games) | 7/20, 1.24 vs 1.42 | 9/20, 1.37 vs 1.41 |
| magger (10 games) | 0 wins | 0 wins (unchanged) |

## What changed
- prediction.lua (from Codex, reviewed): separate Auto-play tuning (prediction 0-600 ms,
  smoothing, max lead, close-out spacing, contest distance, adaptive toggle), motion reads
  with reset/teleport/stop/reversal handling. Added a "start" case (restart from a stop
  skips smoothing). Slider titles carry the unit because Blessed's slider crashes on a
  string `Suffix`.
- defense.lua: uses the Auto-play prediction (never AutoGuardPrediction), close-out
  spacing and contest distance settings; full lead unless the read was reset; checked
  routes (wall/floor/court) with up to 4 detours and a 25-raycast budget, otherwise hold
  (no stale target); DefendedGoal nil-arithmetic edge fixed; contest jumps run even while
  holding.
- Rim strategy: an attacker inside shooting range (<= 80 studs 3D) is closed out
  normally; beyond range the defender waits on his line at <= 55 studs from the rim.

## Opponent tosses the ball up (live clip, Oct 20)
In the clip the attacker threw the ball up over the defender, ran around and caught it;
Auto-play saw a "loose ball", idled/chased with spacing avoidance, then treated his catch
as a turnover and retreated to the hoop.
- extensions.lua: Opponent -> Loose records who released it and whether it was a shot
  (Shooting/Dunking Action within 1.2 s). Catching his own toss is the same possession
  (no turnover retreat).
- match.lua: TossRead predicts the landing point (gravity 196.2, up to 3 s; a ball
  landing within 7 studs of the rim counts as a shot). TossStep goes for the ball when we
  get there 0.15 s+ earlier, otherwise guards the catch point on the rim side with the
  close-out spacing (checked route or hold). Loose-ball chases no longer use opponent
  spacing avoidance (walls/floor still checked).
- Benchmark `tosser` profile (12 games each): 094feb1 allowed 1.26 points per possession,
  this build 0.57; honest 1.00 allowed, lockdown 1.27 allowed (10 games each). Mock only.
