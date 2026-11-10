# RangeFinder

RangeFinder is a World of Warcraft Forever addon that displays the current
target's checked distance when the client provides one, or a clearly labeled
approximate range bracket from interaction and learned-spell range checks.

## Prototype

The Lua modules implement distance validation and formatting, a display
controller and frame view, font-size normalization, target tracking, and
throttling. `tests\Run-Tests.lua`
supplies mock client APIs; the prototype does not silently substitute those
mocks for real client APIs.

The next implementer must verify the integrations below and provide an adapter
to `RangeFinder.Core.New(adapter, savedSettings)`:

- `hasTarget()` returns whether the current target exists.
- `getDistance()` returns a finite, non-negative number of yards, or `nil`
  and a reason when the measurement is unavailable. Unexpected errors must
  propagate. It must not pretend range estimates are exact distances.
- `view:SetText(text)` and `view:SetFontSize(size)` render and resize the box.
  `RangeFinder.Display.CreateView(createFrame, parent, fontPath, TargetFrame)`
  anchors the box directly above the target frame's visible portrait.
- `diagnostic(message)` reports repaired settings through an appropriate
  client mechanism.

The bootstrap initializes the saved-variable table, creates one controller,
routes target changes and world entry, and polls through one updater. It also
connects the native Options slider to `options:SetFontSize(value)`.

`RangeFinder.toc`, `Bootstrap.lua`, and `Install-RangeFinder.ps1` provide an
installable Forever 1.60.1 build. The bootstrap uses `UnitDistanceSquared`
only when its validity flag is true. When that is unavailable, it finds the
bundled `LibRangeCheck-3.0` library and displays a bracket such as `10-30 yd`
or an over-limit value such as `50+ yd`; it never presents that estimate as an
exact distance. The box is hidden when no target exists.

The client has no documented addon-frame registration API for native Edit Mode.
The display is instead anchored to the visible top of the target portrait and
follows it as the frame moves.

## Installation

With the game closed, install the addon with:

```powershell
.\Install-RangeFinder.ps1
```

Enable **RangeFinder** at character select. The box appears directly above the target
unit frame. Adjust its font size under **Options > AddOns > RangeFinder**.

## Third-party notices

RangeFinder bundles [LibRangeCheck-3.0](https://github.com/WeakAuras/LibRangeCheck-3.0)
and LibStub, both under the MIT License. Their complete license notices are in
`LICENSES\`.

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
