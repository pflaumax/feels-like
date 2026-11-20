# Proposal

## Why

Feels Like 0.4.0 has no specs. Its behavior lives in the code, the README and old notes in `docs/`. Later changes need a written baseline, so that each one can state which requirement it adds or changes.

## What Changes

- Write the current, released behavior of Feels Like 0.4.0 as specs, one per capability.
- Describe what the player sees: the gauge, the status word, the tooltip, chat lines, settings and slash commands.
- No behavior changes. No code, locale, README or changelog changes.

## Capabilities

### New Capabilities

- `world-climate`: how the zone, humid air, time of day, seasons and holidays, weather and shelter set the felt temperature.
- `warming`: what warms a cold character: a campfire (also Forever camp fires), a torch, a fight and a drink, and when the reading is Cozy.
- `fire-frost-water`: fire underfoot and lava, frost spells, swimming, wet clothes that dry, and hot springs.
- `body`: how race, druid fur forms, the undead choice and death change what the character feels.
- `gauge`: the ring, needle, colors and status word by the minimap, the On screen choice, moving, locking, size and the unit symbol.
- `tooltip`: the addon's own tooltip on hover and its "Why" line with the reasons for the current word.
- `chat-lines`: the character's short private reactions in chat, how often they come and when they stay quiet.
- `settings`: the settings page, its defaults, the language choice and the reload window.
- `slash-commands`: `/feels` and its `debug`, `auras`, `test` and `measure` commands.
- `addon-api`: the reading for other addons: `FeelsLike.GetTemperature()`, `FeelsLike.API_VERSION` and the data broker feed for panels like Titan Panel.

### Modified Capabilities

None.

## Impact

- New files under `openspec/changes/add-baseline-specs/specs/`. After archive they move to `openspec/specs/`.
- No changes to `FeelsLike/`, `tests/`, `tools/`, README or `docs/CHANGELOG.md`.
- Clients covered: WoW Forever (the main target) and Retail.
