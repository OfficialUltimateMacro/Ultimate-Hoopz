# Offline native behavior tests

Run `python tests/test_ultimate_offense.py`, `python tests/test_ultimate_extensions.py`, and `python tests/test_ultimate_logo.py` from this folder's parent. Python uses Lua 5.5 through ctypes, with no Roblox or network connection. Set LUA_DLL to a Lua 5.5 shared library; the default on the build machine is C:\Lua\lua55.dll. The Lua library must expose luaL_openselectedlibs.

The offense suite simulates a flat world, obstacles, a ledge, replicated player motion, and deferred input/shot callbacks. It covers routing to a shot and arriving, close/jumping defender gates, friendly/remote-player filters, conservative rays, F/G/H/V/B/R/C choices, key release/cooldown, user-input/guard-key conflicts, and cancelling a queued shot. These are offline regressions, not proof of live game success or full-map navigation. The original guard regression isolates the prior planner; offense is tested separately.

The workspace also contains work/test_ultimate_preferences.py for full recovered Hoopz startup using the isolated original interpreter fixture. That test and its historical decoder dependencies are not copied here.

Run `python tests/test_player_collisions.py` for nearby torso-only contact changes, radius/death/respawn/disable/unload restoration and external-value preservation. This mock checks properties and cleanup, not actual physics or server-approved player pushing.

Run `python tests/test_auto_jump.py` for native Space/state jump requests, confirmed takeoff before shooting, duplicate JumpRequest suppression, timeout and cancellation, key release and physical Space preservation. Offense tests also cover close-grounded-defender R followed by another move within0.4s and R again after1.1s. Extension tests cover default J, UI synchronization and processed/typing input.

Run `python tests/test_auto_camera.py` and `python tests/test_original_shot.py`. Both share the vector/world fixture from test_ultimate_offense.py. The former checks camera/body alignment and restoration plus stable-position settling; the latter runs the original recovered VM shot routine and full native/executor dispatch integration, asserting exactly one mocked mouse press and release. These do not run Roblox, so they cannot prove the live native jump backend works.

Shot dispatch regressions now explicitly force RequestAutoJump to return false and assert the recovered VM still emits exactly one mouse press/release. Offense checks accept basket endpoint structures while preserving distant obstruction rejection. Full startup verifies Shot status UI creation.
