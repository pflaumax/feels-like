# gauge Specification

## Purpose

Describes the thermometer by the minimap: the ring, the needle, the colors, the status word, what shows on screen, and how the player moves, locks and sizes it.

## Requirements

### Requirement: Scale and status words
The reading SHALL run from -100 (coldest) to 100 (hottest) on a 270-degree dial of 12 segments, blue on the cold end and red on the hot end. The status word SHALL follow the segment: Freezing (segments 1-2), Cold (3-4), Mild (5-8), Warm (9), Hot (10-11) and Scorching (12), each in its own color. Cozy SHALL replace the word when it applies.

#### Scenario: Words across the scale
- **WHEN** the reading is -80, -50, 0, 40, 60 and 90
- **THEN** the word is Freezing, Cold, Mild, Warm, Hot and Scorching

#### Scenario: Cozy wins
- **WHEN** the reading is Mild and Cozy applies
- **THEN** the word is Cozy in its own color

### Requirement: Needle motion
The needle SHALL move to a new reading like a needle on a spring: it speeds up, swings a little past the reading and settles. It SHALL move the same at any frame rate. When the dial comes back on screen after it was hidden, the needle SHALL show the reading at once, with no swing.

#### Scenario: Big change
- **WHEN** the reading jumps from Cold to Scorching
- **THEN** the needle swings a little past the new reading and settles on it

#### Scenario: Dial shown again
- **WHEN** the player switches On screen from "Status only" back to a mode with the gauge
- **THEN** the needle already points at the reading

### Requirement: Icy and hot ends
The ring SHALL turn icy as the reading goes deeper into Freezing and SHALL glow red from the start of Scorching. The glow SHALL follow the needle but never go past the reading, so a needle that swings past Hot does not light the ring like Scorching.

#### Scenario: Deep cold
- **WHEN** the reading is -90
- **THEN** the ring looks icy

#### Scenario: Swing past Hot
- **WHEN** the reading is Hot and the needle swings briefly into Scorching
- **THEN** the ring does not glow red

### Requirement: Look per client
In Forever the ring SHALL be bronze. With a classic-style minimap in Forever (narrower than the standard one) the ring SHALL match the classic minimap buttons. On Retail the ring SHALL be gold. A client without vector graphics SHALL get a simpler dial drawn with lines.

#### Scenario: Forever and Retail
- **WHEN** the addon runs in Forever and then on Retail
- **THEN** the ring is bronze in Forever and gold on Retail

### Requirement: Unit symbol
The gauge SHALL show a degree symbol, °C or °F, from the Units setting. The gauge SHALL show no number, and the unit SHALL not change the reading.

#### Scenario: Fahrenheit
- **WHEN** the player picks Fahrenheit
- **THEN** the symbol inside the gauge changes to °F and the needle stays where it is

### Requirement: On screen choice
The On screen setting SHALL choose one of five modes: "Gauge, status on hover" (the default), "Gauge and status", "Gauge only", "Status only" and "Nothing". The readings, the chat lines and the panel feed SHALL go on in every mode. In "Status only" the word SHALL take the gauge's place and Scale SHALL set the size of the word, never smaller than readable.

#### Scenario: Status on hover
- **WHEN** the mode is "Gauge, status on hover" and the player hovers the gauge
- **THEN** the status word shows next to the gauge until the mouse leaves

#### Scenario: Nothing
- **WHEN** the mode is "Nothing"
- **THEN** neither the gauge nor the word shows, and the chat lines and panel feed still work

#### Scenario: Status only
- **WHEN** the mode is "Status only"
- **THEN** only the word shows, where it showed next to the gauge, and hovering it shows the tooltip

### Requirement: Word placement
Near the minimap the word SHALL sit on the side of the gauge away from the minimap. Far from the minimap it SHALL sit under the gauge, or in "Status only" in the gauge's place. The word SHALL have a dark outline, so it stays readable on snow and sand.

#### Scenario: Gauge left of the minimap
- **WHEN** the gauge sits left of the minimap
- **THEN** the word shows on the left side of the gauge

### Requirement: Default place
By default the gauge SHALL sit by the minimap at a place fitted to each client and to a classic minimap in Forever. It SHALL follow the minimap when the minimap changes size or the Edit Mode layout changes. Without a minimap it SHALL sit near the lower right corner of the screen.

#### Scenario: Minimap resized
- **WHEN** the player changes the minimap size in Edit Mode and the gauge has never been moved
- **THEN** the gauge stays at its place by the minimap

### Requirement: Moving
While unlocked, holding Shift and dragging the gauge or the word with the left mouse button SHALL move them together, and the new place SHALL be saved. A press without a real move SHALL keep the old place. A drag without Shift SHALL print, once per session, how to move it, or that it is locked. The gauge SHALL stay on the screen.

#### Scenario: Shift-drag
- **WHEN** the player holds Shift and drags the gauge to a new place
- **THEN** the gauge and the word move there and stay there after a reload

#### Scenario: Drag without Shift
- **WHEN** the player drags the unlocked gauge without Shift for the first time
- **THEN** a chat line says to hold Shift and drag to move the gauge

### Requirement: Lock
"Lock position" SHALL stop moving. A locked gauge SHALL let mouse clicks pass through to the world when it needs the mouse for neither the hover word nor the tooltip.

#### Scenario: Locked with no hover
- **WHEN** the gauge is locked, the mode is "Gauge only" and the tooltip is off
- **THEN** clicks on the gauge reach the world behind it

### Requirement: Size and reset
The Scale setting SHALL size the gauge from 0.3 to 2 in steps of 0.01. The default SHALL be 0.53 in Forever and 0.45 on Retail. The Position Reset button SHALL move the gauge or the word back to its default place by the minimap.

#### Scenario: Reset after a move
- **WHEN** the player moved the gauge and clicks Reset
- **THEN** the gauge goes back to its default place by the minimap
