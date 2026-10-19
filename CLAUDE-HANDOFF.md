# Ultimate maintenance handoff

Current release priorities: situational defense, pressure escape routes, standalone Auto Guard isolation and local headphones.

## Module map

- customizations.lua: startup constants and branding resolution. High arc, ShotDelay0.28, BallMagnetfalse, ReachStrength2.
- extensions.lua: state machine, input ownership, notifications, UI hooks, render movement, bounded diagnostics and Auto Guard lock.
- offense.lua: cached reads, steering/clearance, ReactiveRoute, camera/shift-lock, dribble selection, ProtectiveIdle, shot/dunk input and result tracking, RiskProfile/ObserveRisk/SyncRisk.
- match.lua: court and opponent scope, goal labels, manual court correction and predicted loose-ball recovery.
- defense.lua: basket-side defense, turnover retreat, adaptive hoop protection and contests.
- rebuild.py: authoritative source generator; do not regenerate with obsolete one-time transforms.

## Important contracts

1. Auto-play must keep standalone AutoGuardfalse. SetFeature clamps it; EnforceGuardOff syncs UI and key/mobile/UI callback hooks prevent reenable. Native callback IDs: root.1061 UI, root.1168 mobile, root.2169 keyboard. Own Auto-play defense remains active. Restore the prior standalone preference when Auto-play stops.
2. root.106 must not invoke an aim routine for an off-ball contest jump during Auto-play. Manual non-Auto-play behavior remains native.
3. CanTakeShot no longer refuses on defender spacing (user preference: shoot through contests). OffenseStep keeps only a bounded pump fake (at most 0.25 s) against an airborne defender within 7 studs. The near-hoop line relaxation after 8 s is unchanged.
4. Outcome counters stay diagnostic. The conditional rim strategy (pickup.lua) is driven only by suspected abnormal pickup evidence or the manual override. SyncRisk no longer writes AdaptiveRimOnly; UpdateRimStrategy owns it.
5. DunkMode cannot bypass PossessionPathClear or ReactiveRoute. No raw-rim fallback after failed steering. T needs space and a supported clear approach. Adaptive clearance uses10studs versus normal8plus speed margin. Game movement/animations remain outside these guarantees.
6. Camera owns yaw only during assistance; original shots/manual control must win. No root.CFrame forcing. Native/manual shift-lock is required for body-camera alignment. Long rim routes shield; final approach squares toward the rim.
7. Retry spacing stays1.25s to avoid replacing a one-second release observation prematurely. Failed input and actual release are distinct. Never report scores from near-rim passes alone.
8. Hold behavior uses ProtectiveIdle R/V/B only when not preparing a shot or executing Shooting/Dunking. Respect input and action cooldowns.

## Validation and publishing

19 packaged suites plus startup passed against the generated source hash in test-results.json. New test_adaptive_policy covers guard entry points, notification/restoration, diagnostic-only outcomes, opponent scoping, clear-space gating, deep defense, safe holding and no unsafe dunk fallback. Older shot assertions were intentionally changed from forced contests to waiting, per current behavior. Simulations do not measure live retention, scoring or frame cost.

The local release pipeline uses work/publish_main.py, verifies exact passing-build hashes, atomically updates main and verifies the bare permanent URL. Keep the single main/Ultimate.lua loader. github-publication.json and reconstruction-manifest.json record published identity; refresh the retained source package after verification. Do not include private recordings, player-specific logs or personal media-derived results in public notes.

Local headphones: default off; Music controls opens a draggable panel with a blank audio ID, Play/Stop and volume (35% default). These custom client-local cosmetics and audio do not unlock a paid item. Audio must be permitted in the experience. Toggle off or unload removes the cosmetic and stops audio. Respawn reattaches the cosmetic. Module: headphones.lua; regression suite: test_local_headphones.py.

Pressure escapes: no four-attempt possession cap; retry interval reduced from 0.7 to 0.15 seconds. Six lateral/backward-diagonal candidate exits are checked against court, floor, obstacles and predicted opponent spacing. Input action gates and shot ownership remain enforced. These offline checks do not prove live ball retention or scoring.

