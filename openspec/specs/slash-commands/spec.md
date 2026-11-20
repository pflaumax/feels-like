# slash-commands Specification

## Purpose

Describes the `/feels` slash command and its subcommands for the settings, debugging, finding auras, testing the gauge and measuring frames by the minimap.

## Requirements

### Requirement: Command and help
`/feels` and `/feelslike` SHALL be the same command. With no subcommand it SHALL open the settings (see the settings capability). An unknown subcommand SHALL print the list of commands. The subcommand SHALL not care about letter case. Frame names after `measure` SHALL keep their case.

#### Scenario: Unknown subcommand
- **WHEN** the player types `/feels help`
- **THEN** chat lists every command with a short description

#### Scenario: Upper case
- **WHEN** the player types `/feels DEBUG`
- **THEN** it works like `/feels debug`

### Requirement: Debug
`/feels debug` SHALL print every factor of the current reading in chat: the client, the place, the time, the weather (with the raw values from the game), the season, humid air, the shelter, the campfire, the torch, swimming and wetness, the race and body, the drink, the fight, fire underfoot, frost spells, frost and fire resistance (marked as not counted), death, the result and its word, the chat lines, the dial renderer, the panel feed, and where the gauge sits.

#### Scenario: Debug in an inn
- **WHEN** the player types `/feels debug` in an inn
- **THEN** chat shows one line per factor, and the shelter line says inn

#### Scenario: Debug during a test
- **WHEN** a test value shows and the player types `/feels debug`
- **THEN** the result line says that a test is active and how to end it

### Requirement: Auras
`/feels auras` SHALL list the player's buffs with their spell IDs. Known fire auras SHALL get a note, like "counts as campfire" or "counts as a torch". Known fire auras that the buff list hides SHALL be listed too, marked "not in the buff list". When the game hides auras in combat, it SHALL say so. With no buffs it SHALL say "none".

#### Scenario: By a campfire
- **WHEN** the player sits by a campfire and types `/feels auras`
- **THEN** the fire's aura is listed with its ID and the note "counts as campfire"

#### Scenario: In combat
- **WHEN** auras are restricted in combat
- **THEN** the list says they are hidden while auras are restricted

### Requirement: Test values
`/feels test <number>` SHALL point the needle at that value, from -100 to 100, for 30 seconds, then go back to the real reading and say so in chat. `/feels test sweep` SHALL move the needle across the whole scale in steps and then go back. `/feels test cozy` SHALL turn the Cozy word on or off for 30 seconds and keep the needle where it is. `/feels test off` SHALL go back to the real reading at once.

#### Scenario: Test a value
- **WHEN** the player types `/feels test 50`
- **THEN** the needle points at 50 and the word is Hot, and after 30 seconds the real reading is back with a chat line

#### Scenario: Out-of-range value
- **WHEN** the player types `/feels test 500`
- **THEN** the needle points at the top of the scale

#### Scenario: End early
- **WHEN** a test runs and the player types `/feels test off`
- **THEN** the gauge shows the real reading at once

### Requirement: Tests do not touch the real reading
While a test runs, real readings SHALL not move the gauge. The chat lines SHALL wait. The addon API and the panel feed SHALL keep the real reading.

#### Scenario: API during a test
- **WHEN** a test shows 90 and another addon asks for the temperature
- **THEN** it gets the real reading, not 90

### Requirement: Measure
`/feels measure <frame>` SHALL find a frame by its global name or by a dotted path, like `MinimapCluster.DielFrame`, and print where it sits next to the minimap and where the gauge sits. A frame closed to addons SHALL get a line that it cannot be measured. A name that finds no frame SHALL get a hint to find the name with `/fstack`.

#### Scenario: Unknown frame
- **WHEN** the player types `/feels measure NoSuchFrame`
- **THEN** chat says there is no frame by that name and suggests `/fstack`
