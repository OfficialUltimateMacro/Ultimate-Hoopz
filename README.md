Shot Delay default update (2026-10-18): default is now the existing slider minimum, 0.28 seconds (previously 0.32). Bounds and user adjustment remain unchanged. customizations.lua applies initializer root[6][1976]; startup preferences check verifies the default and displayed 0.28.

Current update (2026-10-18): Mixed arc is the default, ordered Low / Mixed arc / High. It averages native aim offsets and Power values; shared Auto-play range is 58–73 studs. Native endpoint tests pass, but live accuracy is uncalibrated.

New match.lua scopes holders, opponents and rebounds to a locked half court, retaining opponent and ball identity instead of selecting the first global holder. Opponent picker, Lock court here and Lock viewed hoop correct ambiguous adjacent courts. No verified game-specific court/team API exists; automatic nearest-hoop selection can require manual correction.

Camera assistance uses capability-checked native PlayerModule mouse-lock and AutoRotate=true, with no root.CFrame assignment. It restores owned lock and previous AutoRotate on manual/shot/disable/unload. If unavailable, enable native shift-lock manually; logs explain the fallback. The simulation models engine shift-lock separately; live integration remains unverified.

Dunk T holds 0.65s while continuing the approach until actual Shooting/Dunking action. No undocumented rim-hang control was added. Rebounds predict bounded landing points with court/floor checks. Logs include hoop coordinates, locked opponent, camera mode and movement distance.

13 packaged offline suites plus simulated startup validate the generated build. New test_match_context.py and test_mixed_arc.py cover global-holder rejection, exact ball tracking, moving dunks, native arc/power interpolation and restoration. Legacy 1D unit tests isolate court context, covered separately in 3D. Simulated shots now release the same ball instead of spawning an unrelated replacement.

Dribbles retain 0.10s minimum pacing and shots retain 1.25s retry spacing. A 0.9s retry overwrote the one-second release check before it finished; do not reintroduce that bug. Live Hoopz acceptance, accuracy and performance remain unverified.

Source remains decoded register-source, not the original author's handwritten code. Rebuild includes match.lua; publisher requires passing tests bound to the exact build hash. Permanent loader remains main/Ultimate.lua; see github-publication.json for actual publication status.

---

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
- **Auto-play camera** (default on; see round 3 above for current camera ownership). Shift-lock style: while Auto-play holds the ball the body squares toward the attack (blend of drive direction and basket, fully toward the rim inside 16 studs, toward the run when retreating, forward during escapes); the camera sits behind at a constant 14–22-stud radius and ~21° pitch looking up the court, with yaw rate-limited (body 9 rad/s, camera 2.6 rad/s) so it never swings. It pulls in only for walls. It releases instantly on WASD/arrows, physical Space, right mouse or any mouse movement (1 s pause, then eases back from your view), during any original aim routine (manual or automatic), during Hoopz Shooting/Dunking actions, possession loss, scriptable cameras, disable and unload, restoring the original AutoRotate.
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

## Auto-play round 3: defense, possession state, camera ownership

Derived from the 23-00-29 live recording (half-court 1v1, one hoop, 24 s shot clock).

- **Possession** follows Blessed's own selector rule: a player holds the ball when `Character.Basketball` contains `Ball`. An empty container left after a turnover no longer counts once that layout has been seen; until then the old existence check is kept so working offense is not lost.
- **State model** (debounced): Own, Opponent, Teammate, Loose, Shot (our shot/aim/dunk routine), Reset (teleport >25 studs, 0.6 s), Manual (with reason), Dead. Leaving Own for Loose waits 0.3 s (dribble reparenting); a confirmed opponent holder is acted on in about 0.12 s. Routes, plans, goals and pending inputs are cleared when their possession or character ends.
- **Defense** (`defense.lua`): the defended hoop is the goal on the attacker's court (nearest to the attacker, sticky for the possession), not the hoop nearest to us. Modes: Contain (6 studs, outside), Close out (4 studs, attacker within 80 studs of the hoop), Protect rim (near the basket or driving), Recover (beaten: cut back basket-side around the attacker, or sprint to the rim late in a drive). Drive velocity is led fully, side-to-side velocity partly. It never drifts farther from the hoop than the attacker, keeps to supported floor, holds still when already in a good spot, faces the attacker, and jumps only for a real Shooting/Dunking action or a rising jump within 9 studs. Planning runs at 20 Hz when the attacker is within 18 studs, 10 Hz otherwise. Ball Check jump matching still works.
- **Auto Guard**: turning Auto-play on switches Auto Guard off (Auto-play defends itself; one movement writer) and turning it off restores the value Auto Guard had before. While Auto-play runs, Blessed's guard loop does not move the character even if L is pressed.
- **Camera**: orbits the same focus as the Roblox camera at your current zoom radius (8–40 studs), so handing back is seamless; first person is respected (body only). Wall checks start at the head and ignore the ball, hitboxes, transparent, unanchored or small parts. Offense frames the basket; defense frames the attacker from the basket side. Pitch eases into 16–34°. Mouse/right-click/WASD/Space hand control back at once; the camera pause never stops defensive movement.
- **Reliability**: shot flag stuck >4 s, aim flag >5 s, a stale Hoopz Action >2.5 s and stalled movement (>2 s not approaching a target) recover with a log entry. One runtime error no longer disables Auto-play (5 errors in 10 s does).
- **Shots/dunks**: planned → input sent → Action seen → release confirmed (out of hand 0.15 s, not regained, not taken by an opponent) → closest pass of that one bound ball to the rim. A make is reported as not verifiable.
- **Diagnostics**: Shot status shows state and time in state, last transition, holder and jump target, basket and intent, why movement stopped, manual reason and remaining time, Action and busy flags, shot/dunk/contest counters and last error, plus the last 4 events. **Copy Auto-play log** copies the 60-entry event log (wall-clock + T+ seconds since Auto-play started) with `setclipboard` when available, including Humanoid died/ragdoll/physics state changes.

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
