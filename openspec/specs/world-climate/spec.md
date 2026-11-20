# world-climate Specification

## Purpose

Sets the air temperature the character is in from the place, the time of day, the season, the weather and the shelter, before anything warms or chills the body.

## Requirements

### Requirement: Place climate
Each known zone, subzone and instance SHALL have a base temperature from -100 to 100 and a climate (desert, arid, temperate, snow, tropical, volcanic or none). A subzone entry SHALL win over its zone. A zone not in the table SHALL use the nearest parent map that is. Forever and Retail SHALL use their own tables.

#### Scenario: Cold and hot zones
- **WHEN** the player stands in Dun Morogh and then in Tanaris at the same time of day, in clear weather
- **THEN** Dun Morogh reads on the cold side and Tanaris on the hot side

#### Scenario: Unknown open-world place
- **WHEN** the player is in an open-world place that is in no table, which is most of Retail
- **THEN** the place counts as base 0 with a temperate climate

#### Scenario: Unknown instance
- **WHEN** the player is in an instance that is not in the instance table
- **THEN** the place counts as base 0 with no climate, so the time of day changes nothing

### Requirement: Time of day
The time of day SHALL follow the server time. Day SHALL run from 9:00 to 21:00 and be warmest at 15:00. Night SHALL be coldest at 5:00. How much the time moves the reading SHALL depend on the climate: most in deserts, less in arid and temperate places, little in snow and tropical places, and not at all in volcanic places or places with no climate.

#### Scenario: Desert afternoon and night
- **WHEN** the player is in Tanaris at 15:00 and again at 5:00
- **THEN** the afternoon reads much hotter than the night

#### Scenario: Temperate night
- **WHEN** the player is in Elwynn Forest at 5:00
- **THEN** the reading is colder than at 15:00, and the night swing is larger than the day swing

#### Scenario: Volcanic place
- **WHEN** the player is in Searing Gorge at any hour
- **THEN** the time of day does not change the reading

### Requirement: Seasons and holidays
With the "Seasons and holidays" setting on, places under the sky SHALL feel a little colder in winter (December to February) and a little warmer in summer (June to August). Winter Veil (December 16 to January 2) SHALL feel colder than winter and Midsummer (June 21 to July 5) warmer than summer. The date SHALL come from the server calendar, or from the computer's date when the game has none.

#### Scenario: Winter Veil
- **WHEN** the date is December 20 and the player is outdoors in a temperate zone
- **THEN** the reading is colder than on the same hour in April, by more than an ordinary winter day

#### Scenario: Spring and autumn
- **WHEN** the date is in March to May or September to November
- **THEN** the season does not change the reading

#### Scenario: Places without their own sky
- **WHEN** the player is in a place that is fully inside, a volcanic place or a place with no climate
- **THEN** the season does not change the reading

#### Scenario: Setting off
- **WHEN** "Seasons and holidays" is off
- **THEN** no date changes the reading

### Requirement: Weather
Where the client reports weather (Forever), rain SHALL cool the reading, snow SHALL cool it more and a sandstorm SHALL heat it. The effect SHALL grow with the weather's intensity. A client without weather (Retail) SHALL get no weather effect.

#### Scenario: Snow at full intensity
- **WHEN** snow falls at full intensity in Forever
- **THEN** the reading is colder than in clear weather at the same place and hour

#### Scenario: Place fully inside
- **WHEN** the player is in a place that is fully inside, like Ironforge
- **THEN** the weather does not change the reading

### Requirement: Humid air
In tropical places, air above a warm threshold SHALL feel hotter by a quarter of the heat over that threshold. Humid air SHALL NOT make wet clothes dry faster.

#### Scenario: Stranglethorn afternoon
- **WHEN** the player is in Stranglethorn Vale on a hot afternoon
- **THEN** the reading is hotter than a dry place with the same air

#### Scenario: Cool tropical night
- **WHEN** the air in a tropical place is below the threshold
- **THEN** humid air adds nothing

### Requirement: Shelter
Indoors the reading SHALL move toward a mild room. In a snow climate a cave or house SHALL only break the wind: colder inside and more of the cold gets in. An inn (indoors and resting, not a whole city that is inside) SHALL move it toward a warm room and keep out most of the outside air. A new shelter SHALL count after it lasts 2 seconds, and at once after a loading screen.

#### Scenario: House on a freezing night
- **WHEN** the player walks into a building on a freezing night outside the snow climate
- **THEN** the reading after 2 seconds is warmer than outside, but not as warm as an inn

#### Scenario: Building on a hot day
- **WHEN** the player walks into a building in a desert afternoon
- **THEN** the reading is cooler than outside

#### Scenario: Cave in the snow
- **WHEN** the player stands in a cave in Winterspring
- **THEN** the reading is warmer than outside, but colder than a building elsewhere with the same outside air

#### Scenario: Walking through a door
- **WHEN** the player steps in and out of a door within 2 seconds
- **THEN** the shelter does not change

### Requirement: Places with their own value
Instances and places that are fully inside, like Ironforge and the Undercity, SHALL use their own base temperature with no shelter and no inn. In volcanic places a roof SHALL keep out part of the weather, as any roof does, but none of the heat of the ground, and no building there SHALL count as an inn.

#### Scenario: Inn in Ironforge
- **WHEN** the player rests in an inn inside Ironforge
- **THEN** the reading is Ironforge's own value and the inn does not apply

#### Scenario: Building in Searing Gorge
- **WHEN** the player stands in a building in Searing Gorge
- **THEN** the heat of the ground stays as hot as outside, only part of the weather is kept out, and it is not Cozy
