# Daisy's Lua Multimark Compatibility

Input: user-supplied `Daisys Lua Multimark-53260-2-1775664221.zip` (version 2).

## Actual Flow

The LOAD script creates `multimark_mark_spell` and `multimark_recall_spell`
using custom `multimark_mark` and `multimark_recall` effects. GreaterMark.lua
receives effect-start notifications and requests mark storage or the destination
menu. After selection, lmm_p.lua sends `LMM_TeleportToCell`; lmm_g.lua teleports
the player. This is distinct from Pure Lua Multi Mark's casting interception.

The controller recognises `multimark_recall` directly without importing any
Daisy module. Greater Mark does not arm the transition. Menu waits keep pending
cast detection alive, and shader playback occurs on the next normal frame.

## Evidence

Four archive-backed checks pass using the original event, menu-selection, and
teleport functions: delayed Greater Recall, translated records, Greater Mark as
a negative case, and menu cancellation.

The native OpenMW 0.52 test creates two marks through Daisy's real interface,
opens its real menu, selects a destination, and checks an actual arrival with
exactly one pulse. It passed with no error-level log entries. The engine and
profiles are isolated from POTI; the downloaded mod is extracted under .runtime.

The native test supplies a cast-success notification rather than casting the
spell. A subsequent manual Greater Mark/Greater Recall test confirmed the effect
works. Specific cancellation, failure, and visual checks remain separately
documented in TESTING.md rather than inferred from that general confirmation.

No production dependency or manifest entry for Daisy has been added. This work
is included in 0.2.3 after the verified 0.2.2 Pure Lua Multi Mark update.
