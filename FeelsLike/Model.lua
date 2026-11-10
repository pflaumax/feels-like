-- Temperature math. No WoW API here, so tests run outside the game.

local _, ns = ...

local Model = {}
ns.Model = Model

Model.MIN = -100
Model.MAX = 100
Model.SWEEP = 270 -- arc in degrees
Model.SEGMENT_COUNT = 12

-- Ring and face change color past these values: icy in Freezing, hot where Scorching starts.
local COLD_EXTREME_START = 70
local HOT_EXTREME_START = Model.MAX - (Model.MAX - Model.MIN) / Model.SEGMENT_COUNT

local function rgb(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

local NEUTRAL = rgb("24323E")

-- Segment colors from coldest to hottest.
Model.SEGMENT_COLORS = {
	rgb("2E58DC"), rgb("3A78E8"), rgb("66B3F0"), rgb("A8E2F7"),
	NEUTRAL, NEUTRAL, NEUTRAL, NEUTRAL,
	rgb("F2D24B"), rgb("F5A445"), rgb("EE7135"), rgb("E0403C"),
}

-- Label words and colors. side is -1 for a cold word, 1 for a warm one and 0 for the middle.
local BANDS = {
	{ lastSegment = 2, word = "Freezing", side = -1, color = rgb("6E9BFF") },
	{ lastSegment = 4, word = "Cold", side = -1, color = rgb("8FD8F0") },
	{ lastSegment = 8, word = "Mild", side = 0, color = rgb("DCDCDC") },
	{ lastSegment = 9, word = "Warm", side = 1, color = rgb("F2D24B") },
	{ lastSegment = 11, word = "Hot", side = 1, color = rgb("F5A445") },
	{ lastSegment = 12, word = "Scorching", side = 1, color = rgb("FF6B6B") },
}

-- Cozy is not a step between cold and hot, so its color is none of theirs.
local COZY = { word = "Cozy", color = rgb("7EDC9E") }

function Model.Clamp(t)
	if t ~= t then -- NaN
		return 0
	elseif t < Model.MIN then
		return Model.MIN
	elseif t > Model.MAX then
		return Model.MAX
	end
	return t
end

-- 0 at MIN, 1 at MAX.
function Model.Fraction(t)
	return (Model.Clamp(t) - Model.MIN) / (Model.MAX - Model.MIN)
end

-- Degrees from 12 o'clock, -135 at MIN and +135 at MAX.
function Model.Angle(t)
	return Model.SWEEP * (Model.Fraction(t) - 0.5)
end

-- Returns x and y offsets for an angle.
function Model.Polar(angle, radius)
	local rad = math.rad(angle)
	return radius * math.sin(rad), radius * math.cos(rad)
end

function Model.SegmentIndex(t)
	return math.min(Model.SEGMENT_COUNT, math.floor(Model.Fraction(t) * Model.SEGMENT_COUNT) + 1)
end

-- Returns the label word and color. Cozy wins.
function Model.Band(t, cozy)
	if cozy then
		return COZY
	end
	local index = Model.SegmentIndex(t)
	for _, band in ipairs(BANDS) do
		if index <= band.lastSegment then
			return band
		end
	end
end

-- The needle moves like one on a spring: it speeds up, swings a little past the reading and comes back.
local NEEDLE_FREQUENCY = 8 -- how fast it swings, in radians per second
local NEEDLE_DAMPING = 0.65 -- below 1 it swings past: about 7 percent of the way here

-- Where the needle is and how fast it moves after dt seconds on its way to aim. The answer is exact for any
-- dt, so the needle moves the same at any frame rate.
function Model.NeedleStep(position, velocity, aim, dt)
	local decay = NEEDLE_DAMPING * NEEDLE_FREQUENCY
	local swing = NEEDLE_FREQUENCY * math.sqrt(1 - NEEDLE_DAMPING * NEEDLE_DAMPING)
	local a = position - aim
	local b = (velocity + decay * a) / swing
	local fade = math.exp(-decay * dt)
	local cos, sin = math.cos(swing * dt), math.sin(swing * dt)
	return aim + fade * (a * cos + b * sin),
		fade * ((b * swing - decay * a) * cos - (a * swing + decay * b) * sin)
end

-- Returns how cold and how hot, each from 0 to 1.
function Model.Extremes(t)
	t = Model.Clamp(t)
	local start = t < 0 and COLD_EXTREME_START or HOT_EXTREME_START
	local k = (math.abs(t) - start) / (Model.MAX - start)
	if k <= 0 then
		return 0, 0
	elseif t < 0 then
		return k, 0
	end
	return 0, k
end

-- Felt temperature.

-- How much the time of day changes the reading per climate. A desert afternoon stays below the top of the scale.
Model.CLIMATE_SWING = {
	desert = { day = 40, night = 50 },
	arid = { day = 30, night = 30 },
	temperate = { day = 10, night = 30 },
	snow = { day = 8, night = 8 },
	tropical = { day = 6, night = 6 },
	volcanic = { day = 0, night = 0 },
	none = { day = 0, night = 0 },
}

-- At full intensity.
Model.WEATHER_DELTA = {
	rain = -12,
	snow = -20,
	sandstorm = 10,
}

-- Seasons and holidays by the server's calendar: a small step on the air of places under the sky.
local SEASON_STEP = 5
local HOLIDAY_STEP = 8
local SEASONAL = { desert = true, arid = true, temperate = true, snow = true, tropical = true }

-- Returns the step and the name of the season or the holiday, or 0 and nil.
function Model.Season(month, day)
	if not month or not day then
		return 0, nil
	elseif (month == 12 and day >= 16) or (month == 1 and day <= 2) then
		return -HOLIDAY_STEP, "Winter Veil"
	elseif (month == 6 and day >= 21) or (month == 7 and day <= 5) then
		return HOLIDAY_STEP, "Midsummer"
	elseif month == 12 or month <= 2 then
		return -SEASON_STEP, "winter"
	elseif month >= 6 and month <= 8 then
		return SEASON_STEP, "summer"
	end
	return 0, nil
end

-- Humid air feels hotter: above the start it adds a share of the heat over it.
local HUMID = { tropical = true }
local HUMID_START = 20
local HUMID_SHARE = 0.25

-- Server time. Day is from 9 to 21 and warmest at 15.
local DAY_START = 9
local DAY_END = 21
local COLDEST_HOUR = 5

-- Shelter pulls the reading toward room temperature. The factor is how much outside air gets in.
local INDOOR_ROOM = 15
local INDOOR_FACTOR = 0.4
-- In the snow a cave or an unheated house is only a windbreak: colder inside, and more of the cold gets in.
local SNOW_INDOOR_ROOM = 0
local SNOW_INDOOR_FACTOR = 0.6
local INN_ROOM = 22
local INN_FACTOR = 0.1

-- A new shelter must last this long before it counts, so doors do not flicker.
local SHELTER_SETTLE = 2

local CAMPFIRE_WARMTH = 35
local TORCH_WARMTH = 20
-- A fire warms you up to this and no further.
local FIRE_CEILING = 45
-- A torch warms a cold body only up to this: no torch makes a mild day warm.
local TORCH_CEILING = 20
-- No air is as hot as fire. Only fire underfoot takes the reading above this.
local AIR_CEILING = 95
-- Share of warmth that soaked clothes take away.
local WET_CHILL = 0.5

-- Cozy only when the result is Mild or Warm, and not close to Cold.
local COZY_MIN = -25
local COZY_LAST_SEGMENT = 9

local HOT_DRY_TIME = 45 -- seconds from soaked to dry
local NORMAL_DRY_TIME = 90
local COLD_DRY_TIME = 150
local HOT_DRYING = 50 -- clothes dry fast from this temperature
local COLD_DRYING = -50
local RAIN_WETNESS = 0.4 -- rain keeps clothes at least this wet
local RAIN_SOAK_TIME = 60 -- seconds of rain from dry to soaked

-- Fire underfoot hits about every 2 seconds.
local BURN_HOLD = 2.5 -- seconds at full heat after the last hit
local BURN_FADE = 4 -- seconds to fade back to normal
-- A fire spell in a fight burns a body that feels it for a moment.
local FIRE_SPELL_HOLD = 1
local FIRE_SPELL_FADE = 3

-- A frost spell chills any body for a moment, toward this. Freezing, with the icy ring.
local FROST_FEEL = -85
local FROST_SPELL_HOLD = 1
local FROST_SPELL_FADE = 3

-- A drink warms a cold body: tipsy, drunk, completely smashed.
local DRINK_WARMTH = { 10, 20, 30 }
-- A fight warms you: the body works hard. The warmth builds over the first seconds of a fight and fades
-- when it is over. Like a fire, it makes you warm but never hot.
local FIGHT_WARMTH = 12
local FIGHT_RISE = 8 -- seconds of fighting to the full warmth
local FIGHT_FADE = 30 -- seconds to cool down after the fight

-- The fire renews Cozy Fire while you stand near. An old aura means you walked away.
local CAMPFIRE_HOLD = 4 -- seconds since renewal that still count as near
local CAMPFIRE_RENEWAL_SLACK = 1.5 -- extra hold on top of the measured gap
local CAMPFIRE_MAX_HOLD = 16
local CAMPFIRE_FADE = 4

local FIRESIDE_DRY_TIME = 15 -- seconds to dry in an inn or by a fire

-- The dead feel this cold everywhere, the same until they are back. Cold, just short of Freezing.
Model.DEAD_FEEL = -65

-- 1 for hold seconds, then fades to 0 over fade seconds.
local function Fade(seconds, hold, fade)
	if not seconds or seconds >= hold + fade then
		return 0
	elseif seconds <= hold then
		return 1
	end
	return 1 - (seconds - hold) / fade
end

-- 1 right after fire damage, then fades to 0.
function Model.Burning(secondsSinceHit, swimming)
	if swimming and secondsSinceHit and secondsSinceHit > BURN_HOLD then
		return 0
	end
	return Fade(secondsSinceHit, BURN_HOLD, BURN_FADE)
end

-- 1 right after a fire spell hit, then fades to 0.
function Model.FireSpellBurning(secondsSinceHit)
	return Fade(secondsSinceHit, FIRE_SPELL_HOLD, FIRE_SPELL_FADE)
end

-- 1 right after a frost spell hit, then fades to 0.
function Model.FrostSpellChill(secondsSinceHit)
	return Fade(secondsSinceHit, FROST_SPELL_HOLD, FROST_SPELL_FADE)
end

-- 1 near the spot by the fire, then fades to 0 when you walk away.
function Model.CampfireDistanceNearness(secondsSinceLeft)
	if not secondsSinceLeft then
		return 1
	end
	return Fade(secondsSinceLeft, 0, CAMPFIRE_FADE)
end

-- 1 while the Cozy Fire aura keeps renewing, then fades to 0.
function Model.CampfireNearness(secondsSinceRenewal, renewalGap)
	local hold = CAMPFIRE_HOLD
	if renewalGap then
		hold = math.min(CAMPFIRE_MAX_HOLD, math.max(CAMPFIRE_HOLD, renewalGap + CAMPFIRE_RENEWAL_SLACK))
	end
	return Fade(secondsSinceRenewal, hold, CAMPFIRE_FADE)
end

-- Returns the shelter to use. memory is kept between calls.
function Model.SettleShelter(memory, raw, now)
	if memory.current == nil or raw == memory.current then
		memory.current, memory.pending, memory.since = raw, nil, nil
	elseif raw ~= memory.pending then
		memory.pending, memory.since = raw, now
	elseif now - memory.since >= SHELTER_SETTLE then
		memory.current, memory.pending, memory.since = raw, nil, nil
	end
	return memory.current
end

-- Instances and fully inside places already have their own value.
local function HasOwnShelter(state)
	return state.inInstance or state.inside
end
Model.HasOwnShelter = HasOwnShelter

-- Heat that comes from the ground. A roof keeps the weather out there, but none of the heat, and no inn is cozy.
local GROUND_HEAT = { volcanic = true }

-- True where the ground is hot. Lava is expected there.
function Model.HasGroundHeat(climate)
	return GROUND_HEAT[climate] == true
end

-- An inn counts only where shelter applies.
local function InInn(state)
	return state.inn and not HasOwnShelter(state) and not GROUND_HEAT[state.climate]
end

-- hour is from 0 to 24.
function Model.DayNight(hour, climate)
	local swing = Model.CLIMATE_SWING[climate]
	if not swing then
		return 0
	end
	local dayLength = DAY_END - DAY_START
	local sinceDayStart = (hour - DAY_START) % 24
	if sinceDayStart < dayLength then
		return swing.day * math.sin(math.pi * sinceDayStart / dayLength)
	end
	local sinceDusk = sinceDayStart - dayLength
	local nightLength = 24 - dayLength
	local fall = (COLDEST_HOUR - DAY_END) % 24
	local depth
	if sinceDusk < fall then
		depth = math.sin(math.pi / 2 * sinceDusk / fall)
	else
		depth = math.sin(math.pi / 2 * (nightLength - sinceDusk) / (nightLength - fall))
	end
	return -swing.night * depth
end

-- Scales the distance from Mild by the body's cold or heat factor. No body is like a human.
function Model.BodyFeel(t, body)
	if not body then
		return t
	end
	return t * (t < 0 and body.cold or body.heat)
end

-- Returns the room temperature and the share of outside air that gets in.
local function Shelter(state)
	if HasOwnShelter(state) then
		return 0, 1
	elseif InInn(state) then
		return INN_ROOM, INN_FACTOR
	elseif state.indoors then
		if state.climate == "snow" then
			return SNOW_INDOOR_ROOM, SNOW_INDOOR_FACTOR
		end
		return INDOOR_ROOM, INDOOR_FACTOR
	end
	return 0, 1
end

-- Felt temperature from the game state and wetness. Returns every step for /feels debug.
function Model.Compute(state, wetness)
	local r = {}
	r.dayNight = Model.DayNight(state.hour, state.climate)
	-- No weather in places that are fully inside.
	local weather = not state.inside and state.weather
	r.weather = weather and (Model.WEATHER_DELTA[weather] or 0) * state.weatherIntensity or 0
	-- No season in places that are fully inside or that have no sky of their own.
	r.season, r.seasonName = 0, nil
	if SEASONAL[state.climate] and not state.inside and not state.seasonsOff then
		r.season, r.seasonName = Model.Season(state.month, state.day)
	end
	local air = state.base + r.dayNight + r.weather + r.season
	r.humid = HUMID[state.climate] and math.max(0, air - HUMID_START) * HUMID_SHARE or 0
	r.env = air + r.humid

	local inn = InInn(state) or false
	r.inn = inn
	local roomTemperature, outsideAir = Shelter(state)
	r.outsideAir = outsideAir
	-- Under a roof on hot ground only the weather stays outside.
	r.groundHeat = GROUND_HEAT[state.climate] and outsideAir < 1 or false
	if r.groundHeat then
		r.sheltered = r.env - r.weather * (1 - outsideAir)
	else
		r.sheltered = roomTemperature + (r.env - roomTemperature) * outsideAir
	end

	-- An inn is already warm. In the water a campfire warms nothing and a torch goes out.
	local campfire = (inn or state.swimming) and 0 or (state.campfire or 0)
	local torch = not inn and state.torch and not state.swimming
	local room = math.max(0, FIRE_CEILING - r.sheltered)
	r.campfire = math.min(CAMPFIRE_WARMTH * campfire, room)
	r.torch = torch and math.min(TORCH_WARMTH, math.max(0, TORCH_CEILING - r.sheltered - r.campfire)) or 0
	r.dry = r.sheltered + r.campfire + r.torch
	-- Humid air feels hotter, but it dries nothing.
	r.drying = r.dry - r.humid * outsideAir
	-- Hot water chills nothing while you swim in it. Wet clothes chill again on the shore.
	local chill = state.swimming and state.hotWater and 0 or WET_CHILL * wetness
	r.wet = 0 - chill * math.max(0, r.dry - Model.MIN) -- no negative zero in /feels debug
	-- The body feels the cold and the heat by race. Fire underfoot burns everyone alike.
	local unscaled = r.dry + r.wet
	local scaled = Model.BodyFeel(unscaled, state.body)
	-- A fire warms no body past the ceiling, and it never cools a body that is hotter without it.
	if r.campfire + r.torch > 0 then
		local withoutFire = r.sheltered - chill * math.max(0, r.sheltered - Model.MIN)
		scaled = math.min(scaled, math.max(FIRE_CEILING, Model.BodyFeel(withoutFire, state.body)))
	end
	r.race = scaled - unscaled
	-- A drink warms only a cold body, and never past the middle of Mild.
	r.drink = math.min(DRINK_WARMTH[state.drunk] or 0, math.max(0, -scaled))
	-- A fight warms every body alike, but no further than a fire does: Cozy by a fire stays Cozy.
	r.fight = math.min(FIGHT_WARMTH * (state.exertion or 0), math.max(0, FIRE_CEILING - scaled - r.drink))
	-- Fire underfoot pulls the reading toward hot. Fire spells in a fight burn only a body that feels them.
	local beforeFrost = math.min(scaled + r.drink + r.fight, AIR_CEILING)
	-- A frost spell pulls the reading toward the cold for a moment, the same for every body.
	r.frost = math.min(0, (FROST_FEEL - beforeFrost) * (state.frostSpell or 0))
	local beforeBurn = beforeFrost + r.frost
	local fireSpell = state.body and state.body.fireSpells and state.fireSpell or 0
	r.burning = math.max(state.burning or 0, fireSpell)
	r.burn = math.max(0, (Model.MAX - beforeBurn) * r.burning)
	r.felt = beforeBurn + r.burn
	r.target = Model.Clamp(r.felt)
	-- Held at the air ceiling, for /feels debug. Not while fire lifts the reading over it.
	r.capped = scaled + r.drink > AIR_CEILING and r.burn == 0 and r.frost == 0

	-- A ghost or a wisp feels nothing of the place.
	if state.dead then
		r.felt, r.target, r.cozy, r.capped = Model.DEAD_FEEL, Model.DEAD_FEEL, false, false
		return r
	end

	local byFire = (state.campfire or 0) >= 0.5
	-- No one is cozy in the water.
	r.cozy = (inn or byFire) and not state.swimming and r.target >= COZY_MIN
		and Model.SegmentIndex(r.target) <= COZY_LAST_SEGMENT or false
	return r
end

-- Returns how warm the fight has made you after dt seconds, from 0 to 1.
function Model.UpdateExertion(exertion, dt, fighting)
	if fighting then
		return math.min(1, exertion + dt / FIGHT_RISE)
	end
	return math.max(0, exertion - dt / FIGHT_FADE)
end

-- Returns the new wetness after dt seconds.
function Model.UpdateWetness(wetness, dt, state, dryTemperature)
	-- Standing in fire dries you at once.
	if (state.burning or 0) > 0 then
		return 0
	elseif state.swimming then
		-- Lava soaks nothing, and a fire hit in the water may be lava.
		return state.maybeLava and wetness or 1
	end

	local raining = state.weather == "rain" and not (state.indoors or state.inside)
	local floor = raining and RAIN_WETNESS * state.weatherIntensity or 0
	if wetness < floor then
		return math.min(floor, wetness + dt / RAIN_SOAK_TIME)
	end

	local dryTime = NORMAL_DRY_TIME
	if InInn(state) or (state.campfire or 0) >= 0.5 then
		dryTime = FIRESIDE_DRY_TIME
	elseif dryTemperature >= HOT_DRYING then
		dryTime = HOT_DRY_TIME
	elseif dryTemperature <= COLD_DRYING then
		dryTime = COLD_DRY_TIME
	end
	return math.max(floor, wetness - dt / dryTime)
end

-- A step smaller than this is not worth a word in the tooltip.
local REASON_MIN = 3
-- The tooltip names this many reasons.
local REASON_COUNT = 3
-- A place past this base is cold or hot, a place inside it only cool or warm.
local STRONG_PLACE = 34

local function PlaceWord(base)
	if base < 0 then
		return base <= -STRONG_PLACE and "a cold place" or "a cool place"
	end
	return base >= STRONG_PLACE and "a hot place" or "a warm place"
end

-- Every word Model.Reasons can give, without the body words that Core adds, for the language tests.
Model.REASON_WORDS = {
	"a cold place", "a cool place", "a warm place", "a hot place", "the night", "the sun", "rain", "snow",
	"a sandstorm", "the weather", "winter", "summer", "Winter Veil", "Midsummer", "the season", "humid air",
	"the inn", "a roof", "a campfire", "a torch", "the water", "wet clothes", "your body", "a drink",
	"a fight", "a frost spell", "fire", "death",
}

-- Why the reading has its word right now, strongest first, in plain words. Returns the reasons that make it
-- colder and the ones that make it warmer, for one line in the tooltip. A cold word names only what makes it
-- cold and a warm word only what makes it warm, so the line never argues with the word. Mild names both.
-- Cozy names its fire or its inn. state.bodyWord names the body, like "your fur".
function Model.Reasons(state, r)
	if state.dead then
		return { "death" }, {}
	elseif r.cozy then
		return {}, { r.inn and "the inn" or "a campfire" }
	end
	-- Under a roof the sun and the weather do not reach you. Only the air they warm or chill gets in.
	local roofed = (r.outsideAir or 1) < 1
	local steps = {
		{ state.base, PlaceWord(state.base) },
		{ r.dayNight, r.dayNight < 0 and "the night" or not roofed and "the sun" },
		{ r.weather, not roofed and (state.weather == "sandstorm" and "a sandstorm" or state.weather or "the weather") },
		{ r.season, r.seasonName or "the season" },
		{ r.humid, "humid air" },
		{ r.sheltered - r.env, r.inn and "the inn" or "a roof" },
		{ r.campfire, "a campfire" },
		{ r.torch, "a torch" },
		{ r.wet, state.swimming and "the water" or "wet clothes" },
		{ r.race, state.bodyWord or "your body" },
		{ r.drink, "a drink" },
		{ r.fight, "a fight" },
		{ r.frost, "a frost spell" },
		{ r.burn, "fire" },
	}
	table.sort(steps, function(a, b)
		return math.abs(a[1]) > math.abs(b[1])
	end)
	local side = Model.Band(r.target, false).side
	local colder, warmer = {}, {}
	for _, step in ipairs(steps) do
		local value, word = step[1], step[2]
		local fits = side == 0 or (value < 0) == (side < 0)
		if word and fits and math.abs(value) >= REASON_MIN and #colder + #warmer < REASON_COUNT then
			local list = value < 0 and colder or warmer
			list[#list + 1] = word
		end
	end
	return colder, warmer
end
