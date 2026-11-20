# Spec Delta

## Purpose

Describes how the character's body changes what they feel: race, druid forms with fur, the undead choice, the "Feel by race" setting and death.

## ADDED Requirements

### Requirement: Race changes how strongly you feel
With "Feel by race" on, the race SHALL scale how far the reading is from 0: one factor for the cold side and one for the hot side. Dwarves SHALL feel the cold less. Tauren SHALL feel the cold less and the heat more. Trolls SHALL feel the cold more and the heat less. Humans, orcs, night elves, gnomes, Skyborne and any race not in the table SHALL feel like a human.

#### Scenario: Dwarf in Dun Morogh
- **WHEN** a dwarf and a human stand in the same cold place
- **THEN** the dwarf's reading is less cold than the human's

#### Scenario: Tauren and troll in the desert
- **WHEN** a tauren and a troll stand in the same hot place
- **THEN** the tauren's reading is hotter than a human's and the troll's is less hot

#### Scenario: Mild place
- **WHEN** characters of different races stand in a place that reads near 0
- **THEN** their readings are almost the same

### Requirement: Druid fur forms
With "Feel by race" on, a druid in Cat, Bear, Dire Bear, Travel, Aquatic or Moonkin form SHALL feel like a tauren, whatever the race.

#### Scenario: Night elf in Bear Form
- **WHEN** a night elf druid shifts into Bear Form in the snow
- **THEN** the reading is less cold than in normal form

### Requirement: Undead choice
With "Feel by race" on, undead characters SHALL feel the way the "Undead feel" setting says. Numb, the default, SHALL feel little of the cold and the heat, and a fire spell in a fight SHALL scorch them: the reading jumps toward the top for a moment and fades over a few seconds. "Like the living" SHALL feel like a human, also in fire.

#### Scenario: Numb undead in the snow
- **WHEN** an undead character with Numb stands in Winterspring
- **THEN** the reading is much less cold than a human's

#### Scenario: Numb undead hit by a fire spell
- **WHEN** an undead character with Numb is hit by a fire spell in combat
- **THEN** the reading jumps toward the top of the scale for a moment

#### Scenario: Undead like the living
- **WHEN** an undead character with "Like the living" is hit by a fire spell in combat
- **THEN** the reading does not change, as for a human

### Requirement: Feel by race off
With "Feel by race" off, every character SHALL feel like a human, in every form, and fire spells SHALL not scorch the undead.

#### Scenario: Tauren with the setting off
- **WHEN** "Feel by race" is off and a tauren stands in a hot place
- **THEN** the reading is the same as a human's

### Requirement: What the body does not change
A fire SHALL warm every body only up to Warm. Fire underfoot and frost spells SHALL hit every body alike. A drink and a fight SHALL add the same warmth to every body.

#### Scenario: Troll by a fire
- **WHEN** a troll stands by a campfire on a cold night
- **THEN** the reading rises no higher than Warm, as for any race

### Requirement: Death
While the character is dead, as a ghost or a wisp, the reading SHALL be Cold at -65, the same in every place, until the character is alive again. It SHALL never be Cozy then. A hunter's Feign Death SHALL not count as dead.

#### Scenario: Ghost in Tanaris
- **WHEN** the character dies in Tanaris and runs back as a ghost
- **THEN** the reading is -65, Cold, the whole time

#### Scenario: Back to life
- **WHEN** the character is resurrected
- **THEN** the reading is the real one for the place again