## Latest (Claude): conditional rim strategy, contested shots, Ball Magnet, escapes, local audio

- pickup.lua (appended after match.lua by rebuild.py): CourtBallSample requires exactly one ball on the locked court. SamplePickups runs each Heartbeat while Auto-play is on, keeping a 1.2 s / 90-sample history plus marks (teleport, respawn, ball teleport, made basket, out of court, ambiguous, Ingame change, court change). EvaluatePickup only scores possession changes into a court opponent's hands. Rejection reasons and the allowance formula are in README. PickupLevel decays evidence. UpdateRimStrategy is called from AutoPlayStep and logs only on change. ConfirmSuspectedOpponent and ClearRimStrategy back the UI buttons. Settings: AutoPlayMagnetResponse ("Manual confirm" default / "Off" / "Auto (experimental)") and AutoPlayRimOverride=false.
- Offense: rimStrategy forces DunkMode except for the 2.5 s blocked-lane fallback (RimBlockedSince). Defense: a camping branch when AdaptiveRimOnly and rimDistance >= 20, with step-up via CampFarSince.
- Ball Magnet: removed from Auto-play's applied set. Install forces settings.BallMagnet=UltimatePreferences.BallMagnet (false) on both settings-table branches. A manual enable survives Auto-play toggles.
- Escapes: square-defender side persistence, flip guard (3 flips/3 s locks the side for 1.2 s), midpoint/separation scoring, and SpaceReset (1.5 s blocked, every 1.2 s, combined repulsion, 7 angles). MoveRefusal records why an input was refused.
- Headphones: 16-part curved design. ResolveMusicSource accepts an ID, an MP3/OGG link (HttpGet, signature check, 15 MB cap, writefile to UltimateMusic/, getcustomasset) or a workspace file, with clear privacy/unsupported messages.
- Tests: test_pickup_evidence.py, test_rim_strategy.py and test_escape_stability.py (the last also takes a build path; the previous published build fails side-flip stability and the court-edge box). Contested-shot assertions were updated per the user's preference. work/run_release_tests.py generates test-results.json (22 suites + startup) bound to the build SHA, and publish_main.py requires every tests/test_*.py result plus startup.
- Research: public Hoopz documentation is vague; mechanics come from decoded Blessed and user-supplied footage. Nothing here is live-verified.

## Follow-up (Claude): live-game log fixes

From a user-supplied Auto-play log (not stored in the repository): possessions began about 99 studs out after resets and were lost within 3-4 s while escaping sideways; the pickup sampler never evaluated an event (normal=0), consistent with an extra static ball on the court. Changes: CourtBallSample ignores balls never seen held or moving (BallMotion) and counts sampler outcomes; reset pause 0.6 -> 0.25 s; ReactiveRoute stops count toward the SpaceReset fallback. A straight-line "attack into range" variant was tried and reverted because tests/test_checkball_attack.py (0.25 s delayed defender, STEAL radius env, default 6) showed it lost every possession versus 4/4 for the previous release. Current build equals the previous release on that drill (4/4 at radius 6, 3/4 at 8); a wider route buffer (9-11) did not help.

## Rim finish, sampler identity, early-jumper spacing
- offense.lua: TryDunk has no SpaceAt gate and only a geometry (WalkClear) approach check; new RimFinishPoint steps to the rim side away from the nearest defender. The DunkMode branch uses it inside DunkReach+8 with no dribble moves. Accepted dunks raise DunkReach by 0.5 (cap 12).
- CanTakeShot: a defender within 7 studs blocks a jumper for the first 2.5 s held (live logs showed jumpers stripped mid-routine); after that, contested shots go. The check-ball drill still shoots 4/4.
- pickup.lua CourtBallSample: held ball wins; a loose part within 7 studs of the holder counts as the same ball; strays are ignored while one is held; multiple loose balls resolve to the tracked/nearest ball (ambiguous only if tied within 6 studs or nearest >30). The regression is in test_pickup_evidence (0b).
- Live behaviour unverified.
