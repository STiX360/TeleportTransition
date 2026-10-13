# Optional Kyne's Intervention Support

## Source Evidence

The installed Tamriel Data plugin defines `T_Nor_Mys_KynesIntervention` with a
Divine Intervention fallback. Its OpenMW LOAD script replaces that effect with
`t_intervention_kyne`. The effect implementation in `global_miscspells.lua`
performs a scripted teleport, subject to teleport blocking and regional limits.
Its destinations are in Skyrim: Home of the Nords, not TR_Mainland.

The controller recognises the record identity before the fallback effect and
also recognises the custom effect directly. No Tamriel Data module is imported
by the controller. Kyne uses Default Colour while its dedicated setting remains
hidden. The ordinary production manifest still loads only the controller.

## Isolation

Engine, Tamriel Data, and Skyrim files are copied from POTI into
`.runtime/kyne-source`. The separate test profile and user-data directories are
under `.runtime/kyne-*`. No playthrough saves are loaded. POTI is only read.
Morrowind, Tribunal, and Bloodmoon plugins are loaded from the base Steam game.

## Acceptance

API-double checks cover the fallback record, custom effect with a translated
name, both callback orders, and no-arrival behaviour. Native setup confirmed the
real custom effect loads on API revision 134 and completed the regular shader
and scripted Recall smoke sequence without error-level log entries.

An additional experimental smoke step that directly inserted Kyne's active spell
did not complete: the process ended before either a pass or Lua failure was
logged. That synthetic application step was removed from the test launcher;
it does not establish how normal casting behaves. Real casting, arrival, and
visuals remain manual acceptance checks in TESTING.md.
