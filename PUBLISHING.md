# Publishing Teleport Transition

The source repository is suitable for GitHub. The production ZIP is the Nexus
download; do not upload the repository, test bundle, or runtime folders as the main
mod file. Workflows automate publication once committed/pushed and configured;
no live publication was performed while preparing them.

## Before Publishing

- No redistribution/source-reuse license is selected. Dependent mods should
  require a separate Teleport Transition installation rather than bundle its files.
- Confirm the latest version's appearance, door exclusion, failed casts,
  settings reset/save/reload, and full POTI gameplay compatibility manually.
- Read reports/manual-results.md and reports/automated-results.md. Do not describe
  untested cases as confirmed or claim a clean full POTI compatibility pass.
- Record a short video of the ripple and a screenshot of the Scripts settings.
- Confirm your preferred author name, Nexus permissions, and support links.

## Build and Check

From the repository root:

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p "test_*.py"
python tests/verify_readiness.py
.\tools\start-test.ps1 -SmokeTest
.\tools\package.ps1
git status --short
```

Local game and engine paths are overridable in the test tools. Git ignores
generated archives, runtime saves/logs, Python caches, and local dependencies.
The production manifest loads only scripts/teleport_transition/player.lua.
The cross-platform builder is `python tools/package.py`; add `--test` for the
separate developer kit. The PowerShell wrapper builds both. VERSION supplies all
archive names. ZIP timestamps/permissions are fixed for byte-identical rebuilds.

## Automatic GitHub Releases

The workflows follow the working FactionIntervention publishing structure:

- Pushes to main and pull requests run offline tests and build a downloadable
  production artifact. No credentials are passed to these validation tests.
- Push a tag `vX.Y.Z` to test/build, publish the production ZIP on GitHub Releases,
  then add that exact verified file as a new Nexus version.
- The tagged commit must belong to main. VERSION, the README heading, shader
  version metadata, tag, and matching CHANGELOG heading must agree.
- Manual dispatch of Publish Releases from main builds/checks a package but does
  NOT publish to GitHub or Nexus. Drafting/publishing an existing-tag GitHub release
  alone is not a trigger; use the version-tag push.
- GitHub retries verify any existing matching asset rather than overwrite it.
  Release jobs are serialized; old Nexus file versions are not archived/deleted.

For the next version, update VERSION, the README heading, the shader's technique
version, and add a `## X.Y.Z` CHANGELOG section with release notes. No package script
filename edits are needed. Commit/push those changes to main, then:

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

Replace X.Y.Z with the actual version. Review what is committed before pushing a
tag: publication is automatic. GitHub/Nexus uploads use the same SHA256-verified
ZIP and version-specific changelog. The optional test ZIP is never auto-published.

Keep the source README visible at the repository root. Publish future version
changes consistently in VERSION, shader metadata, README, and CHANGELOG.

## Nexus Environment Setup

Keep the GitHub environment named `nexus`, with the selected main branch and `v*`
tag deployment rules shown in your setup. The Nexus job uses this environment.

| Setting | Location | Value |
| --- | --- | --- |
| NEXUSMODS_API_KEY | nexus environment secret | Your API key; never commit or paste into logs |
| NEXUSMODS_FILE_ID | nexus environment variable | Existing Nexus file ID, not PLACEHOLDER |
| NEXUSMODS_MOD_ID | nexus environment variable | Nexus v3 global mod ID, not PLACEHOLDER |
| NEXUSMODS_ENABLED | Optional repository variable | Set `false` to pause Nexus; otherwise enabled by default |

The official upload action adds versions to an EXISTING Nexus file. Create the
Nexus mod page and upload the first production ZIP manually. For bootstrapping,
set repository variable NEXUSMODS_ENABLED=false, create your first GitHub release,
then upload its ZIP manually to Nexus and obtain the real IDs. Clear the variable
or set it to true when ready for automatic uploads on later version tags.

The file ID is available under the Nexus file's API Info. For the mod ID, query
`https://api.nexusmods.com/v3/games/morrowind/mods/<page-number>` and use the response's
`id`; the game-scoped page number in the Nexus URL is not necessarily the v3 ID.
See the [official upload action instructions](https://github.com/Nexus-Mods/upload-action#how-to-find-the-file-id).

Placeholder IDs or a missing key fail before uploading; the GitHub release still
succeeds independently. GitHub does not expose environment secrets to the build
or pull-request jobs. The Nexus action is pinned to the same reviewed commit as
FactionIntervention. A failed upload is not silently treated as published.

Rerun only the failed Nexus job after fixing configuration. Do not replay a
successful Nexus upload without checking the file page; Nexus duplicate-version
behaviour is not covered by the offline retry tests.

## Nexus Description Draft

Teleport Transition is an OpenMW 0.52 mod and modder's resource: a procedural
magical ripple with a reusable shader and Lua integration interface.
Use its optional standalone integration for Recall, Almsivi Intervention, and
Divine Intervention, or use it strictly as a resource for another mod's spells,
portals, scripted travel, or other events. List Teleport Transition as a dependency;
players install it separately. Do not bundle or redistribute its files.

For standalone use, leave Enabled and Automatic spell effects on. For resource-only
use, turn Automatic spell effects off in Options > Scripts > Teleport Transition,
leave Enabled on, and keep TeleportTransition.omwscripts loaded. Other mods can
then call the interface or send an event to play the effect without automatic
vanilla spell triggers.

Choose strength, distortion, ripple bands, duration, magical colour, colour
intensity, and chromatic fringe. Reduced motion removes warping, moving wave
patterns, and colour-channel displacement. Ctrl+Shift+F11 previews the effect.
The mod does not alter spell records, teleport destinations, or travel timing.
It uses no additional textures, models, or audio.
No permission to redistribute, copy, or adapt the shader/scripts is granted.
Contact the author before incorporating project files into another release.

Install the production archive as a mod, enable its content manifest, and restart
OpenMW. The dynamic shader cannot be manually toggled in the F2 HUD; use Scripts
settings. Scrolls and enchanted items are not supported by the automatic detector.
The effect is an arrival ripple, not a crossfade between departure and destination.

## Nexus Files

- Main file: dist/Teleport-Transition-0.2.1.zip.
- Optional test file: dist/Teleport-Transition-Test-0.2.1.zip.
- Requirement: OpenMW 0.52 with post-processing enabled. No POTI dependency.
- Describe the current build as a prototype/beta until the manual checklist passes.
