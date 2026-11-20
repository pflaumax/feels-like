# fire-frost-water Specification

## Purpose

Describes the sharp changes from fire underfoot, lava and frost spells, and how water and wet clothes chill the character until they dry.

## Requirements

### Requirement: Fire underfoot
Fire damage out of combat, and more than 15 seconds after combat, SHALL count as fire underfoot. It SHALL take the reading to the top of the scale for every body, hold it there for a moment after the last hit and then fade back over a few seconds. Fire underfoot SHALL dry wet clothes at once.

#### Scenario: Stepping into a campfire
- **WHEN** the player steps into a campfire and takes fire damage out of combat
- **THEN** the needle goes to the top of the scale and the status is Scorching

#### Scenario: Stepping out
- **WHEN** the player leaves the fire and takes no more fire damage
- **THEN** the reading falls back to normal within a few seconds

### Requirement: Fire in a fight
Fire damage in combat, or within 15 seconds after it, SHALL count as a fire spell, not fire underfoot. A fire spell SHALL change the reading only for a body that fears fire (see the body capability). One exception: while swimming in a volcanic place or a place marked with lava, a second fire hit 0.5 to 2.5 seconds after the previous one SHALL count as lava, also in a fight.

#### Scenario: Fire spell on a human
- **WHEN** a human character in combat is hit by a fire spell
- **THEN** the reading does not change

#### Scenario: Lava in a fight
- **WHEN** the player swims in lava in Searing Gorge during a fight and takes fire hits on a steady beat
- **THEN** the reading goes to the top of the scale

### Requirement: No air as hot as fire
Without fire underfoot or a fire spell, the reading SHALL stay below the top of the scale, at 95 or less.

#### Scenario: Hottest place
- **WHEN** the player stands in the hottest place on a hot afternoon with nothing burning them
- **THEN** the reading is 95 or less

### Requirement: Frost spells
Frost damage that is not also fire SHALL chill every body toward Freezing with the icy ring, in combat or out of it. The chill SHALL hold for a moment after the hit and fade over a few seconds.

#### Scenario: Frostbolt in the desert
- **WHEN** a frost spell hits the player in Tanaris
- **THEN** the reading drops to Freezing for a moment and then returns to normal

### Requirement: Swimming chills
A swim SHALL soak the clothes at once. Soaked clothes SHALL take away half of the distance between the reading and the coldest end of the scale, and less wet clothes take away less. So a swim SHALL feel cold in a mild zone, freezing in the snow and only refreshing in a desert.

#### Scenario: Swim in Elwynn Forest
- **WHEN** the player swims in Elwynn Forest on a mild day
- **THEN** the status is Cold

#### Scenario: Swim in Tanaris
- **WHEN** the player swims in Tanaris in the afternoon
- **THEN** the reading is much cooler than on the shore, and the status is Mild

### Requirement: Drying
Wet clothes SHALL dry over time: in about 90 seconds normally, faster when it is hot, slower when it is very cold, and fastest in an inn or close by a fire. Outdoors in rain the clothes SHALL stay at least a little wet, more in heavier rain. While the character is dead, the clothes SHALL stay as they are.

#### Scenario: Out of the water on a mild day
- **WHEN** the player leaves the water on a mild day and waits 90 seconds
- **THEN** the clothes are dry and the swim no longer chills

#### Scenario: Drying by the fire
- **WHEN** the player sits by a campfire in soaked clothes
- **THEN** the clothes dry in about 15 seconds

#### Scenario: Standing in the rain
- **WHEN** the player stands outdoors in rain
- **THEN** the clothes get partly wet within half a minute and do not dry fully until the rain stops or the player goes under a roof

### Requirement: Hot springs and lava
A swim in a place with hot water, like the hot springs of Winterspring, SHALL chill nothing while in the water. The clothes SHALL still chill on the shore until they dry. A swim in lava SHALL not soak the clothes.

#### Scenario: Hot springs
- **WHEN** the player swims in the hot springs of Winterspring
- **THEN** the swim does not chill the reading

#### Scenario: Leaving the hot springs
- **WHEN** the player walks out of the hot springs into the snow
- **THEN** the wet clothes chill the reading until they dry
