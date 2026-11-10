# RangeFinder

RangeFinder is a prototype for a World of Warcraft Forever addon. At the
user's request, development has continued past the feasibility gate in
[PLAN.md](PLAN.md) using mocked client boundaries. There is no installable
addon yet: the actual client integrations and in-game behavior remain
unverified.

## Prototype

The Lua modules implement distance validation and formatting, a display
controller and provisional frame view, font-size normalization, target
tracking, throttling, and Edit Mode preview state. `tests\Run-Tests.lua`
supplies mock client APIs; the prototype does not silently substitute those
mocks for real client APIs.

The next implementer must verify the integrations below and provide an adapter
to `RangeFinder.Core.New(adapter, savedSettings)`:

- `hasTarget()` returns whether the current target exists.
- `getDistance()` returns a finite, non-negative number of yards, or `nil`
  and a reason when the measurement is unavailable. Unexpected errors must
  propagate. It must not pretend range estimates are exact distances.
- `view:SetText(text)` and `view:SetFontSize(size)` render and resize the box.
  `RangeFinder.Display.CreateView(createFrame, parent, fontPath)` is a
  provisional implementation using mocked frame methods in tests; its font,
  frame APIs, and sizing must be verified in the client.
- `diagnostic(message)` reports repaired settings through an appropriate
  client mechanism.

The missing client bootstrap must initialize the saved-variable table after
loading, create exactly one controller, call `Initialize()`, route target
changes and world entry to `OnTargetChanged()` and `OnWorldEntry()`, and
route elapsed time to `OnUpdate(elapsed)` through one updater. It must
connect the verified native options slider to `options:SetFontSize(value)`
and native Edit Mode enter/exit to `editMode:Enter()` and `editMode:Exit()`.
Position, save/cancel, layout switching, combat restrictions, and registration
are not implemented. Do not treat the preview callbacks as native Edit Mode
integration.

There is deliberately no TOC or installer yet. Add them only after the actual
client integration and interface version are verified. No coverage report or
in-game acceptance results are available.

## Prototype tests

From this directory, with a compatible Lua interpreter installed:

```powershell
lua .\tests\Run-Tests.lua
```

The harness uses mock boundaries, not the game client. On the development
machine it was also run successfully with Lupa's Lua 5.1 runtime installed
temporarily in session storage. The actual Forever runtime has not been
confirmed.

## Feasibility findings

The public [Forever UI source, revision
`9dc84f0`](https://github.com/Gethe/wow-ui-source/tree/9dc84f0d3bbae1768ac3405b3716000bd93eda06)
identifies itself as **1.60.1 (70862)**. This is a source snapshot, not
confirmation of the build installed on the machine that runs the game.

- **Distance:** The snapshot's
  [Unit API definitions](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
  list `UnitDistanceSquared(unit)` and `UnitPosition(unit)`, but do not
  establish their supported target categories or measurement semantics.
  General Warcraft Wiki documentation describes
  [`UnitDistanceSquared`](https://warcraft.wiki.gg/wiki/API:UnitDistanceSquared)
  as limited to group members and
  [`UnitPosition`](https://warcraft.wiki.gg/wiki/API:UnitPosition) as
  unavailable for units outside the group, with restrictions in instances.
  These references are not proof of Forever-specific behavior. Exact
  player-to-target distance for friendly and hostile players, NPCs, and
  creatures remains unverified.
- **Edit Mode:** The snapshot contains
  [Edit Mode API definitions](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/EditModeManagerDocumentation.lua)
  and an internal
  [`RegisterSystemFrame`](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua)
  method. Their presence does not establish a supported addon registration
  mechanism or addon-frame save, cancel, layout-switching, and combat
  semantics.
- **Options and runtime:** The exact supported addon options and slider
  lifecycle, installed client interface version, and runtime behavior remain
  unverified.

## Required next steps

Obtain evidence from the actual Forever client or reliable Forever-specific
documentation for each feasibility item in `PLAN.md`. In particular, verify
target-category coverage and yard semantics, and demonstrate native Edit Mode
registration and save/cancel behavior for an addon frame. Record the actual
client build and distinguish client results from mocked checks. If the required
APIs are unavailable or only cover some targets, a scope change needs user
approval before implementing an approximate or otherwise reduced-scope
fallback.

The sibling addon's installer defaults to
`D:\World of Warcraft\_forever_\Interface\AddOns`; this is only an existing
convention and has not been validated on the game machine.
