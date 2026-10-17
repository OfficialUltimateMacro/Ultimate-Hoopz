# Ultimate â€” decoded Blessed runtime

This version is reconstructed from the supplied **Blessed** script, with **Ultimate** branding and the requested startup preferences. It uses Blessed's recovered UI and gameplay program, rather than the separate Ultimate 1.1 implementation.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/OfficialUltimateMacro/Ultimate-Hoopz/main/Ultimate.lua"))()
```

## Editable source

`Ultimate.Blessed.decoded.lua` contains the decoded runtime: readable constants, prototype tables, named runtime helpers, and instruction handlers. Change `local BRAND = "Ultimate"` near the top to edit the title. There is no encrypted Luraph payload or original decoder bootstrap in this file.

**This is not the author's original handwritten source.** The program still uses register tables, instructions and program counters. Original variable names, comments and structured source were not recovered. It should not be described as a fully devirtualized source copy.

The recovered UI, supported-game branches and limits are retained, with the input and gameplay additions described below. Requested defaults are configured in `customizations.lua`:

- **Auto Guard key L**, explicitly labeled Auto Guard key. Its handler and notification affect only Auto Guard.
- Aimbot enabled with **no key binding or key picker**. Auto Guard and Ball Check enabled by default.
- Match target jump enabled: subscribes only to the original guard/Ball Check selector's current player, and rechecks that selector before jumping. Target changes, lost possession, death, respawn, own possession and manual movement are handled.
- **Auto-play (Experimental)** stays off by default. It retains defense and loose-ball pickup, and now moves with possession to open shooting positions. It samples a shooting arc at the recovered aim range, scores travel and defender spacing, and steers around nearby players and collidable obstacles. Floor probes reject unsupported steps; blocked routes stop and replan. This is local tactical routing, not a full-map pathfinding or match strategy system.
- Opponent reads use nearby replicated positions, bounded velocity prediction, and airborne state. Known non-neutral teammates are excluded. Close defenders, jumping contests and blocked shot lines delay shooting. It stops and settles before calling the existing aim routine. No opponent-input prediction, learned habits, court-rule inference or guaranteed win rate is claimed.
- **Auto-play dribble** defaults on within Auto-play. Controls from the user's two mapping screenshots: H switch handles; F/G behind-back left-to-right/right-to-left; V/B fake behind left/right; R fake out; C cross up. It chooses occasional moves from hand position, route direction and close defender pressure, with a 0.9-second cooldown and timed key release. T dunk is deliberately not triggered by this shooting planner. VirtualInputManager key events must be supported; unavailable dribble input does not stop movement planning.
- **Attack basket** chooses Nearest or Second nearest when acquiring possession. The selected basket is retained for that possession. Set the correct scoring side; the script does not know game-specific team/court assignments. The original shooting routine requires that intended basket to also be nearest at shot time.
- Manual movement or typing pauses Auto-play and clears its offensive plan. Possession loss, respawn, disable and unload clear routes and release keys. Disabling restores the feature values Auto-play changed where they still match. Queued shots recheck state; an original shot routine already executing may finish after disable.
- Ball Magnet enabled at **50**; Ball Reach enabled at **10**.
- Hoopz WalkSpeed **0.01**, the recovered slider maximum; Anti Drop enabled.
- Ultimate wordmark used for the header and floating icon.

The PNG is hosted in `assets/ultimate-wordmark.png`. When `getcustomasset`/`getsynasset` and `writefile` are available, the script downloads and caches it as `Ultimate-wordmark-061784a8.png` in the executor workspace. Downloads must have a PNG signature. If custom assets are unavailable, a pink Ultimate text wordmark is shown. The original Blessed logo is not used as a fallback.

The original optional spoofing controls remain. Readable additions are in `extensions.lua` and `offense.lua`. Rejoin before loading an updated version because the recovered script retains its original loaded-state guard.

## Validation

- Lua syntax loading passed.
- All 164 recovered prototypes and their child links were checked.
- Before gameplay additions, the reconstructed runtime and recovered original interpreter completed matching mocked startup traces. Current startup intentionally differs by removing the aim picker and adding the Auto-play controls.
- The original safeword URL was retrieved and contained `digital` at the time of this build. Its check remains unchanged.
- The extended mocked Hoopz route completed initialization, verified actual initialized settings and maximum slider values, and confirmed that only the guard keybind picker remains.
- Native extension regression checks cover guard-only L/notification and processed/typing input; target identity, switching, possession, cooldown and respawn; settings-table replacement; Auto-play enable/restore, manual pause, loose-ball ownership, shot range/cooldown, death and cleanup.
- Offense simulation covers possession movement and arrival at a calibrated shooting position, defender prediction/filtering and contest gates, wall/ledge steering, all seven mapped dribble keys, cooldown/release, manual input, guard-key conflicts, queued-shot cancellation, blocked routes and cleanup.
- Logo checks cover one shared download/cache for both icon locations, custom-asset failure fallback, and ordinary property assignments.

Startup mocks do not run original scheduled gameplay tasks. Native offense tests separately execute simulated movement and deferred shot/input callbacks. These checks do not verify live rendering, server acceptance, complete map navigation, anti-cheat behavior or live Hoopz gameplay. No live Hoopz test was performed. Portable native tests and prerequisites are in `tests/README.md`.

## Rebuilding

`python rebuild.py` regenerates the decoded runtime from `data/Blessed.decoded-program.json`, `data/Blessed.instruction-handlers.json`, `customizations.lua`, `extensions.lua`, and `offense.lua`. The original decoded data stays unchanged. `branding-changes.json` records title/logo substitution locations. `reconstruction-manifest.json` records the file hash and publication status.

The original supplied script and the earlier independently authored Ultimate implementation remain separate local artifacts. Git history preserves the previous public build.
