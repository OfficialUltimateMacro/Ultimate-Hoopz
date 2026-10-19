# Ultimate maintenance handoff

Current release priorities: standalone Auto Guard isolation, outcome-based rim-only adaptation, strict clear-space shooting and safe dunk approaches. README describes current behavior and defaults; historical release notes have been replaced with this engineering-only reference.

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
4. Outcome profiles are keyed by opponent UserId/name and bounded12entries. Two failed jumper releases or three possession-loss transitions activate rim-only mode. FinishShotTrack and UpdateState feed observations. This is a heuristic response, not cheat detection. Mode stays opponent-specific and session-local. Counter gaps over90s reset counters, while an already activated mode persists for that opponent.
5. DunkMode cannot bypass PossessionPathClear or ReactiveRoute. No raw-rim fallback after failed steering. T needs space and a supported clear approach. Adaptive clearance uses10studs versus normal8plus speed margin. Game movement/animations remain outside these guarantees.
6. Camera owns yaw only during assistance; original shots/manual control must win. No root.CFrame forcing. Native/manual shift-lock is required for body-camera alignment. Long rim routes shield; final approach squares toward the rim.
7. Retry spacing stays1.25s to avoid replacing a one-second release observation prematurely. Failed input and actual release are distinct. Never report scores from near-rim passes alone.
8. Hold behavior uses ProtectiveIdle R/V/B only when not preparing a shot or executing Shooting/Dunking. Respect input and action cooldowns.

## Validation and publishing

18packaged suites plus startup passed against the generated source hash in test-results.json. New test_adaptive_policy covers guard entry points, notification/restoration, actual failed-release adaptation, opponent scoping, clear-space gating, deep defense, safe holding and no unsafe dunk fallback. Older shot assertions were intentionally changed from forced contests to waiting, per current behavior. Simulations do not measure live retention, scoring or frame cost.

The local release pipeline uses work/publish_main.py, verifies exact passing-build hashes, atomically updates main and verifies the bare permanent URL. Keep the single main/Ultimate.lua loader. github-publication.json and reconstruction-manifest.json record published identity; refresh the retained source package after verification. Do not include private recordings, player-specific logs or personal media-derived results in public notes.
