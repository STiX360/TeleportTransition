# Automated Verification

Run: 2026-10-09, OpenMW 0.52.0 from C:/Modlists/POTI/.OpenMW/openmw.exe.

- Twelve mocked Lua tests pass: nine production-controller cases and three fixture cases.
- Readiness check passes: four vanilla spell/effect records, engine Lua syntax,
  and production manifest excludes test helpers.
- PrepareOnly passes: isolated profile, content list, and initial settings generated.
- Real-engine 0.2.1 smoke run passes: new screenshot defaults, integration calls
  with Automatic spell effects off, fixture supplies, 500 magicka, pronounced
  purple preview, reduced-motion preview, existing chain preservation, cleanup,
  and scripted-home travel does not trigger another effect.
- Final smoke log contains TT_SMOKE_PASS and no error-level log entries.
- No existing POTI profile, playthrough save, or installed mod was edited.

POTI shader-chain smoke loaded HBAO, VAIO, godrays, DIVE, wetworld, bloomPS2,
tonemap, SMAA. Internal transition and unchanged-chain checks reached TT_SMOKE_PASS.
The overall strict log gate FAILED due to missing textures/vaionoise3dw.dds in VAIO
(also seen in the user's normal POTI log before this work). This is not a clean
full-stack compatibility pass. The launcher provides a separate manual chain run.

The smoke run launches a hidden game window and exits automatically. No actual
spells are cast by it. User-confirmed 0.1.0 Recall behaviour is recorded separately.
Doors, real failed casts, new control appearance, save/reload gameplay, and full
POTI compatibility remain manually unverified.

Reproduce from this directory:

```powershell
python .\tests\verify_readiness.py
.\tools\start-test.ps1 -PrepareOnly
.\tools\start-test.ps1 -SmokeTest
```

Mock tests live in this repository's tests/test_teleport_transition.py and
tests/test_teleport_transition_harness.py (Python with lupa).
