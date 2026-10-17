# Ultimate — decoded Blessed runtime

This version is reconstructed from the supplied **Blessed** script, with its two window-title constants changed to **Ultimate**. It uses Blessed's recovered UI and gameplay program, rather than the separate Ultimate 1.1 implementation.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/OfficialUltimateMacro/Ultimate-Hoopz/main/Ultimate.lua"))()
```

## Editable source

`Ultimate.Blessed.decoded.lua` contains the decoded runtime: readable constants, prototype tables, named runtime helpers, and instruction handlers. Change `local BRAND = "Ultimate"` near the top to edit the title. There is no encrypted Luraph payload or original decoder bootstrap in this file.

**This is not the author's original handwritten source.** The program still uses register tables, instructions and program counters. Original variable names, comments and structured source were not recovered. It should not be described as a fully devirtualized source copy.

The original feature defaults, UI structure, supported-game branches, input logic, limits and external dependencies are retained. This copy therefore also retains original optional spoofing controls; they were not added by Ultimate. Features from the separate 1.1 redesign were not grafted onto this copy.

## Validation

- Lua syntax loading passed.
- All 164 recovered prototypes and their child links were checked.
- The reconstructed runtime and recovered original interpreter both completed mocked initialization with the same 654 recorded startup actions, including the Ultimate window title.
- The original safeword URL was retrieved and contained `digital` at the time of this build. Its check remains unchanged.

The mock does not run scheduled gameplay tasks or simulate a live game. This verifies the tested startup path, not every callback, server acceptance, anti-cheat behavior or pixel-level appearance in Roblox. No live Hoopz test was performed.

## Rebuilding

`python rebuild.py` regenerates the decoded runtime from `data/Blessed.decoded-program.json` and `data/Blessed.instruction-handlers.json`. The rebuild applies the two audited title substitutions. `branding-changes.json` records their locations. `reconstruction-manifest.json` records the file hash and publication status.

The original supplied script and the earlier independently authored Ultimate implementation remain separate local artifacts. Git history preserves the previous public build.
