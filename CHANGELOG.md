# Changelog

## 0.2.3

- Recognise Daisy's Greater Recall custom effect directly, including translated
  spell records. Add archive-backed and isolated native destination-menu tests.
- Verify Daisy's Lua Multimark 2 Greater Recall in-game. Both supported multimark
  mods remain optional; no third-party scripts or assets are bundled.
- Recognise optional Tamriel Data Kyne's Intervention by custom effect or record
  identity, including its Divine Intervention fallback. Keep its dedicated
  colour control hidden pending normal-casting acceptance.
- Add an isolated copied-dependency Kyne test profile without changing POTI.

## 0.2.2

- Start automatic effects on the next frame, avoiding nested delayed-action errors after scripted teleports.
- Keep automatic spell matching alive while a teleport spell menu is open, improving
  compatibility with Lua multimark mods that choose a destination after casting.
- Recognise Recall and Intervention variants by spell record name/id when they do
  not expose the vanilla teleport effects directly.
- Add separate colour overrides for Recall, Almsivi Intervention, and Divine
  Intervention, each inheriting Default Colour unless overridden.
- Rename the shared colour setting to Default Colour; expose only the vanilla
  teleport spell colour overrides in this update.
- Verify Pure Lua Multi Mark 2.5 marked-destination Recall in-game; no additional
  mod is required to use Teleport Transition.

## 0.2.1

- Set stronger purple defaults: strength 2.4, duration 1.8, distortion 3,
  ripple bands 3, colour intensity 0.85, and chromatic fringe 0.6.
- Show numeric minimum/maximum ranges in Scripts settings.
- Separate automatic spell triggering from the master effect switch, allowing
  integration-only use while retaining previews and other mods' managed calls.

## 0.2.0

- Add separate distortion, ripple-band, magical-colour, tint, and fringe controls.
- Add isolated POTI shader-chain testing without changing installed profiles.

## 0.1.0

- Initial arrival ripple for Recall and both Intervention spells.
- Add Scripts settings, reduced-motion mode, preview hotkey, and Lua integration.
- Add isolated test character, test launcher, and engine smoke checks.
