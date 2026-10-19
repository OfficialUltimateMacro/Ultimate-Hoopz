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
3. CanTakeShot performs spacing checks before any timeout-based near-hoop line relaxation. No contested-shot timeout override. Normal required gap12studs, with additional airborne-contest refusal.
- Outcome counters are diagnostics only. Forced rim-only offense and adaptive deep defense have been removed. A turnover retreat expires after 2.5 seconds, then normal situational defense resumes.
5. DunkMode cannot bypass PossessionPathClear or ReactiveRoute. No raw-rim fallback after failed steering. T needs space and a supported clear approach. Adaptive clearance uses10studs versus normal8plus speed margin. Game movement/animations remain outside these guarantees.
6. Camera owns yaw only during assistance; original shots/manual control must win. No root.CFrame forcing. Native/manual shift-lock is required for body-camera alignment. Long rim routes shield; final approach squares toward the rim.
7. Retry spacing stays1.25s to avoid replacing a one-second release observation prematurely. Failed input and actual release are distinct. Never report scores from near-rim passes alone.
8. Hold behavior uses ProtectiveIdle R/V/B only when not preparing a shot or executing Shooting/Dunking. Respect input and action cooldowns.

## Validation and publishing

19 packaged suites plus startup passed against the generated source hash in test-results.json. New test_adaptive_policy covers guard entry points, notification/restoration, diagnostic-only outcomes, opponent scoping, clear-space gating, deep defense, safe holding and no unsafe dunk fallback. Older shot assertions were intentionally changed from forced contests to waiting, per current behavior. Simulations do not measure live retention, scoring or frame cost.

The local release pipeline uses work/publish_main.py, verifies exact passing-build hashes, atomically updates main and verifies the bare permanent URL. Keep the single main/Ultimate.lua loader. github-publication.json and reconstruction-manifest.json record published identity; refresh the retained source package after verification. Do not include private recordings, player-specific logs or personal media-derived results in public notes.

Local headphones: default off; Music controls opens a draggable panel with a blank audio ID, Play/Stop and volume (35% default). These custom client-local cosmetics and audio do not unlock a paid item. Audio must be permitted in the experience. Toggle off or unload removes the cosmetic and stops audio. Respawn reattaches the cosmetic. Module: headphones.lua; regression suite: test_local_headphones.py.

Pressure escapes: no four-attempt possession cap; retry interval reduced from 0.7 to 0.15 seconds. Six lateral/backward-diagonal candidate exits are checked against court, floor, obstacles and predicted opponent spacing. Input action gates and shot ownership remain enforced. These offline checks do not prove live ball retention or scoring.
