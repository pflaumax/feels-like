# tooltip Specification

## Purpose

Describes the tooltip on hover: what it shows, how its "Why" line names the reasons for the current word, and how it stays clear of the game's own tooltip.

## Requirements

### Requirement: Own tooltip
With "Tooltip on hover" on, hovering the gauge, or the word when it shows on its own or always, SHALL show the addon's own tooltip. It SHALL look like the game's tooltip and open toward the middle of the screen. The addon SHALL never show, hide or change the game's shared tooltip, so the tooltips of units, map pins and other addons stay as they are.

#### Scenario: Hover the gauge
- **WHEN** the player hovers the gauge
- **THEN** a tooltip opens toward the middle of the screen

#### Scenario: Unit tooltips after hovering
- **WHEN** the player hovers the gauge and then a creature in the world
- **THEN** the creature's tooltip shows as usual

#### Scenario: Setting off
- **WHEN** "Tooltip on hover" is off
- **THEN** hovering the gauge or the word shows no tooltip

### Requirement: Tooltip content
The tooltip SHALL show the status word in its color, then the "Why" line, then "Shift-drag to move" while the gauge is unlocked. While a test value shows, it SHALL say "A test value. /feels test off ends it." instead of the "Why" line. The tooltip SHALL update while it is open, without flicker.

#### Scenario: Unlocked gauge
- **WHEN** the gauge is unlocked and the player hovers it
- **THEN** the tooltip ends with "Shift-drag to move"

#### Scenario: Test running
- **WHEN** `/feels test 50` runs and the player hovers the gauge
- **THEN** the tooltip says it is a test value and shows no "Why" line

#### Scenario: Reading changes while open
- **WHEN** the reading changes from Cold to Freezing while the tooltip is open
- **THEN** the tooltip shows Freezing at once

### Requirement: Why line
The "Why" line SHALL name up to three reasons, strongest first, and skip very small ones. A cold word SHALL name only what makes it colder, a warm word only what makes it warmer, and Mild both. What makes it colder SHALL be blue and what makes it warmer orange. On the warm half, the warmer reasons SHALL come first.

#### Scenario: Snowy night
- **WHEN** the reading is Freezing in Winterspring at night in snow
- **THEN** the line reads "Why: a cold place, snow, the night" in blue

#### Scenario: Cold word with a torch
- **WHEN** the reading is Cold although a torch warms the player a little
- **THEN** the line names no torch

#### Scenario: Mild with both sides
- **WHEN** the reading is Mild in a cold place warmed by a campfire, but not Cozy
- **THEN** the line names reasons in blue and in orange

### Requirement: Reason words
The reasons SHALL be plain words: the place (a cold, cool, warm or hot place), the night, the sun, the weather (rain, snow, a sandstorm), the season (winter, summer, Winter Veil, Midsummer), humid air, the inn, a roof, a campfire, a torch, the water, wet clothes, the body (your race, your fur, dead flesh), a drink, a fight, a frost spell and fire. Under a roof the line SHALL not name the sun or the weather.

#### Scenario: Tauren in the heat
- **WHEN** a tauren reads Hot in a desert afternoon
- **THEN** the line can name "your fur" as a reason

#### Scenario: Indoors on a sunny day
- **WHEN** the player stands in a building in the afternoon
- **THEN** the line does not name the sun

### Requirement: Cozy and death reasons
When the word is Cozy, the line SHALL name only the inn or the campfire. While the character is dead, the line SHALL name only death.

#### Scenario: Cozy in an inn
- **WHEN** the word is Cozy in an inn
- **THEN** the line is "Why: the inn"

#### Scenario: Ghost
- **WHEN** the character is a ghost
- **THEN** the line is "Why: death"
