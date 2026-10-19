# Ultimate

Hoopz Auto-play with Ultimate branding and editable recovered runtime source.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/OfficialUltimateMacro/Ultimate-Hoopz/main/Ultimate.lua"))()
```

## Current behavior

- J toggles Auto-play. While active, the separate Auto Guard feature is locked off across its keybind, UI and mobile toggle. A Disabled notification explains that Auto-play handles defense. The previous standalone setting restores when Auto-play stops.
- Auto-play owns offense, possession transitions, hoop recovery, opponent-scoped defense and loose-ball recovery. Manual movement and camera intervention remain authoritative.
- Normal jumpers require at least12studs of current/predicted defender clearance and no nearby airborne contest. Route timeouts cannot bypass shot-space checks.
- Outcome counters are diagnostics only. Forced rim-only offense and adaptive deep defense have been removed. A turnover retreat expires after 2.5 seconds, then normal situational defense resumes.
- Rim approaches obey the same clearance checks as dribble routes. Dunk input requires a supported clear approach and sufficient separation. The planner holds and shields when no safe lane exists; it does not fall back to a raw target through a blocked route. An activated policy cannot guarantee a winning route.
- Moving routes are revalidated at a bounded0.05s cadence. Invalid commitments are replaced or stopped; court boundaries, walls, floor support and predicted positions constrain exits. The buffer is a heuristic, not knowledge of the game's hidden hitboxes. Independent player movement or game animations can still cause contact.
- Dribble chains use a0.075s input floor,0.16s ordinary repeat and0.32s R repeat cooldown. Actual game actions, shooting, manual input and key conflicts can delay inputs. Waiting with possession can use protective R/V/B fakes.
- Assisted camera yaw is faster while shielding or defending; long rim drives retain shielding until the close approach. Shots and manual input release camera ownership. Body turning uses native shift-lock; enable it manually when automatic controller access is unavailable. The script does not force character root orientation.
- Turnovers cancel stale offensive movement and prioritize hoop-side recovery. Defensive contest jumps do not invoke the aim routine while off-ball.

## Startup preferences

High arc; Shot Delay0.28; Aimbot on without its own keybind; standalone Auto Guard and Ball Check on; Auto Guard keyL; Auto-play off with keyJ; Ball Magnet off; Ball Reach on with strength2; WalkSpeed0.01; Anti Drop on. Auto-play temporarily applies its existing feature toggles while enabled and restores prior values afterward. Low and Mixed arc remain selectable. Mixed arc interpolates recovered endpoint offsets and power and is not live-calibrated.

## Source and build

Ultimate.lua and Ultimate.source.lua contain identical generated source. This is decoded register-source, not recovery of the original author's handwritten variable names, comments or structured source. The raw recovered program and instruction handlers remain in data/.

Editable modules: customizations.lua, extensions.lua, offense.lua, match.lua and defense.lua. Branding assets are in assets/. Rebuild from the package directory:

```text
python rebuild.py
```

The generator writes Ultimate.Blessed.decoded.lua. The release pipeline checks its manifest hash and binds passing test results to the exact published bytes, then updates main atomically and verifies the permanent loader URL.

## Validation and limitations

19 packaged offline suites plus a simulated startup check validate this release. They cover UI/key isolation, diagnostic-only outcome counters, shot-space refusal, safe dunk gating, route invalidation, turnovers, camera handback, input cleanup, court/holder scoping and bounded diagnostics. Simulation geometry and game services are simplified. They do not establish live scoring accuracy, steal resistance, real hitboxes, acceptance of moves or Roblox FPS. Safe waiting is reported separately from offensive success; a stalled possession is not a demonstrated win.

Copy Auto-play log exports local bounded events, move counts and tactical samples, including policy, defender gaps, reroutes, power and shot reasons. It does not send telemetry. Tests and engineering documentation use synthetic scenarios; private user media and personal gameplay logs are not included.

Local headphones: default off; Music controls opens a draggable panel with a blank audio ID, Play/Stop and volume (35% default). These custom client-local cosmetics and audio do not unlock a paid item. Audio must be permitted in the experience. Toggle off or unload removes the cosmetic and stops audio. Respawn reattaches the cosmetic. Module: headphones.lua; regression suite: test_local_headphones.py.

Pressure escapes: no four-attempt possession cap; retry interval reduced from 0.7 to 0.15 seconds. Six lateral/backward-diagonal candidate exits are checked against court, floor, obstacles and predicted opponent spacing. Input action gates and shot ownership remain enforced. These offline checks do not prove live ball retention or scoring.
