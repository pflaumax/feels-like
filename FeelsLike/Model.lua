-- Pure functions of the temperature scale. No WoW API here, so tests run outside the game.

local _, ns = ...

local Model = {}
ns.Model = Model

Model.MIN = -100
Model.MAX = 100
Model.SWEEP = 270 -- degrees of the arc, centered on 12 o'clock
Model.SEGMENT_COUNT = 12

-- Ring and face start to change color past this value, in either direction.
local EXTREME_START = 70

local function rgb(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

local NEUTRAL = rgb("24323E")

-- From coldest to hottest. Every cold and hot segment has its own shade, so the ends read as a gradient.
Model.SEGMENT_COLORS = {
	rgb("2747C9"), rgb("3A78E8"), rgb("66B3F0"), rgb("A8E2F7"),
	NEUTRAL, NEUTRAL, NEUTRAL, NEUTRAL,
	rgb("F2D24B"), rgb("F5A445"), rgb("EE7135"), rgb("E0403C"),
}

-- Label words. Text colors are lighter than the segments where a segment is too dark to read.
local BANDS = {
	{ lastSegment = 2, word = "Freezing", color = rgb("6E9BFF") },
	{ lastSegment = 4, word = "Cold", color = rgb("8FD8F0") },
	{ lastSegment = 8, word = "Mild", color = rgb("C8D3DC") },
	{ lastSegment = 9, word = "Warm", color = rgb("F2D24B") },
	{ lastSegment = 11, word = "Hot", color = rgb("F5A445") },
	{ lastSegment = 12, word = "Scorching", color = rgb("FF6B6B") },
}

local COZY = { word = "Cozy", color = rgb("FFB86B") }

function Model.Clamp(t)
	if t ~= t then -- NaN, e.g. from tonumber("nan")
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

-- Degrees clockwise from 12 o'clock: -135 at MIN, 0 at comfort, +135 at MAX.
function Model.Angle(t)
	return Model.SWEEP * (Model.Fraction(t) - 0.5)
end

-- Angle in degrees clockwise from 12 o'clock. Returns x, y offsets (y up) from the center.
function Model.Polar(angle, radius)
	local rad = math.rad(angle)
	return radius * math.sin(rad), radius * math.cos(rad)
end

function Model.SegmentIndex(t)
	return math.min(Model.SEGMENT_COUNT, math.floor(Model.Fraction(t) * Model.SEGMENT_COUNT) + 1)
end

-- Returns { word, color }. Cozy (inn or campfire) wins over the temperature word.
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

-- Returns cold, hot: each 0 below EXTREME_START and 1 at the scale limit.
function Model.Extremes(t)
	t = Model.Clamp(t)
	local k = (math.abs(t) - EXTREME_START) / (Model.MAX - EXTREME_START)
	if k <= 0 then
		return 0, 0
	elseif t < 0 then
		return k, 0
	end
	return 0, k
end

-- Felt temperature. Formula and draft values: PLAN.md section 6.

-- How far the time of day moves the reading, per climate: up at the warmest hour, down at the coldest.
-- Sand deserts swing hardest: scorching afternoons, mild nights. Temperate nights go deeper than their
-- days, so a mild zone cools into the coolest Mild segment before dawn while its days stay Mild.
Model.CLIMATE_SWING = {
	desert = { day = 50, night = 50 },
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

-- Server time. The day runs from 09:00 to 21:00 and is warmest at 15:00; Forever's sky turns to night
-- at about 21:00 (seen 2026-10-21). The night cools down to the coldest hour before dawn, then warms up
-- faster.
local DAY_START = 9
local DAY_END = 21
local COLDEST_HOUR = 5

-- Shelter pulls the reading toward a room temperature; the factor is how much of the outside gets in.
-- A building is a pleasant room (hearths, people, no wind), so on a mild day it is not colder inside,
-- at night it is warmer, and in the heat it is cooler. An inn is warmer still and keeps out almost all.
local INDOOR_ROOM = 15
local INDOOR_FACTOR = 0.4
local INN_ROOM = 22
local INN_FACTOR = 0.1

-- Shelter: "outdoors", "indoors" or "inn". At a door the game reports indoors a moment before resting,
-- so a new shelter must last this long before it counts; otherwise the needle swings at every inn door.
local SHELTER_SETTLE = 2

local CAMPFIRE_WARMTH = 35
local TORCH_WARMTH = 20
-- Fire warms you up to this and no further: by a campfire on a mild day it is Warm and Cozy, not Hot.
local FIRE_CEILING = 45
-- Soaked clothes take away this share of the warmth above the bottom of the scale: in water a mild day
-- reads Cold and a snow zone Freezing, while a desert noon only cools down to Mild.
local WET_CHILL = 0.5

-- Cozy only while the result is Mild or Warm: a campfire at noon in Tanaris is not cozy.
local COZY_FIRST_SEGMENT = 5
local COZY_LAST_SEGMENT = 9

local HOT_DRY_TIME = 45 -- seconds from soaked to dry
local NORMAL_DRY_TIME = 90
local COLD_DRY_TIME = 150
local HOT_DRYING = 50 -- dry temperature at or above which clothes dry fast
local COLD_DRYING = -50
local RAIN_WETNESS = 0.4 -- rain outdoors keeps clothes at least this wet
local RAIN_SOAK_TIME = 60 -- seconds of full rain from dry to soaked

-- Fire underfoot (campfire, lava) hits about every 2 seconds while you stand in it.
local BURN_HOLD = 2.5 -- seconds at full heat after the last fire hit
local BURN_FADE = 4 -- seconds from full heat back to normal after that

-- Cozy Fire lasts 60 s, and the fire renews it while you stand near. A fresh aura means "by the fire";
-- an aging one means you walked away, so its warmth fades within seconds instead of a minute.
-- How often a fire renews it is not in the game data, so Sensors measures the gap between renewals.
local CAMPFIRE_HOLD = 4 -- seconds since the last renewal that still count as by the fire
local CAMPFIRE_RENEWAL_SLACK = 1.5 -- extra hold on top of a measured renewal gap
local CAMPFIRE_MAX_HOLD = 16
local CAMPFIRE_FADE = 4

local FIRESIDE_DRY_TIME = 15 -- seconds from soaked to dry in an inn or by a campfire (in fire: at once)

-- 1 for hold seconds, then a linear fade to 0 over fade seconds. nil seconds means never.
local function Fade(seconds, hold, fade)
	if not seconds or seconds >= hold + fade then
		return 0
	elseif seconds <= hold then
		return 1
	end
	return 1 - (seconds - hold) / fade
end

-- 1 right after fire damage, fading to 0. secondsSinceHit is nil when there was no hit.
-- Water puts you out: while swimming, only a hit within BURN_HOLD counts (that is lava, not a lake).
function Model.Burning(secondsSinceHit, swimming)
	if swimming and secondsSinceHit and secondsSinceHit > BURN_HOLD then
		return 0
	end
	return Fade(secondsSinceHit, BURN_HOLD, BURN_FADE)
end

-- 1 while you stay near the spot where you were by the fire; once you are farther away than the aura
-- reaches, fades to 0 over CAMPFIRE_FADE. secondsSinceLeft is nil while you are still near.
function Model.CampfireDistanceNearness(secondsSinceLeft)
	if not secondsSinceLeft then
		return 1
	end
	return Fade(secondsSinceLeft, 0, CAMPFIRE_FADE)
end

-- 1 while the Cozy Fire aura keeps being renewed, fading to 0 once it ages.
-- renewalGap: measured seconds between two renewals, or nil while unknown.
function Model.CampfireNearness(secondsSinceRenewal, renewalGap)
	local hold = CAMPFIRE_HOLD
	if renewalGap then
		hold = math.min(CAMPFIRE_MAX_HOLD, math.max(CAMPFIRE_HOLD, renewalGap + CAMPFIRE_RENEWAL_SLACK))
	end
	return Fade(secondsSinceRenewal, hold, CAMPFIRE_FADE)
end

-- memory: a table kept between calls. Returns the shelter to use for raw (what the game says now).
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

-- Instances and places that are inside as a whole: their value is already how it feels in there.
local function HasOwnShelter(state)
	return state.inInstance or state.inside
end
Model.HasOwnShelter = HasOwnShelter

-- An inn counts only where shelter applies.
local function InInn(state)
	return state.inn and not HasOwnShelter(state)
end

-- hour: 0..24. By day a half sine; by night a fall to the coldest hour and a shorter climb back.
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

-- state: base, climate, hour, weather (kind or nil), weatherIntensity (0..1), indoors, inn, inInstance,
-- inside (the place is inside as a whole, see Zones.lua), campfire (0..1, see Model.CampfireNearness),
-- torch (set while a lit torch lights you, see Sensors), swimming,
-- burning (0..1, see Model.Burning).
-- wetness: 0..1. Returns every step, so /feels debug can print them.
-- Instance values and places that are inside as a whole already describe how the place feels inside,
-- so shelter and inns do not apply there.
function Model.Compute(state, wetness)
	local r = {}
	r.dayNight = Model.DayNight(state.hour, state.climate)
	-- A place that is inside as a whole has no sky, so weather the game reports there does not reach you.
	local weather = not state.inside and state.weather
	r.weather = weather and (Model.WEATHER_DELTA[weather] or 0) * state.weatherIntensity or 0
	r.env = state.base + r.dayNight + r.weather

	local inn = InInn(state)
	if HasOwnShelter(state) then
		r.sheltered = r.env
	elseif inn then
		r.sheltered = INN_ROOM + (r.env - INN_ROOM) * INN_FACTOR
	elseif state.indoors then
		r.sheltered = INDOOR_ROOM + (r.env - INDOOR_ROOM) * INDOOR_FACTOR
	else
		r.sheltered = r.env
	end

	-- An inn is already warm; a lingering campfire aura must not make it hot. Water puts a torch out.
	local campfire = inn and 0 or (state.campfire or 0)
	local torch = not inn and state.torch and not state.swimming
	local room = math.max(0, FIRE_CEILING - r.sheltered)
	r.campfire = math.min(CAMPFIRE_WARMTH * campfire, room)
	r.torch = torch and math.min(TORCH_WARMTH, room - r.campfire) or 0
	r.dry = r.sheltered + r.campfire + r.torch
	r.wet = -WET_CHILL * wetness * math.max(0, r.dry - Model.MIN)
	-- Fire underfoot pulls the reading toward the hot end, whatever the zone.
	local beforeBurn = r.dry + r.wet
	r.burn = math.max(0, (Model.MAX - beforeBurn) * (state.burning or 0))
	r.felt = beforeBurn + r.burn
	r.target = Model.Clamp(r.felt)

	local segment = Model.SegmentIndex(r.target)
	local byFire = (state.campfire or 0) >= 0.5
	r.cozy = (inn or byFire) and segment >= COZY_FIRST_SEGMENT and segment <= COZY_LAST_SEGMENT or false
	return r
end

-- Returns the new wetness after dt seconds. dryTemperature is Compute().dry + Compute().burn.
function Model.UpdateWetness(wetness, dt, state, dryTemperature)
	-- Standing in fire dries you at once. It also tells lava from water: you swim in both.
	if (state.burning or 0) > 0 then
		return 0
	elseif state.swimming then
		return 1
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
