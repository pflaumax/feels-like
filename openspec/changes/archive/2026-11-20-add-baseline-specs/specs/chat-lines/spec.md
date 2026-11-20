# Spec Delta

## Purpose

Describes the character's short reactions in chat: when they speak, how rarely, when they stay quiet, and the lines of their own that some bodies have.

## ADDED Requirements

### Requirement: Private lines in chat
With "Flavor lines in chat" on, the character SHALL now and then react with a short line in the chat window, in the emote color, that only the player sees. The lines SHALL be in the chosen language. The lines of one kind SHALL take turns, so the same line does not come twice in a row.

#### Scenario: The cold sets in
- **WHEN** the reading turns Cold and stays Cold
- **THEN** a line like "A chill runs down your back." shows in chat, only for the player

### Requirement: What the lines react to
A line SHALL come when the reading has held for 3 seconds on one of these: fire underfoot with Scorching, Cozy by a fire, Cozy in an inn, soaked clothes out of the water, Freezing, Cold, Hot, Scorching, or rain or snow falling on the player while the word is Mild or Warm. When several fit, they SHALL come in that order.

#### Scenario: Cozy by the fire
- **WHEN** the word turns Cozy by a campfire and holds for 3 seconds
- **THEN** a Cozy line like "You warm your hands by the fire." shows

#### Scenario: Short dip
- **WHEN** the word turns Cold for only 2 seconds and goes back to Mild
- **THEN** no line shows

#### Scenario: Rain on a mild day
- **WHEN** rain falls on the player while the word is Mild
- **THEN** a rain line can show

### Requirement: One-time events
Getting more drunk while the drink warms the player, and lighting a torch that warms them, SHALL each get a line at that moment or not at all.

#### Scenario: Drink in the cold
- **WHEN** the game says the player got drunker while the reading is cold
- **THEN** a line like "The drink warms you from the inside." shows

### Requirement: How often
The same kind of line SHALL come at most once in 10 minutes, and any line at most once a minute. A word reached again within its 10 minutes SHALL stay quiet for that whole stretch.

#### Scenario: Back and forth
- **WHEN** the reading goes Cold, Mild and Cold again within 5 minutes
- **THEN** only the first Cold gets a line

### Requirement: When the lines stay quiet
No line SHALL come in the first 10 seconds after login or a reload, and what the character feels then SHALL be no news later. In combat or while a test value shows, a line SHALL wait and come later if the word still holds. A one-time event SHALL be dropped then. While the character is dead, no line SHALL come. With the setting off, no line SHALL come.

#### Scenario: Login in the snow
- **WHEN** the player logs in where the reading is Freezing
- **THEN** no Freezing line shows for this stretch of Freezing

#### Scenario: Cold during a fight
- **WHEN** the word turns Cold in combat and is still Cold when the fight ends
- **THEN** the Cold line shows after the fight

### Requirement: Lines of the body
Undead characters SHALL get their own lines for Freezing, Cold, Hot and Scorching, because they do not breathe, sweat or shiver. Tauren and druids in a fur form SHALL get their own lines for those words too. This SHALL hold whatever the "Feel by race" and "Undead feel" settings say. The other lines SHALL be shared.

#### Scenario: Undead in the heat
- **WHEN** an undead character's word turns Hot
- **THEN** the line is one of the undead lines, with no sweat or breath in it

#### Scenario: Tauren in the heat
- **WHEN** a tauren's word turns Hot
- **THEN** the line is one of the fur lines, like "Your fur is far too warm for this."
