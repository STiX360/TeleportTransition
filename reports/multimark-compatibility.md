# Pure Lua Multi Mark Compatibility

Date: 2026-10-13 (Australia/Perth)

Input: user-supplied `puremultimark-57313-2-5-1776680162.zip`.

## Observed Source Flow

With two or more locations, `PMM_p.lua` opens an Interface menu at the
`spellcast` / `self start` animation key. Selecting a named location suppresses
the native Recall with Silence. At `self release`, the mod removes that Silence,
sends `PMM_loadLoc`, and explicitly calls Mysticism `Spellcast_Success`.
`PMM_g.lua` receives the event and calls the player's teleport method.
Latest uses native Recall instead of that scripted destination path.

## Automated Evidence

The archive-backed tests execute those original handlers with API doubles.
They pass for destination selection after a 30-second menu wait, both callback
orders, Latest, failed casting, and cancellation. After the delayed-action fix,
the 0.2.2 suite passes 45 tests, including controller, fixture, and
release/package checks. Production Lua syntax and vanilla record checks pass.

The colour regression test was corrected to initialize settings before applying
test preferences. This was a test setup error, not a production colour defect.

## Pending Evidence

The user's manual test reproduced missing effects for marked Recall destinations
while Interventions worked. The isolated OpenMW log reports
`DelayedAction is not allowed to create another DelayedAction` from `setFloat`
inside the controller's `onTeleported` callback. Detection succeeded; applying
the shader in that callback failed. Automatic playback is now queued for
`onFrame`, with a regression test that rejects shader updates during the callback.
The native smoke sequence also exercises a successful Recall notification
followed by a scripted global teleport and checks one pulse and cleanup.
The native smoke run passed with Pure Lua Multi Mark loaded, including exactly
one pulse after the scripted Recall notification and teleport, cleanup, and no
error-level log entries. A manual marked-destination Recall retest also confirmed
that the transition appears after the fix.

The mocked tests do not reproduce native OpenMW callback timing. Success
is reported after the menu closes, so a long menu wait is not sufficient evidence
that the original short matching window caused this particular report.

Run the manual sequence in TESTING.md with the actual mod enabled. Daisy's Lua
Multimark and Tamriel Rebuilt Kyne's Intervention are not tested by this archive.
