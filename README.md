# RangeFinder

RangeFinder is a World of Warcraft Forever addon that shows the current
target's precise distance whenever the client provides a valid distance or
usable world positions, at any distance and whether on foot or flying.
Only when neither precise source is available does it use an approximate
range bracket from the bundled LibRangeCheck-3.0 library.

| Measurement | Display |
|---|---|
| Checked or world-position distance | `23 yd`, rounded to the nearest whole yard |
| Approximate bracket | `10-30 yd` |
| Lower bound only | `50+ yd` |
| Selected target without an available measurement | `N/A` |
| No target | Box hidden |

The box sits directly above the standard target frame's portrait and follows
its position. There is no separate Edit Mode registration, preview, dragging,
or saved position. Font size is configurable under
**Options > AddOns > RangeFinder**, defaults to 14, and persists account-wide
within the integer range 8-32.

## Installation

With the game closed, run:

```powershell
.\Install-RangeFinder.ps1
```

The default destination is
`D:\World of Warcraft\_forever_\Interface\AddOns`. Override it if needed:

```powershell
.\Install-RangeFinder.ps1 -AddOnsPath 'E:\World of Warcraft\_forever_\Interface\AddOns'
```

Enable **RangeFinder** at character select. The installer copies the runtime
modules and licenses, removes the obsolete `EditMode.lua` from an existing
installation, and strips upstream `@do-not-package@` blocks from the installed
library. The vendored source remains intact for maintenance.

## Implementation

`Bootstrap.lua` loads saved settings, creates one controller, registers the
font-size slider, routes target/world events, and drives a throttled updater.
Distances refresh immediately on target changes and approximately every
0.1 seconds while a target exists; the per-frame updater is detached when
there is no target. Library calls bypass the range cache so
secret-GUID unit-token entries cannot leak the previous target's bracket.
Text, visibility, and font updates are applied only when their inputs change.

`RangeFinder.Core.New(adapter, savedSettings)` keeps client boundaries mockable:

- `hasTarget()` reports whether the target exists.
- `getDistance()` returns a finite non-negative yard value, a bounded range
  `{ minimum = n, maximum = m }` with `n < m`, a lower bound `{ minimum = n }`,
  or `nil` and an unavailable reason. Unexpected errors propagate.
- `view:SetText(text)`, `view:SetFontSize(size)`, and `view:SetVisible(visible)`
  update the box. `Display.CreateView` receives the portrait anchor.
- `diagnostic(message)` reports repaired font settings.

## Lightweight tests

From this directory, with a compatible Lua interpreter:

```powershell
lua .\tests\Run-Tests.lua
```

The harness covers range validation and formatting, controller lifecycle,
throttling, settings, display sizing, and mocked bootstrap range retrieval.
It is not loaded by the add-on and does not verify game-client behavior.

## Forever compatibility and remaining verification

The TOC targets interface `16001`. The public
[Forever UI source snapshot](https://github.com/Gethe/wow-ui-source/tree/9dc84f0d3bbae1768ac3405b3716000bd93eda06)
identifies itself as **1.60.1 (70862)**; this is not confirmation of the
installed build on the game machine.

The bootstrap first uses `UnitDistanceSquared("target")` when its validity flag
is true and the result is usable. Otherwise, if Forever exposes `UnitPosition`,
it calculates the three-dimensional distance between player and target world
positions in the same instance. Missing, invalid, or secret values are not
used for arithmetic. There is no distance threshold or flight-only condition.
World-position distance measures between unit positions, not spell reach or
hitbox edges; its availability and semantics still need in-game verification.
Only when neither precise source is usable does it fall back to approximate
library results. Estimates are never formatted as exact distances.
The library includes Forever-specific handling;
other WoW flavors are not compatibility evidence for this add-on.

No WoW installation is available on the development machine. Actual Forever
API compatibility, secret-value restrictions, target-category coverage,
distance semantics, portrait anchoring, settings lifecycle, and combat and
instance behavior still require verification on the game machine. See
[PLAN.md](PLAN.md) for the current scope and acceptance checklist.

## Third-party notices

RangeFinder bundles
[LibRangeCheck-3.0](https://github.com/WeakAuras/LibRangeCheck-3.0) and LibStub.
License notices are retained in `LICENSES\` and the vendored sources.
