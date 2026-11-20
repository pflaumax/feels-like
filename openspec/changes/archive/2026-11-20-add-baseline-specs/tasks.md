# Tasks

This change writes down behavior that already ships. No task changes code. When a spec and the code disagree, fix the spec text. If the code looks wrong, add it to `docs/IDEAS.md` as a bug to fix in its own change.

## 1. Temperature model

- [x] 1.1 Check every requirement and scenario in `specs/world-climate/spec.md` against `FeelsLike/Model.lua`, `FeelsLike/Sensors.lua` and `FeelsLike/Data/`. Fix the spec where it differs. Done when each scenario matches the code or a case in `tests/model_test.lua`.
- [x] 1.2 Check `specs/warming/spec.md` against `Model.lua`, `Sensors.lua` and `Core.lua` (campfire, camp fire seat, torch, fight, drink, Cozy). Done when each scenario matches the code or a case in `tests/model_test.lua`.
- [x] 1.3 Check `specs/fire-frost-water/spec.md` against `Model.lua` and `Sensors.lua` (fire underfoot, lava beat, frost spells, wetness and drying, hot springs). Done when each scenario matches the code or a case in `tests/model_test.lua`.
- [x] 1.4 Check `specs/body/spec.md` against `FeelsLike/Data/Races.lua`, `Core.lua` and `Model.lua` (race factors, fur forms, undead choice, setting off, death). Done when each scenario matches the code or a case in `tests/model_test.lua`.

## 2. What the player sees

- [x] 2.1 Check `specs/gauge/spec.md` against `FeelsLike/Gauge.lua`, `DialVector.lua` and `DialLines.lua` (bands, needle, icy and hot ends, ring per client, On screen modes, place, move, lock, scale, reset). Done when each scenario matches the code or a case in `tests/smoke_test.lua` or `tests/model_test.lua`.
- [x] 2.2 Check `specs/tooltip/spec.md` against `Gauge.lua` and the reason code in `Model.lua`. Check that every reason word in the spec is in `Model.REASON_WORDS` or a body word from `Core.lua`. Done when each scenario matches the code or a case in `tests/smoke_test.lua`.
- [x] 2.3 Check `specs/chat-lines/spec.md` against `FeelsLike/Flavor.lua` and `Core.lua` (triggers, order, cooldowns, quiet times, body lines). Check that every quoted line exists in `Flavor.lua`. Done when each scenario matches the code or a case in `tests/smoke_test.lua`.

## 3. Settings, commands and API

- [x] 3.1 Check `specs/settings/spec.md` against `FeelsLike/Options.lua`, `Core.lua` (defaults, saved-settings upgrade, opening rules) and `FeelsLike/Locale.lua` with `FeelsLike/Locale/*.lua` (languages and client defaults). Done when each scenario matches the code or a case in `tests/smoke_test.lua`.
- [x] 3.2 Check `specs/slash-commands/spec.md` against the slash command code in `Core.lua` and the Commands table in `README.md`. Done when every subcommand in the code is in the spec, and the reverse.
- [x] 3.3 Check `specs/addon-api/spec.md` against `Core.lua` (`FeelsLike.GetTemperature`, `FeelsLike.API_VERSION`), `FeelsLike/Broker.lua` and "For addon authors" in `README.md`. Done when each scenario matches the code or a case in `tests/smoke_test.lua`.

## 4. Whole change

- [x] 4.1 Run `openspec validate add-baseline-specs --strict`. Done when it reports the change as valid.
- [x] 4.2 Run `luajit tests/model_test.lua && luajit tests/smoke_test.lua` and `git status`. Done when both tests pass and nothing outside `openspec/` has changed.
## Workflow follow-up

- Run `/openspec-verify-change add-baseline-specs`.
- Archive with `/openspec-archive-change add-baseline-specs`. The specs then move to `openspec/specs/`.
- Later, in game, in Forever and on Retail: check the scenarios no test covers (the tooltip next to a unit tooltip, the reload window after a language change, `/feels test 50`, `/feels auras` by a campfire, and the panel feed if a panel addon is installed). Every one was checked against the code in task 1 to 3. If one behaves differently, fix the spec in `openspec/specs/` or open a change for the bug.
