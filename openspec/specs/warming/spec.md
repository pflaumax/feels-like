# warming Specification

## Purpose

Describes what warms a cold character: a campfire, a torch, a fight and a drink, and when the reading turns Cozy.

## Requirements

### Requirement: Campfire warmth
A campfire aura the addon knows (Cozy Fire, and the camp fire auras of Forever) SHALL warm the reading. The warmth SHALL fade soon after the fire stops renewing the aura (a slow fire gets more time), or within a few seconds after the player walks more than about 12 yards from where they stood by it. A campfire SHALL warm nothing in an inn or while swimming.

#### Scenario: Standing by a fire on a cold night
- **WHEN** the player stands next to a campfire on a cold night
- **THEN** the reading moves toward Warm

#### Scenario: Walking away
- **WHEN** the player walks well away from the fire
- **THEN** the fire's warmth fades within a few seconds

#### Scenario: Swimming near a fire
- **WHEN** the player swims next to a campfire
- **THEN** the campfire adds no warmth

### Requirement: Forever camp fire seat
In Forever, after the player sits by a camp fire, the warmth SHALL stay while they stay within about 12 yards of their seat, for up to 15 minutes, and SHALL end when the camp fire goes out or they walk away.

#### Scenario: Getting up by the camp fire
- **WHEN** the player sat by a camp fire, stands up and walks around next to it
- **THEN** the fire still warms them

#### Scenario: Camp fire goes out
- **WHEN** the camp fire's nearby aura ends while the player stands by their seat
- **THEN** the fire's warmth ends

### Requirement: Fire never makes a body hot
A campfire, a torch and a fight SHALL warm the reading no higher than Warm. A fire SHALL never make the reading colder than it would be without the fire.

#### Scenario: Fire on a mild day
- **WHEN** the player stands by a campfire where the air is Mild
- **THEN** the reading is at most Warm, never Hot

#### Scenario: Fire on a hot day
- **WHEN** the player stands by a campfire in a hot desert afternoon
- **THEN** the reading is the same as without the fire

### Requirement: Torch
A lit torch held in a hand, or the Night Watchman's Torch toy and the torch light it gives allies, SHALL warm a cold reading by a little. It SHALL add nothing once the air is 20 or warmer, so a torch never makes the reading Warm. A torch SHALL warm nothing in an inn or in the water.

#### Scenario: Torch on a cold night
- **WHEN** the player lights the Night Watchman's Torch on a cold night
- **THEN** the reading is a bit warmer

#### Scenario: Torch on a mild day
- **WHEN** the player holds a lit torch where the reading is already 20 or more
- **THEN** the torch adds nothing and the reading does not become Warm

### Requirement: Fight
In combat the reading SHALL warm a little. The warmth SHALL build over the first 8 seconds of a fight and fade over 30 seconds after it ends. A fight SHALL warm every body alike, no higher than Warm.

#### Scenario: Fight in the snow
- **WHEN** the player fights for 10 seconds in a cold zone
- **THEN** the reading is a little warmer than before the fight

#### Scenario: After the fight
- **WHEN** 30 seconds have passed since the fight ended
- **THEN** the fight adds no warmth

### Requirement: Drink
The addon SHALL follow the game's own drunk lines in chat, in any game language. Tipsy, drunk and completely smashed SHALL warm a reading below 0 by a growing amount, but never past 0, the middle of Mild. A drink SHALL NOT change a reading at 0 or above. "You feel sober again" or two hours without a drunk line SHALL end the warmth.

#### Scenario: Tipsy on a cold night
- **WHEN** the game says "You feel tipsy." while the reading is Cold
- **THEN** the reading is warmer, and more drinks make it warmer still

#### Scenario: Drunk in the desert
- **WHEN** the player is drunk where the reading is on the warm half
- **THEN** the drink changes nothing

#### Scenario: Reload and login
- **WHEN** the player reloads the interface while drunk, and later logs in again
- **THEN** the drink still warms after the reload, and the new login starts sober

### Requirement: Cozy
The status SHALL be Cozy instead of its usual word when the player is in an inn or close by a campfire, is not swimming, and the reading is Mild or Warm and not close to Cold. Cozy SHALL have its own color.

#### Scenario: By the fire on a cold evening
- **WHEN** the player sits by a campfire and the reading rises to Mild
- **THEN** the status is Cozy

#### Scenario: Cold by the fire
- **WHEN** the player stands by a campfire but the reading is still Cold or near Cold
- **THEN** the status is the usual word, not Cozy

#### Scenario: Hot inn or a swim
- **WHEN** the reading in an inn is Hot, or the player swims next to a fire
- **THEN** the status is not Cozy
