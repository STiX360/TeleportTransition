# Teleport Transition 0.2.4

An asset-free procedural arrival effect for Recall, Almsivi Intervention, and
Divine Intervention. A short contraction and expanding ripple settle back to
the untouched scene. No flashes, camera movement, or teleport delays.

## Standalone Mod or Modder's Resource

**Teleport Transition is both a standalone teleport-spell mod and a modder's
resource: a reusable procedural shader with a Lua integration interface.**

Modders can use the effect for their own portals, spells, scripted travel, or
other events without enabling this mod's automatic vanilla-spell behaviour.
Other mods should list Teleport Transition as a dependency and call its interface.
Players install this mod separately; dependent mods do not bundle its files.

| Use | Enabled | Automatic spell effects |
| --- | --- | --- |
| Standalone: automatically respond to Recall and both Interventions | Yes | Yes |
| Modder's resource: another mod decides when to play the effect | Yes | No |
| Disable this controller and all its integration calls | No | Either |

For resource-only use, turn **Automatic spell effects** off in
Options > Scripts > Teleport Transition. Leave **Enabled** on and keep
`TeleportTransition.omwscripts` loaded. This switches off the standalone spell
behaviour, not the reusable shader interface. Other mods can then trigger the
effect while respecting the player's colour, intensity, duration, and accessibility
settings. Do not turn off the master switch or unload the manifest when using
the managed integration interface.

## Installation

Requires OpenMW 0.52 with post-processing enabled; verified against 0.52.0.
Older versions are not verified. This is not an original Morrowind/MWSE mod.
Install the archive as a separate Mod Organizer mod. Enable the mod AND its
TeleportTransition.omwscripts content entry. If your exporter creates an
.omwscripts.esp placeholder, check that plugin too. Restart OpenMW.

Manual installation: add this directory as a data path in openmw.cfg and add
`content=TeleportTransition.omwscripts`.

Options > Scripts > Teleport Transition provides Enabled (default on), strength,
duration, distortion, ripple bands, Default Colour, per-spell colour overrides,
colour intensity, chromatic fringe, and Reduced motion. Ctrl+Shift+F11 previews
the effect during gameplay.
Reduced motion removes displacement and chromatic splitting; colour and a gentle
peripheral fade remain. Numeric ranges are shown beneath each setting.
The dynamic shader is locked in the F2 HUD; use Scripts settings instead.

Enabled is the master switch for this controller, previews, and its integration
interface. Automatic spell effects controls detection of vanilla and supported
custom teleport spells. To use
only another mod's triggers, leave Enabled on and turn Automatic spell effects off.
The content manifest must stay enabled to provide the Lua interface and event.

## Stronger Effects

Strength now ranges from 0 to 3. It changes displacement amplitude and the fade,
not ring radius or speed. Distortion independently multiplies geometric warping;
ripple bands adds wave detail. Duration controls travel speed: lower is faster.
Colour intensity is independent of distortion. Choose Purple, Blue, Green, Gold,
or Neutral. Recall, Almsivi Intervention, and Divine Intervention can override
Default Colour. Previews and uncategorised effects use Default Colour. Chromatic fringe separates
red/blue samples along the wavefront.

Default purple setup:

| Setting | Value |
| --- | --- |
| Effect strength | 2.4 |
| Distortion amount | 3 |
| Ripple bands | 3 |
| Duration | 1.8 seconds |
| Default Colour | Purple |
| Spell-specific colours | Default Colour |
| Colour intensity | 0.85 |
| Chromatic fringe | 0.6 |

Existing saves retain their preferences. Use the menu's Reset button to adopt
all new defaults on an existing save, or start a fresh test session.
Higher warping can be uncomfortable. Reduced motion disables moving wave patterns
as well as refraction and chromatic splitting. There is no strobing or white flash.

## Behaviour and limitations

The controller pairs a detected teleport spell cast with an actual teleport event
within 0.25 simulation seconds. If a teleport spell opens a menu, as multimark
mods often do, that matching window is held while the menu is open. Doors, paid
travel, Mark, failed casts, and blocked/no-destination casts should not trigger it.
Custom spells using the same three effects are supported, as are spell records
named like Greater Recall. Pure Lua Multi Mark 2.5 and Daisy's Lua Multimark 2
destination selection have been tested in-game. Daisy's Greater Recall is also
recognised by its custom effect ID, including when its name is translated.
Both mods are optional; no additional mod is required. Scrolls and enchanted
items remain outside automatic detection. Vanilla spell records and travel mechanics
are not modified.

