# Teleport Transition Test Run

## Start

Double-click `Test-Teleport-Transition.cmd`. Close other OpenMW instances first.
This starts a fresh OpenMW 0.52 session in Seyda Neen using only Morrowind.esm
and TeleportTransitionTest.omwscripts. The test manifest already includes the
production controller: do not enable both manifests together.

The default engine is POTI's bundled 0.52 executable, but none of POTI's modlist
or settings are loaded. The base Steam game supplies spell records. Installed
Tribunal/Bloodmoon archives provide weather assets, without loading their ESMs.
The kit supplies Mark, Recall, Almsivi Intervention, and Divine Intervention;
Mark is selected initially. Mysticism, Willpower, and Luck are 100; magicka is 500.
Look for the test-ready message and inspect your magic window before proceeding.

Each launcher run starts fresh. Explicitly load a test save only for save/reload
checks. Never load a playthrough save with the test fixtures enabled.

Profile/settings/log: `.runtime/manual-profile/`.
Test saves and Lua storage: `.runtime/manual-user-data/`.
The hidden smoke test uses separate `smoke-profile` and `smoke-user-data` folders.
Windowed 1280x720, post-processing enabled, and no other shaders are initial defaults.
Existing manual test settings are preserved, including any changes you make in-game.

Override paths or prepare without opening the game:

```powershell
.\tools\start-test.ps1 -PrepareOnly
.\tools\start-test.ps1 -Engine 'C:\Path\openmw.exe' -GameData 'D:\Path\Data Files'
.\tools\start-test.ps1 -SmokeTest
.\tools\start-test.ps1 -PotiShaders -PrepareOnly
```

## Commands

Open the console, enter `luap` once, then use:

```lua
I.TeleportTransitionTest.run('preview')
I.TeleportTransitionTest.status()
```

Close the console for queued actions and delayed stat writes to take effect.
Enter `exit()` to return to the ordinary console. Cast spells normally using the
magic window and casting controls. Helpers do not manufacture successful casts.

| Argument | Action |
| --- | --- |
| `preview` | Play one effect after returning to gameplay |
| `ready` | Restore high casting stats, magicka, and fatigue |
| `fail` | Empty magicka for insufficient-magicka refusal |
| `low-skill` | Low casting stats with full magicka; retry for a genuine failed roll |
| `home` | Scripted return to your starting position; should not trigger the shader |
| `blocked` / `unblocked` | Disable/enable native teleportation |
| `enabled` / `disabled` | Enable/disable the production effect |
| `reduced` / `normal` | Toggle reduced-motion mode |
| `pronounced` / `baseline` | Apply strong purple or original ripple settings |
| `status` | Print location, selected spell, magicka, settings, and observed pulse count |

Ctrl+Shift+F11 also previews during gameplay. Settings live in
Options > Scripts > Teleport Transition, not the locked F2 shader controls.
Pulse start/end messages go to openmw.log. Preview pulses count too: note the
counter before each case. A counter indicates controller activity, not visual quality.

For a stronger preview, enter `I.TeleportTransitionTest.run('pronounced')`, then
`I.TeleportTransitionTest.run('preview')`, and close the console. Duration sets
speed independently; Purple with a nonzero Colour intensity adds magical colour.
All new settings also appear on the production Scripts page. `baseline` restores
the original look without changing Enabled.

Version 0.2.1 defaults match the user-selected slow purple effect: strength 2.4,
duration 1.8, distortion 3, bands 3, Purple, colour intensity 0.85, fringe 0.6.
Start fresh or use Reset to adopt them. Both Enabled and Automatic spell effects
default to Yes. Test integration-only mode by turning Automatic spell effects to
No: vanilla teleports should no longer trigger, but previews should still work.
Enabled No remains a master opt-out for the controller and its interface.

## POTI Shader-Chain Run

Double-click `Test-Teleport-Transition-POTI-Shaders.cmd` for a separate test profile
with POTI's active shader chain and copied shader parameters. This mode reads the
exported POTI profile, loads its shader-bearing data roots, and puts the workspace
mod last so an old installed copy cannot override it. It never writes to POTI.

It is a shader-chain compatibility run, NOT the full modlist. Gameplay plugins
and their Lua controllers are not imported. Settings/logs are in
`.runtime/poti-shaders-manual-profile`; saves/storage are in the corresponding
`poti-shaders-manual-user-data` directory. Source paths can be overridden with
`-PotiProfile`. Existing manual settings are preserved; changes to POTI's source
chain are picked up when a new test profile is first created, not automatically
overwritten onto an existing manual profile.

The compatibility smoke run (`-PotiShaders -SmokeTest`) checks that the existing
chain's names and order survive both effects and scripted travel. The strict log
gate also rejects unrelated error-level entries. This machine currently reports
missing `textures/vaionoise3dw.dds` from VAIO, also observed in the normal POTI log.
The transition/chain checks pass, but that resource error prevents a clean overall
compatibility smoke pass. Full POTI gameplay and visual acceptance remain manual.

## Manual Sequence

1. Preview once. Confirm one short contraction/ripple, then an unchanged image.
2. On a fresh run BEFORE casting Mark, cast Recall. Expect no travel or pulse.
3. Cast Mark. Expect no pulse. Cast Divine Intervention, then Recall: one pulse
   per successful teleport, and Recall must actually return you to your Mark.
4. Use `home`, then cast Almsivi Intervention. Expect no pulse for home, one for the spell.
5. Use `fail` and try an Intervention. Expect no travel or pulse; restore with `ready`.
6. Use `low-skill` and retry until an actual casting failure occurs. No pulse on
   that failure. Restore with `ready`. Insufficient magicka is NOT a failed roll.
7. Use `blocked`, then cast both Interventions and Recall. No travel or pulse.
   Use `unblocked` afterwards, closing the console before casting each time.
8. With Recall selected, open an ordinary travel door and use a travel service.
   Neither should trigger. `home` provides a simpler scripted-travel negative check.
9. Disable in Scripts, cast an Intervention. Native travel works without a pulse.
   Re-enable, select Reduced motion, and preview: only peripheral fading, no distortion.
10. Change strength/duration, save, reload, and preview. Settings must persist;
    supplied spells must not duplicate, and no effect should resume just from loading.
11. Try switching selection during a cast and repeated inputs during its animation.
    Record misattribution: this prototype relies on a selected-spell/success correlation,
    not a direct engine callback identifying the spell responsible for a teleport.

Capture a short video for timing, or matched screenshots partway through a 2-second
preview. Test your regular resolution and reduced motion. This is an arrival effect;
it does not retain or crossfade the departure scene.

## Verification Limits

Readiness checks (no game launch):

```powershell
python .\tests\verify_readiness.py
.\tools\start-test.ps1 -PrepareOnly
```

The readiness script checks the real Morrowind.esm spell records, compiles all
runtime Lua with the installed engine DLL, and checks production/test separation.
Override its `--engine` (engine directory) and `--esm` paths if necessary.

The smoke run checks the real engine's fixture setup, shader activation/compilation,
reduced-motion activation, and cleanup. It does NOT cast spells or establish visual
quality. Lua controller/fixture tests are in this repository's tests/ directory.
Use this minimal run first; POTI compatibility requires a separate manual test later.

Record results in reports/manual-results.md, including engine version, pulse counts,
actual cell/position changes, input device, and any openmw.log errors.

See reports/automated-results.md for the latest automated verification summary.
