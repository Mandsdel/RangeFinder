# RangeFinder implementation plan

## Execution contract for the implementing AI

This document is a plan, not evidence that Forever supports any particular API. Do not invent API names or copy retail WoW integrations without confirming Forever compatibility.

Work only inside `RangeFinder\` unless a shared-file change is necessary and explicitly justified. Preserve unrelated work. Do not change the existing `DisenchantTooltip` addon.

Follow the phases in order. Complete the API feasibility gate before writing addon behavior. If a required integration cannot be verified, report the exact missing evidence and pause the affected work. Do not quietly weaken a requirement.

## Requirements and decision ownership

### Approved scope change

The user approved anchoring the range box directly above the standard `TargetFrame`
instead of native Edit Mode positioning. This supersedes every native Edit Mode
positioning and preview requirement in this plan. The frame must follow
`TargetFrame`; it must not add custom dragging or position persistence.

The user approved bundling the MIT-licensed LibRangeCheck-3.0 library for
clearly labeled approximate range brackets when Forever does not provide an
exact target distance. It may display `10-30 yd` or `50+ yd`, but must never
show an estimate as an exact `30 yd`.

| ID | Requirement | Decision rule |
|---|---|---|
| R1 | Show current player-to-target distance in whole yards when available, otherwise a labeled upper-bound range | Never present an estimate as exact |
| R2 | Show `N/A` without a target or available measurement | Never retain the previous target's value |
| R3 | Anchor the box above the standard target unit frame | No custom dragging or position persistence |
| R4 | Configure font size under Options > Addons > RangeFinder | Changes apply immediately and persist |
| R5 | Remain lightweight and safe during normal gameplay | No external services, gameplay automation, or protected gameplay actions |

Implementation defaults, not additional user requirements: nearest-integer rounding, a dark centered-text box placed eight pixels above `TargetFrame`, a 0.1-second polling interval, and account-wide font size. Use a font-size default of 14 with an integer slider from 8 to 32. Adjust these defaults only if verified client constraints require it, and document the reason.

User approval is required to replace exact measurements with estimates, replace native Edit Mode with custom dragging, add a runtime dependency, or change the requested options location.

## Goal

Create a lightweight WoW Forever addon displaying a small box with the distance to the current target in whole yards.

| State | Box displays |
|---|---|
| Target selected and distance available | `23 yd` |
| No target selected | `N/A` |
| Target selected but distance unavailable | `N/A` |

The box's position must be adjustable through WoW Forever's built-in UI Edit Mode. Font size must be configurable under **Options > Addons > RangeFinder**.

## 1. Verify Forever's APIs

Confirm the installed client's APIs before implementing client-specific integrations.

### Distance measurement

- Identify the supported API for measuring player-to-target distance in yards.
- Check support for friendly players, hostile players, NPCs, and creatures.
- Check behavior across maps, instances, and targets whose positions are unavailable.
- Confirm whether the result represents positional distance or gameplay range adjusted for target size.
- Determine whether the API provides an exact distance or only approximate range intervals.

Do not present estimates as exact measurements. If precise distance is unavailable, agree on whether approximate ranges are acceptable before implementing a fallback.

### Edit Mode

- Identify how addons register frames with Forever's built-in Edit Mode.
- Verify frame selection, repositioning, layout saving, and layout switching where supported.
- Use native position and layout persistence where supported.
- Confirm any combat restrictions and respect them.

Native Edit Mode integration is a requirement. If the client does not expose it to addons, raise that limitation for a decision rather than silently substituting custom dragging.

### Addon options

- Identify the supported API for registering **Options > Addons > RangeFinder**.
- Confirm how settings are persisted and applied.

### Feasibility gate: required evidence

Inspect local project guidance, the installed Forever client's API definitions or UI source, and available Forever-specific documentation/examples. Read existing installer conventions before creating installation scripts. Record findings in the eventual `README.md`, with source paths or URLs and the client build to which they apply.

| Integration | Evidence required before implementation |
|---|---|
| Distance | Actual function and signature, units, return validity, supported target categories, measurement semantics, and unavailable-result behavior |
| Edit Mode | Supported addon-frame registration and lifecycle, save/cancel behavior, position ownership, layout support, and combat restrictions |
| Options | Supported category and slider registration, initialization lifecycle, and persistence mechanism |
| Runtime | Confirmed interface version, Lua syntax/runtime constraints, and available timer/event mechanisms |

Do not treat `.wowluarc.json`'s `forever` flavor or the sibling addon's `16001` interface value as proof of API support.

Distinguish a supported API temporarily returning no measurement (`N/A`) from an unsupported required integration (a blocker). If only some target categories can be measured, describe the limitation and obtain approval before claiming R1 is satisfied. Do not derive exact yards from spell checks, interaction ranges, normalized map coordinates without verified scaling, or range brackets.

**Exit condition:** All required integrations have a verified implementation route, or the user has explicitly approved a documented change in scope. If client access is unavailable, state that feasibility remains unverified rather than guessing.

## 2. Create the addon structure

Create a separate addon alongside `DisenchantTooltip`:

```text
RangeFinder\
  RangeFinder.toc
  Core.lua
  Range.lua
  Display.lua
  EditMode.lua
  Options.lua
  README.md
  Install-RangeFinder.ps1
  Install RangeFinder.cmd
  tests\
    Run-Tests.lua
