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
- **Auto-play** is experimental and stays off by default. **J** toggles it; Auto-play key is editable and the UI switch follows the shortcut. Keyboard toggles show a two-second Auto-play Enabled/Disabled notification. It retains defense and loose-ball pickup, and now moves with possession to open shooting positions. It samples a shooting arc at the recovered aim range, scores travel and defender spacing, and steers around nearby players and collidable obstacles. Floor probes reject unsupported steps; blocked routes stop and replan. This is local tactical routing, not a full-map pathfinding or match strategy system.
- Shot dispatch now starts the original delayed aim routine independently of synthetic jump detection, matching the request-before-takeoff ordering of manual Space. It still requests a jump and suppresses duplicate native events, but an unconfirmed jump no longer silently skips shooting. The actual recovered VM press/release path is regression-tested with jump detection forced to fail. Existing server input acceptance and shot success remain unverified in live Hoopz.
- **Shot status** in Guard controls shows the latest dispatch/error, current blocker and attempt count. Rim/backboard hits within five studs of the target and at basket height no longer falsely reject the straight diagnostic ray for an arced shot. Farther walls still block.
- **Auto-play camera** (default on). Shift-lock style: while Auto-play holds the ball the body squares toward the attack (blend of drive direction and basket, fully toward the rim inside 16 studs, toward the run when retreating, forward during escapes); the camera sits behind at a constant 14–22-stud radius and ~21° pitch looking up the court, with yaw rate-limited (body 9 rad/s, camera 2.6 rad/s) so it never swings. It pulls in only for walls. It releases instantly on WASD/arrows, physical Space, right mouse or any mouse movement (1 s pause, then eases back from your view), during any original aim routine (manual or automatic), during Hoopz Shooting/Dunking actions, possession loss, scriptable cameras, disable and unload, restoring the original AutoRotate.
- Route steering briefly retains a clear exit direction to reduce left/right oscillation while penalizing predicted close defender intercepts.
- Opponent reads use nearby replicated positions, bounded velocity prediction, and airborne state. Defenders never veto a shot: in range with a basket line it shoots with zero space; contested shots fire without the settle pause; an airborne blocker within 7 studs gets one R pump fake and the release waits at most 0.45 s for them to land. Open early possessions take one step into the middle of the calibrated power table (60–72 studs low / 59–71 high). A 4.5 s possession clock stops spot-shopping and attacks the nearest ring point; after 8 s a repeatedly failing straight-line check no longer blocks the shot.
- **Offensive movement**: an on-ball defender in the path triggers a committed 0.5 s lateral escape away from his side (or toward the ball hand when he is square), paired with the matching move: F/G behind-the-back from the off hand, C when already on that side, V/B fake when square. A fast-closing defender gets a 0.22 s hesitation with R first. At most 4 escapes per possession, 0.7 s apart, so it cannot circle forever. Shot spots are re-sampled around the side you are on and only replaced when clearly better. **Second nearest** now only picks spots where that basket is nearest, so the recovered aimbot targets it.
- **Auto-dunk** (default on). Inside the jumper ring it drives to the near side of the rim and presses T. It also drives from the near edge of the ring (<64 studs) when pressed hard (<5 studs) and the corridor to the rim is empty. If neither the Hoopz Dunking action nor a release is seen, the next dunk tries 2 studs closer (min 4).
- **Verification**: after each shot routine the script watches the Character Action attribute, whether the ball left your hand within 1 s, and the closest loose-ball pass to the rim for 2.5 s. Shot status shows shots sent / released / reached rim (≤3.5 studs) and dunks sent / started, plus the latest result text.
- **Auto-dunk** (default on, Guard controls toggle). Inside the calibrated jumper ring (closer than ~55 studs to the rim) it drives to the rim instead of backing out to the three, and presses **T** within 9 studs (0.25 s hold, 1.2 s cooldown). Shot status counts Dunks. Whether Hoopz accepts the T dunk from that spot is not verified live.
- **Auto-play dribble** (default on): H, F/G, V/B, R, C as mapped. Reactive picks plus a varied fallback (never the same move twice in a row); during committed escapes the planned move is used instead. Cadence 0.10 s between moves, 0.20 s same move, 0.40 s R, 0.04 s holds.
- **Attack basket** chooses Nearest or Second nearest when acquiring possession. The selected basket is retained for that possession. Set the correct scoring side; the script does not know game-specific team/court assignments. The original shooting routine requires that intended basket to also be nearest at shot time.
- Manual movement or typing pauses Auto-play and clears its offensive plan. Possession loss, respawn, disable and unload clear routes and release keys. Disabling restores the feature values Auto-play changed where they still match. Queued shots recheck state; an original shot routine already executing may finish after disable.
- Ball Magnet **off by default**, strength **50**; Ball Reach enabled at **10**.
- Hoopz WalkSpeed **0.01**, the recovered slider maximum; Anti Drop enabled.
- Ultimate wordmark used for the header and floating icon.
- **Player collisions** remains experimental and defaults OFF in the Guard controls. It attempts local torso contact by enabling CanCollide and using the Default collision group on your torso and nearby living players' torsos within 20 studs. It leaves roots, limbs, accessories, velocities, ownership and server collision rules alone. Settings restore when disabled, when players leave range, on death/respawn and on unload. Replication, constraints or server physics may prevent pushing; actual movement of another player is not guaranteed. This is a local contact experiment, not a verified push feature.

