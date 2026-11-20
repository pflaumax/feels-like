# Spec Delta

## Purpose

Describes the settings page: which settings it has, their defaults, how they are kept, how the language changes and when the page can open.

## ADDED Requirements

### Requirement: Settings page
The addon SHALL have a page in Options, AddOns, Feels Like with these settings and defaults: On screen ("Gauge, status on hover"), Units (Celsius), Tooltip on hover (on), Feel by race (on), Undead feel (Numb), Seasons and holidays (on), Flavor lines in chat (on), Language, Lock position (off), Scale (0.53 in Forever, 0.45 on Retail) and a Position Reset button.

#### Scenario: First login
- **WHEN** the player logs in with the addon for the first time
- **THEN** every setting has its default

### Requirement: Settings apply at once and are kept
A changed setting SHALL take effect at once, with no reload, except the language of the settings page itself. Settings SHALL be kept between sessions.

#### Scenario: Turn off the tooltip
- **WHEN** the player turns off "Tooltip on hover"
- **THEN** hovering the gauge shows no tooltip right away

#### Scenario: Next session
- **WHEN** the player changes Units to Fahrenheit and logs in again later
- **THEN** the gauge still shows °F

### Requirement: Old and unknown settings
Settings saved by older versions SHALL carry over: the old "Show status" and "Show gauge" choices SHALL become the matching On screen mode. A saved On screen mode or language that no longer exists SHALL go back to its default.

#### Scenario: Upgrade from 0.3.2
- **WHEN** a player who had "Show gauge" off in 0.3.2 updates to 0.4.0
- **THEN** On screen is "Nothing"

### Requirement: Languages
The addon SHALL speak English, Ukrainian, German, French, Spanish and Portuguese. The default SHALL be the game client's language when the addon has it (German, French, Spanish for Spain and Mexico, Brazilian Portuguese), else English. Ukrainian SHALL be picked by hand. A text with no translation SHALL show in English.

#### Scenario: German client
- **WHEN** a player with a German game client starts the addon for the first time
- **THEN** the language is German

#### Scenario: Missing translation
- **WHEN** a text has no translation in the chosen language
- **THEN** it shows in English

### Requirement: Changing the language
A new language SHALL change the status word, the tooltip, the panel feed and the chat lines at once. The settings page SHALL keep its language until a reload, so the addon SHALL offer a reload in its own window with Reload and Later. Changing back to the page's language SHALL close the window. The window SHALL not use the game's shared popup and SHALL not close with Escape.

#### Scenario: Pick Ukrainian
- **WHEN** the player picks Ukrainian on an English page
- **THEN** the status word changes at once and a window offers to reload the interface

#### Scenario: Later
- **WHEN** the player clicks Later in the reload window
- **THEN** the window closes and the settings page stays in English until the next reload

### Requirement: Opening the settings
`/feels` and a click on the panel feed SHALL open the settings page. In combat, in a boss encounter, in a Challenge Mode run or in a PvP match the page SHALL stay closed, and a chat line SHALL say when it opens.

#### Scenario: In combat
- **WHEN** the player types `/feels` in combat
- **THEN** the page does not open and a chat line says the settings open after combat

#### Scenario: Out of combat in a boss fight
- **WHEN** the player types `/feels` during a boss encounter while out of combat
- **THEN** a chat line says the settings open after the boss fight, the Challenge Mode run or the PvP match
