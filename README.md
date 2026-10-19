# Ultimate

Hoopz Auto-play with Ultimate branding and editable recovered runtime source.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/OfficialUltimateMacro/Ultimate-Hoopz/main/Ultimate.lua"))()
```

## Current behavior

- J toggles Auto-play. While active, the separate Auto Guard feature is locked off across its keybind, UI and mobile toggle. A Disabled notification explains that Auto-play handles defense. The previous standalone setting restores when Auto-play stops.
- Auto-play owns offense, possession transitions, hoop recovery, opponent-scoped defense and loose-ball recovery. Manual movement and camera intervention remain authoritative.
- In-range jumpers with a clear basket line are taken even when contested or with no space. Only a defender already airborne within 7 studs triggers a bounded pump fake (at most 0.25 s) before the shot.
- Outcome counters (turnovers, failed releases, contested shots) are diagnostics only and never select a strategy. A turnover retreat expires after 2.5 seconds, then normal situational defense resumes.
- Rim finish: within DunkReach + 8 studs of the rim, Auto-play stops dribble moves, steps toward the side of the rim away from the nearest defender, and sends T without waiting for defender separation. Only geometry (walls/poles) between the player and the rim holds the dunk. Accepted dunks raise the dunk reach by 0.5 stud (max 12); unaccepted ones lower it by 2 (min 4). Farther out, rim drives still use the normal route clearance checks and hold/shield when no lane exists.
- Jumpers: during the first 2.5 s of a possession, a jumper is not started with a defender inside 7 studs (steal reach); the player drives/dunks instead. After 2.5 s held, contested and zero-space jumpers go up.
- Pickup sampler game-ball identity: a held ball is the game ball; a ball part within 7 studs of its holder (the dribbled copy) is the same ball; stray loose balls are ignored while one is held; with several loose balls, the previously tracked one or the one clearly nearest the match players is used.
- Moving routes are revalidated at a bounded0.05s cadence. Invalid commitments are replaced or stopped; court boundaries, walls, floor support and predicted positions constrain exits. The buffer is a heuristic, not knowledge of the game's hidden hitboxes. Independent player movement or game animations can still cause contact.
- Dribble chains use a0.075s input floor,0.16s ordinary repeat and0.32s R repeat cooldown. Actual game actions, shooting, manual input and key conflicts can delay inputs. Waiting with possession can use protective R/V/B fakes.
- Assisted camera yaw is faster while shielding or defending; long rim drives retain shielding until the close approach. Shots and manual input release camera ownership. Body turning uses native shift-lock; enable it manually when automatic controller access is unavailable. The script does not force character root orientation.
- Turnovers cancel stale offensive movement and prioritize hoop-side recovery. Defensive contest jumps do not invoke the aim routine while off-ball.

## Conditional rim strategy (suspected abnormal pickups)

Normal opponents get normal offense and situational defense. A separate, opponent-specific evidence system looks for **suspected abnormal pickups**: possession appearing in the locked opponent's hands while the last fresh client sample showed the ball beyond a generous reach allowance. Client observations cannot prove cheating, so nothing is ever labelled confirmed.

- Allowance: max(14, 9 + (ball speed + opponent speed) x (sample age + 0.25 s latency) + 2) studs, with a vertical allowance of 6 studs.
- Rejected, with the reason logged: stale samples (>0.25 s), missing prior samples, opponent or local respawn/teleport, ball teleport (inbound/reset), made-basket handover, ball leaving the court, multiple balls, match-state changes, direct transfers between other players (passes), players who are not the locked opponent, the same possession counted twice, and events less than 5 s apart. Nearby steals, rebounds and contested or failed shots are normal pickups.
- Evidence decays (time constant 120 s, window 300 s), is bounded to 8 events, and resets when the court or opponent changes. Levels: none, suspected (2 independent events, score at least 1.5) and strong (3 events, score at least 2.4, median excess at least 6 studs).
- **Magnet response** setting: *Manual confirm* (default) prompts once with the evidence and waits for **Confirm suspected opponent**; *Auto (experimental)* activates only at strong evidence and exits when the score falls below 1.0; *Off* never acts. **Rim strategy override** forces the strategy for testing without evidence or accusation, and **Clear rim strategy** resets confirmation and override. A confirmation expires when evidence decays.
- While active, offense prefers safe drives and dunks (all route and clearance checks still apply). After 2.5 s with a blocked rim lane, a normal in-range jumper is allowed. Defense stays deep on the attacker-rim line (up to 9 studs from the hoop), faces and tracks the attacker laterally, steps up when the attacker lingers beyond 55 studs for 6 s, uses normal rim protection and contests inside 20 studs, and still recovers loose balls and rebounds. Normal turnover recovery is unchanged.
- Only balls seen held or moving count as the game ball, so static rack/decor balls on a court no longer make every sample ambiguous. Shot status shows sampler counts (`samples[...]`).
- Limitation: a magnet that physically drags the ball close before pickup looks like a normal pickup and is not detected.

## Pressure escapes

After a score/reset teleport the controller pauses 0.25 s (was 0.6 s) before playing. A check-ball drill (reset about 99 studs out, defender closing with a 0.25 s reaction delay) is a regression test; this release matches the previous release there and does not claim an improvement in steal avoidance.


The four-attempt cap stays removed and the retry interval stays at 0.15 s, with six lateral/backward-diagonal exits. Against a square defender the planner now keeps its previous side instead of alternating. Three side changes within 3 s lock the side for 1.2 s. Exits are scored on end and midpoint clearance against current and predicted positions plus separation gained. After 1.5 s without any safe route, a bounded space reset moves up to 10 studs along the combined push-away direction from nearby defenders, at most every 1.2 s and only on the court. Refused moves and routes are reported in Shot status (`Refused: move ... | route ...`).

## Startup preferences

High arc; Shot Delay0.28; Aimbot on without its own keybind; standalone Auto Guard off (L or its toggle enables it); Ball Check on; Auto Guard keyL; Auto-play off with keyJ; Ball Magnet off; Ball Reach on with strength2; WalkSpeed0.01; Anti Drop on. Auto-play temporarily enables Aimbot and Ball Reach and disables standalone Auto Guard, restoring prior values afterward. Ball Magnet is never enabled automatically: it starts off and only changes when you toggle it. Low and Mixed arc remain selectable. Mixed arc interpolates recovered endpoint offsets and power and is not live-calibrated.

## Source and build

Ultimate.lua and Ultimate.source.lua contain identical generated source. This is decoded register-source, not recovery of the original author's handwritten variable names, comments or structured source. The raw recovered program and instruction handlers remain in data/.

Editable modules: customizations.lua, extensions.lua, offense.lua, match.lua, pickup.lua, defense.lua and headphones.lua. Branding assets are in assets/. Rebuild from the package directory:

```text
python rebuild.py
```

The generator writes Ultimate.Blessed.decoded.lua. The release pipeline checks its manifest hash and binds passing test results to the exact published bytes, then updates main atomically and verifies the permanent loader URL.

## Validation and limitations

23 packaged offline suites plus a simulated startup check validate this release, bound to the exact generated SHA by work/run_release_tests.py. New suites cover pickup evidence (normal steals, single anomalies, stale/duplicate/reset rejection, decay, manual/auto/off/override, scoping), the rim strategy versus normal play, and escape stability.

Copy Auto-play log exports local bounded events, move counts and tactical samples, including policy, defender gaps, reroutes, power and shot reasons. It does not send telemetry. Tests and engineering documentation use synthetic scenarios; private user media and personal gameplay logs are not included.

Local headphones: default off, now with a curved band and round ear cups. Music controls opens a draggable panel with a blank source field, Play/Stop and volume (35% default). The field accepts a Roblox audio ID, a direct MP3/OGG link, or an MP3/OGG file in the executor workspace. Roblox only plays audio an experience may use (same creator, under 6 seconds, or Roblox/licensed catalog), so most uploaded IDs are blocked. Links and files are validated, saved under UltimateMusic/ and played locally through getcustomasset when the executor provides it. These custom client-local cosmetics and audio do not unlock a paid item. Audio must be permitted in the experience. Toggle off or unload removes the cosmetic and stops audio. Respawn reattaches the cosmetic. Module: headphones.lua; regression suite: test_local_headphones.py.