The PNG is hosted in `assets/ultimate-wordmark.png`. When `getcustomasset`/`getsynasset` and `writefile` are available, the script downloads and caches it as `Ultimate-wordmark-061784a8.png` in the executor workspace. Downloads must have a PNG signature. If custom assets are unavailable, a pink Ultimate text wordmark is shown. The original Blessed logo is not used as a fallback.

The original optional spoofing controls remain. Readable additions are in `extensions.lua` and `offense.lua`. Rejoin before loading an updated version because the recovered script retains its original loaded-state guard.

## Performance (mocked, 10 simulated seconds)

`tests/test_performance.py` counts engine calls. Holding the ball with a shadowing defender, versus the previous build: raycasts 6976→1285, RaycastParams 764→10, GetPlayers 849→18, GetTagged 171→5, MoveTo 594→43, mock Lua CPU −47%. Seeking a loose ball: full workspace scans 10→1 (event-driven ball index), raycasts 1120→130, MoveTo 600→21. Part of the holding-ball reduction comes from changed behavior (committed escapes skip some steering), so it is not a pure like-for-like. Mock CPU time is relative only; real frame cost was not measured in Roblox.

## Validation

- Lua syntax loading passed.
- All 164 recovered prototypes and their child links were checked.
- Before gameplay additions, the reconstructed runtime and recovered original interpreter completed matching mocked startup traces. Current startup intentionally differs by removing the aim picker and adding the Auto-play controls.
- The original safeword URL was retrieved and contained `digital` at the time of this build. Its check remains unchanged.
- The extended mocked Hoopz route completed initialization, verified actual initialized settings and maximum slider values, and confirmed that only the guard keybind picker remains.
- Native extension regression checks cover guard-only L/notification and processed/typing input; target identity, switching, possession, cooldown and respawn; settings-table replacement; Auto-play enable/restore, manual pause, loose-ball ownership, shot range/cooldown, death and cleanup.
- Offense simulation covers possession movement and arrival at a calibrated shooting position, defender prediction/filtering and contest gates, wall/ledge steering, all seven mapped dribble keys, cooldown/release, manual input, guard-key conflicts, queued-shot cancellation, blocked routes and cleanup.
- Collision regression checks cover default-off, nearby torso-only changes, range/death/respawn/disable/unload restoration, current server baselines and preserving externally changed values.
- Native recovered-shot integration now runs the unmodified root.106 VM routine and verifies one actual mocked mouse press/release from the normal request path, including simultaneous executor/native input. Camera tests cover heading/position, mouse/manual/shot/possession/toggle release and original AutoRotate restoration. Stable-position settling is tested with stale velocity.
- Jump regressions cover native input, state fallback, takeoff confirmation, no duplicate shot, blocked-jump timeout, cancellation, Space release and preserving manually held Space. J toggle/UI synchronization and typing/processed-input behavior are checked. Collision and Auto-play labels are shortened to fit the narrow UI.
- Logo checks cover one shared download/cache for both icon locations, custom-asset failure fallback, and ordinary property assignments.

Startup mocks do not run original scheduled gameplay tasks. Native offense tests separately execute simulated movement and deferred shot/input callbacks. These checks do not verify live rendering, server acceptance, complete map navigation, anti-cheat behavior or live Hoopz gameplay. No live Hoopz test was performed. Portable native tests and prerequisites are in `tests/README.md`.

## Rebuilding

`python rebuild.py` regenerates the decoded runtime from `data/Blessed.decoded-program.json`, `data/Blessed.instruction-handlers.json`, `customizations.lua`, `extensions.lua`, and `offense.lua`. The original decoded data stays unchanged. `branding-changes.json` records title/logo substitution locations. `reconstruction-manifest.json` records the file hash and publication status.

The original supplied script and the earlier independently authored Ultimate implementation remain separate local artifacts. Git history preserves the previous public build.