```

Use the existing Forever addon's interface version (`16001`) as the starting point, confirming compatibility with the installed client.

Declare saved variables for font size and any configuration that is not managed by native Edit Mode.

### Module responsibilities and load order

Use one addon namespace and compatible Lua syntax. Load modules in this order in the TOC; defer frame creation and API registration until the verified client lifecycle permits them.

| File | Responsibility |
|---|---|
| `Range.lua` | Verified distance adapter, return validation, and pure whole-yard formatting |
| `Display.lua` | Create the box, render text, apply font size, and measure required dimensions |
| `EditMode.lua` | Native registration, preview state, and native placement/layout integration |
| `Options.lua` | Native options category, integer slider, and saved font-size updates |
| `Core.lua` | Initialize saved settings once; connect modules, target events, and one polling loop |

Use small namespace functions instead of a framework. Keep the range adapter mockable without a running client. Tests must not be loaded by the addon TOC.

### Data and state contract

- The range adapter returns a finite, non-negative number of yards or an explicit unavailable result with a reason. Treat zero as valid. Reject negative, non-number, NaN, and infinite returns.
- Expected unavailable measurements produce `N/A`; unexpected API failures must remain observable through the verified client error mechanism. Do not blanket-catch API errors and turn them into successful-looking `N/A` values.
- Format valid distances with nearest-integer rounding, with halves rounded up, then one space and `yd`. Keep the raw value unrounded until formatting.
- Separate gameplay measurement state from the Edit Mode preview flag. Rendering chooses `23 yd` during editing; otherwise it chooses the current measurement or `N/A`.
- Initialize a single account-wide saved-variable table, such as `RangeFinderDB`, after its saved variables have loaded. Default missing font size to 14. Normalize numeric values to integer bounds 8-32; repair invalid saved values with a one-time diagnostic, not a repeated polling warning.
- Position has one owner: native Edit Mode where supported. If the verified native extension mechanism requires addon-managed persistence, document its schema and layout/save/cancel semantics before implementing it; do not introduce competing position stores.

### Dependency order

After feasibility is established, create the TOC and testable range logic first, then the display, native Edit Mode integration, native options, and finally Core lifecycle wiring. Complete automated and in-game verification before packaging the release. The numbered feature sections below define behavior, not a requirement to initialize frames in that textual order.

## 3. Build the display

- Use a small box with a dark background and centered, readable text.
- Choose a default position near the center of the screen without covering the character.
- Initially display `N/A`.
- Round available distances to the nearest whole yard: `23 yd`, never `23.4 yd`.
- Keep the box visible when no target is selected.
- Resize the box as necessary to accommodate the configured font size and displayed text.
- Use the client's verified built-in font resource. Measure rendered text with padding rather than relying on a fixed width that can clip large values.
- Do not intercept ordinary gameplay mouse input outside Edit Mode unless the verified native integration requires it.

## 4. Integrate with built-in Edit Mode

- Register the range box with Forever's native Edit Mode.
- Allow users to select and reposition it through Edit Mode.
- Keep the box locked during normal gameplay to prevent accidental movement.
- Display a sample value such as `23 yd` while editing so placement is possible without a target.
- Restore the actual target state when leaving Edit Mode.
- Preserve placement through native layout saving where supported.
- Respect native layout switching and combat restrictions.
- Implement native save and cancel semantics; canceling an edit must not persist a moved position.
- Resizing for font changes must preserve the native placement anchor.

Do not add a separate freely draggable positioning mechanism as a substitute.

## 5. Add font-size options

- Register a RangeFinder page under **Options > Addons > RangeFinder**.
- Provide a labeled font-size slider with a visible numeric value.
- Use the implementation defaults: 14 by default, integer values from 8 to 32.
- Apply changes immediately to the range box, including its Edit Mode preview.
- Resize the box to keep its text readable.
- Persist font size across UI reloads and game sessions.

## 6. Implement target tracking

- Refresh immediately when the player changes or clears their target.
- While a target exists, refresh approximately every 0.1 seconds so movement updates the distance.
- Stop distance polling when there is no target.
- Clear stale values immediately when the target changes or its distance becomes unavailable.
- Keep distance retrieval separate from UI rendering so client-specific API behavior stays in one place.
- Ensure Edit Mode preview text does not overwrite or become stale gameplay state.
- On initialization and world entry, refresh the current target even if no target-change event has fired.
- Use verified target-change and world-entry events. Use one throttled updater or timer, not both; avoid registering duplicate handlers or timers.
- A target-change handler invalidates the old value and measures the current target synchronously. An unavailable measurement replaces the previous value in that same refresh.
- Recheck target existence on each poll. Stop polling if the target has disappeared, even if an event was missed.
- Refresh from the actual current target when leaving Edit Mode. If native Edit Mode suspends measurement, it must not suspend this exit refresh.
- In combat, continue safe distance/text updates. Defer restricted positioning or registration operations only as required by the verified client API.
- Update text and dimensions only when their inputs change; do not create frames, tables, or options controls on each polling tick.

## 7. Verify behavior

Verification has two layers. Mocked Lua checks verify logic; only the actual Forever client can establish API compatibility, range semantics, native Edit Mode behavior, and the requested options location. Never report mocked checks as in-game verification.

### Automated checks

Use an existing compatible Lua runner if available. If none exists, identify the missing prerequisite and document the intended command before adding tooling. Keep the harness dependency-free where practical and use Lua syntax compatible with the confirmed client runtime.

Implement `tests\Run-Tests.lua` with mocked client boundaries and a nonzero failure exit. Document a runnable command using the actual available interpreter, for example `lua .\tests\Run-Tests.lua` only if `lua` is installed and compatible.

| Test | Required assertions |
|---|---|
| Formatting | `0` -> `0 yd`; `0.49` -> `0 yd`; `0.5` -> `1 yd`; `23.49` -> `23 yd`; `23.5` -> `24 yd`; `1234` -> `1234 yd` |
| Invalid measurements | Missing, negative, non-number, NaN, and infinite values never render as yard values |
| No target | Renders exactly `N/A`; does not call the distance API or keep polling |
| Target lifecycle | Selecting, switching, clearing, and losing a target never retains a stale value |
| Timing | At most one scheduled poll per 0.1-second interval; no catch-up burst after a long frame; event refreshes remain immediate |
| Initialization | Loaded settings and an already selected target are handled; repeated initialization creates no duplicate updater or category |
| Preview | Entering Edit Mode shows `23 yd`; target changes during editing cannot replace the preview; exit remeasures the current target |
| Settings | Missing value defaults to 14; numeric values round and clamp to 8-32; malformed values are repaired with a diagnostic; valid changes persist |
| Error distinction | Expected unavailable results render `N/A`; unexpected API failures are surfaced rather than silently swallowed |

### In-game acceptance checks

| Scenario | Expected result |
|---|---|
| Login without a target | `N/A` |
| Select a supported target | Whole-number distance followed by ` yd` |
| Player or target moves | Distance updates continuously |
| Switch targets | New target's distance replaces the old value immediately |
| Clear target | Immediately displays `N/A` |
| Target becomes unavailable | `N/A`, not the previous distance |
| Target is the player | `0 yd` |
| Enter Edit Mode without a target | Box is selectable and displays sample text |
| Reposition the box in Edit Mode | Native positioning controls move the box |
| Leave Edit Mode | Actual target distance or `N/A` replaces the preview |
| Save placement and reload or relog | Placement is restored |
| Move the box and cancel Edit Mode | Previous saved placement is retained |
| Switch native layouts, where supported | Box follows the selected layout |
| Open Options > Addons > RangeFinder | Font-size control is available |
| Change font size | Text updates immediately and fits inside the box |
| Reload UI or relog after changing font size | Font size is restored |
| Minimum and maximum font sizes | Text, including large yard values and `N/A`, remains readable without clipping |
| Resize after moving the box | The saved placement anchor does not shift |
| Combat and instance transitions | No Lua errors or restricted-action failures |

Verify actual yard accuracy against confirmed API semantics. Spell-range checks alone do not prove an exact displayed distance.

For each supported target category, record a measured sample and compare it with a trusted Forever-specific reference using the same distance semantics. If no independent reference exists, state that accuracy beyond the API's documented contract remains unverified. Do not invent a precision claim.

Record pass, fail, or blocked for each acceptance check with the client build and relevant evidence. A selected but temporarily unmeasurable target may correctly show `N/A`; that does not prove broad target support.

## 8. Package and document

- Follow the existing addon's double-click installer pattern for the local `_forever_\Interface\AddOns` directory.
- Inspect the sibling installer rather than assuming a destination. Use its confirmed destination as a configurable default and validate it before copying.
- Copy only runtime addon files and the README; exclude tests, this plan, and installer scripts from the installed addon unless a documented runtime need exists.
- Ensure the destination is `AddOns\RangeFinder`, not a nested duplicate folder. Preserve unrelated addons and all client-managed saved variables.
- Surface installation errors and return a nonzero exit code. Re-running installation must update files safely without resetting settings.
- Document installation, native Edit Mode positioning, font-size configuration, rounding behavior, and verified API limitations.
- Keep the first version dependency-free unless the API investigation demonstrates a need.

## Completion and handoff

The implementing AI must not declare the addon complete until:

1. R1-R5 have implementation evidence, or explicit user-approved deviations are recorded.
2. The TOC loads runtime files in the documented order and declares the saved-variable table.
3. Automated checks pass and required in-game checks pass on the confirmed Forever build.
4. Installation places the correct files in the intended addon directory without changing unrelated addons or saved settings.
5. The README contains actual API evidence, supported target categories, configuration instructions, limitations, and reproducible verification commands.

If client access or another prerequisite is missing, deliver the completed work with a precise blocked-check list. Distinguish "implemented", "automatically checked", and "verified in game"; do not label blocked work as complete.

The final implementation handoff should list changed files, approved deviations, actual verification outcomes, and remaining blockers. Do not perform unrelated refactoring or add unrequested features.

## First-version scope

Include one range box, native Edit Mode positioning, current-target tracking, whole-yard output, `N/A` when no measurement is available, and a persisted font-size setting in the native addon options.

Exclude range alerts, class-specific thresholds, a minimap button, and additional customization settings.

## Plan optimization record

Three planning-only iterations were applied; no addon implementation was created:

1. **Requirements and feasibility:** Added stable requirement IDs, explicit implementation defaults, evidence-based API gates, decision ownership, and stop conditions for unsupported integrations.
2. **Architecture and lifecycle:** Defined module boundaries and load order, distance and persistence contracts, preview/gameplay separation, native position ownership, and deterministic event/polling behavior.
3. **Verification and delivery:** Added exact formatting cases, lifecycle and error assertions, native save/cancel acceptance checks, safe installation boundaries, and completion rules that distinguish mocked checks from real-client evidence.