Kyne's Intervention from Tamriel Data is supported, including its custom effect
and Divine Intervention fallback. Its colour override appears only when the
spell record is installed and otherwise inherits Default Colour. Native tests
cover real casting, arrival, disabled effects, and rejected travel.
Tamriel Data and Skyrim are not dependencies of Teleport Transition.
Kyne's cast-release animation also supplies detection when capped Mysticism
prevents a skill-progression notification. A real arrival is still required.

This is an arrival transition, not a before-and-after crossfade: the engine
teleports instantly, and we do not intercept it or retain the departure image.
The real-engine shader/fixture smoke run passes on OpenMW 0.52. Callback ordering
for actual casts and visual appearance still require your in-game check.
An unrelated scripted teleport immediately following a successful teleport cast
could be misclassified because the engine event has no cause field.

The shader appends to the current chain and removes only itself when finished.
It does not rewrite POTI settings or reorder existing shaders. Other mods may
alter the result through their shader ordering. No external textures are used.

## Other mods

### Managed Integration (Recommended)

From a player script:

```lua
local I = require('openmw.interfaces')

if I.TeleportTransition then
    I.TeleportTransition.play()
end
```

From a global script, after the mod's successful travel or other trigger:

```lua
player:sendEvent('TeleportTransitionPlay', {})
```

Player scripts can call `I.TeleportTransition.play()` or `.stop()` after checking
that the interface exists. Global scripts can use
`player:sendEvent('TeleportTransitionPlay', {})` after their own successful travel.
Calling play again restarts the pulse; Enabled is respected by all callers.
Automatic spell effects is not required for these calls. A mod driving the raw
shader directly can also load it without our controller, but must provide its own
progress animation, uniforms, and cleanup. Our Enabled switch cannot police
another mod's independent shader handle.
Do not send this event for vanilla spells too, or you may restart their effect.

### Direct Shader Use

The `Shaders/teleport_transition.omwfx` file can be driven independently through
`openmw.postprocessing`. This does not require our Lua controller, but the caller
must animate `transitionProgress` from 0 to 1, configure the uniforms, and disable
the shader afterward. Simply loading the shader does not animate it. Do not have
two controllers drive the same named shader simultaneously.

No redistribution or source-reuse license is currently provided. This resource
is intended for dependency-based integration, not copying, adapting, or bundling
its shader/scripts into another release. Obtain permission before redistributing
or incorporating project files.

## Test checklist

Double-click `Test-Teleport-Transition.cmd` in the test package for an isolated
ready-to-cast character. See [TESTING.md](TESTING.md) for setup, helper commands,
and the acceptance sequence. Test helpers are absent from the production manifest.

- Preview using Ctrl+Shift+F11; check ultrawide and ordinary aspect ratios.
- Cast Mark (no transition), move away, and Recall (one transition).
- Cast each Intervention (one transition).
- Try failed casts and Recall without a Mark (no transition).
- Use a door and paid travel while a teleport spell is selected (no transition).
- Disable the mod in Scripts and repeat; test Reduced motion and save/reload.
- Check openmw.log for shader compilation or Lua errors.

## Development and Publishing

Install test dependencies and run the mocked controller/fixture tests:

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p "test_*.py"
python tests/verify_readiness.py
```

Build separate production and test ZIPs with `tools/package.ps1` (Python required),
or use `python tools/package.py` and `python tools/package.py --test`.
Outputs stay in
this repository's ignored `dist/` directory. Production includes no test scripts,
runtime profiles, or saves. See [PUBLISHING.md](PUBLISHING.md) for the GitHub/Nexus
checklist and [TESTING.md](TESTING.md) for isolated game testing.
Version-tag pushes (`vX.Y.Z`) automatically build/attach the production ZIP to
GitHub Releases and publish a new Nexus file version after Nexus IDs/secrets are
configured. VERSION, this heading, shader metadata, and changelog must agree.
