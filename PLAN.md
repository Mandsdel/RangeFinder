# RangeFinder scope and acceptance

## Current scope

Develop only for World of Warcraft Forever. The approved scope replaces the
original native Edit Mode positioning and preview requirements with a box
anchored directly above the standard target frame's visible portrait.
There is no custom dragging, position persistence, or preview feature.

Prioritize precise distances everywhere Forever supplies them: checked
distance first, then usable player/target world positions in the same instance.
There is no ground/flight gate or distance threshold. The approved range
fallback uses bundled LibRangeCheck-3.0 estimates only when both precise
sources are unavailable. Keep approximate brackets (`10-30 yd`) and
lower-bound results (`50+ yd`) distinguishable from exact values (`23 yd`).
Do not silently remove this fallback or substitute a different measurement
scheme. Changes to measurement scope or dependencies require user approval.

| Requirement | Current behavior |
|---|---|
| Target distance | Checked or world-position yard value rounded to nearest integer, otherwise a labeled range |
| Unavailable measurement | `N/A`, never the previous target's value |
| No target | Box hidden; per-frame updater detached and distance polling stops |
| Placement | Immediately above the target portrait, following its anchor |
| Font size | Options > AddOns > RangeFinder; default 14, integer bounds 8-32 |
| Persistence | Account-wide font size only |
| Updates | Immediate on target/world changes; approximately 0.1-second polling |
| Safety | No services, gameplay automation, or protected gameplay actions |

## Implementation boundaries

| File | Responsibility |
|---|---|
| `Range.lua` | Validate numeric, bounded, and lower-bound measurements; format yards |
| `Display.lua` | Create the portrait-anchored box; cache text, visibility, and font updates |
| `Options.lua` | Normalize and persist font size; diagnose repaired settings |
| `Core.lua` | Initialize once; refresh target state and throttle measurements |
| `Bootstrap.lua` | Connect Forever APIs, saved variables, events, and native settings |
| `Install-RangeFinder.ps1` | Install runtime files and licenses; omit library development blocks |
| `tests\Run-Tests.lua` | Lightweight mocked checks, excluded from the TOC |

Keep the small mockable adapter boundary. Preserve the vendored library's
Forever adjustments and licenses; strip its explicitly marked development
blocks during installation rather than forking its public API to reduce size.
Range checks must bypass stale unit-token caches when target identity changes.
Expected unavailable measurements render `N/A`; unexpected errors remain
observable, not hidden by blanket catches.

## Verification

Run the existing Lua harness after behavior changes. Cover measurement shapes,
invalid inputs, stale-value replacement, target lifecycle, polling, settings,
and display sizing without building an elaborate client simulator.

There is no local WoW installation. Mocked checks cannot establish compatibility
or accuracy. Verify these on the separate Forever game machine:

| Scenario | Expected result |
|---|---|
| Login without a target, or clear target | Box hidden |
| Login with an existing target | Current measurement shown |
| Checked distance available | Rounded whole-yard value |
| Checked distance unavailable, usable world positions available | Rounded 3D whole-yard distance, including nearby ground targets |
| World positions unavailable, secret, invalid, or in different instances | Do not calculate from those positions; use range fallback |
| Only a range bracket available | Distinct `minimum-maximum yd` output |
| Only a lower bound available | Distinct `minimum+ yd` output |
| Measurement unavailable | `N/A`; no stale target value |
| Rapid target switches | Fresh target measurement immediately |
| Player or target moves | Distance refreshes approximately every 0.1 seconds |
| Target portrait moves | Box follows without independent positioning |
| Change font size | Text updates immediately and fits at both bounds |
| Reload or relog | Font size restored |
| Combat, instance, and world transitions | No Lua errors or restricted-action failures |

Record the actual Forever build, supported target categories, measurement
semantics, secret-value restrictions, options behavior, and relevant API
evidence. Do not infer Forever compatibility from another WoW version.
