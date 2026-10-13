# Optional Kyne's Intervention Support

## Source Evidence

The installed Tamriel Data plugin defines `T_Nor_Mys_KynesIntervention` with a
Divine Intervention fallback. Its OpenMW LOAD script replaces that effect with
`t_intervention_kyne`. The effect implementation in `global_miscspells.lua`
performs a scripted teleport, subject to teleport blocking and regional limits.
Its destinations are in Skyrim: Home of the Nords, not TR_Mainland.

The controller recognises the record identity before the fallback effect and
also recognises the custom effect directly. No Tamriel Data module is imported
by the controller. Its colour setting appears only when the spell record is
installed and defaults to inheriting Default Colour. The ordinary production
manifest still loads only the controller.

## Isolation

Engine, Tamriel Data, and Skyrim files are copied from POTI into
`.runtime/kyne-source`. The separate test profile and user-data directories are
under `.runtime/kyne-*`. No playthrough saves are loaded. POTI is only read.
Morrowind, Tribunal, and Bloodmoon plugins are loaded from the base Steam game.

## Acceptance

API-double checks cover translated custom effects, fallback classification,
conditional setting registration, colour inheritance/overrides, invalid values,
old-save migration, and save/load persistence. Missing Tamriel Data leaves the
setting absent and requires no external module.

The native suite uses player controls to perform real casting, without injected
active spells or success notifications. It covers two successful casts (override
and inherited colour), disabled effects, automatic detection off, blocked travel,
insufficient magicka, a failed roll, and out-of-region rejection. Successful cases
must travel and produce exactly one pulse; all cases must clean up the shader.
The installed engine reports OpenMW 0.52.0, API revision 134.

All eight native cases passed with no error-level log entries. The full suite
passes 53 tests, including both Multi Mark archives. Native casting at capped
Mysticism required a Kyne-specific release-animation detection path; it still
requires an actual teleport, and failed/rejected casts produced no pulse.
The ordinary native smoke test also passed without Tamriel Data or Skyrim
loaded, verifying standalone startup and operation with the Kyne setting absent.

Copied engine SHA-256:
`b94a8513aa011e7a0f12a15a86a0609b5f68d1d2e269d148148d771ba7db3b15`.

Visual colour appearance is a manual check in TESTING.md; automated colour
verification uses shader uniforms in the controller tests. The engine does not
provide a shader-uniform getter for the native smoke test.
The subsequent manual Kyne test was confirmed working before preparing 0.2.4.
