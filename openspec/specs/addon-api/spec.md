# addon-api Specification

## Purpose

Describes what other addons can read from Feels Like: the public `FeelsLike.GetTemperature()` call and the data feed for panel addons like Titan Panel.

## Requirements

### Requirement: GetTemperature
`FeelsLike.GetTemperature()` SHALL return three values: the felt temperature from -100 to 100 on the addon's own scale (not degrees), the status word, and whether the reading is Cozy. The word SHALL be the English word (Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy), whatever language the addon shows. Before the first reading after login it SHALL return nothing.

#### Scenario: Cold reading
- **WHEN** another addon calls `FeelsLike.GetTemperature()` while the reading is -50
- **THEN** it gets -50, "Cold" and false

#### Scenario: Ukrainian chosen
- **WHEN** the addon shows Ukrainian and another addon calls `FeelsLike.GetTemperature()`
- **THEN** the word is still English

#### Scenario: Right after login
- **WHEN** another addon calls it before the first reading
- **THEN** it gets nil

### Requirement: Real reading only
`FeelsLike.GetTemperature()` SHALL always return the real reading, also while `/feels test` moves the gauge.

#### Scenario: During a sweep
- **WHEN** `/feels test sweep` runs and another addon calls `FeelsLike.GetTemperature()`
- **THEN** it gets the real reading

### Requirement: API version
`FeelsLike.API_VERSION` SHALL be 1. It SHALL go up only when a change breaks callers.

#### Scenario: Version check
- **WHEN** another addon reads `FeelsLike.API_VERSION`
- **THEN** it gets 1

### Requirement: Panel feed
When a panel addon brings LibDataBroker-1.1, Feels Like SHALL offer a data source named "Feels Like" with its icon. Its text SHALL be the status word in its color and in the chosen language. Its tooltip SHALL show "Feels Like", the word, the "Why" line and "Click to open the settings". A click SHALL open the settings. A panel addon that loads after Feels Like SHALL still get the feed. Without a panel addon there SHALL be no feed, and Feels Like SHALL not bundle the library.

#### Scenario: Titan Panel
- **WHEN** Titan Panel is installed and the reading is Cold
- **THEN** the panel shows "Cold" in the Cold color

#### Scenario: Click the feed
- **WHEN** the player clicks the Feels Like feed in the panel out of combat
- **THEN** the settings page opens

#### Scenario: Hidden gauge
- **WHEN** On screen is "Nothing"
- **THEN** the panel feed still shows the current word
