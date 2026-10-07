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

-- Half of the day/night difference, per climate. Sand deserts swing hardest: scorching afternoons, mild nights.
Model.CLIMATE_SWING = {
	desert = 50,
	arid = 30,
	temperate = 10,
	snow = 8,
	tropical = 6,
	volcanic = 0,
	none = 0,
}

-- At full intensity.
Model.WEATHER_DELTA = {
	rain = -12,
	snow = -20,
	sandstorm = 10,
}

local PEAK_HOUR = 15 -- warmest hour; the coldest is 12 hours later

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
local WET_CHILL = 30 -- at fully soaked clothes

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

function Model.DayNight(hour, climate)
	local swing = Model.CLIMATE_SWING[climate] or 0
	return swing * math.cos(2 * math.pi * (hour - PEAK_HOUR) / 24)
end

-- state: base, climate, hour, weather (kind or nil), weatherIntensity (0..1), indoors, inn, inInstance,
-- campfire (0..1, see Model.CampfireNearness), burning (0..1, see Model.Burning).
-- wetness: 0..1. Returns every step, so /feels debug can print them.
-- Instance values already describe how the place feels inside, so shelter does not apply there.
function Model.Compute(state, wetness)
	local r = {}
	r.dayNight = Model.DayNight(state.hour, state.climate)
	r.weather = state.weather and (Model.WEATHER_DELTA[state.weather] or 0) * state.weatherIntensity or 0
	r.env = state.base + r.dayNight + r.weather

	if state.inInstance then
		r.sheltered = r.env
	elseif state.inn then
		r.sheltered = INN_ROOM + (r.env - INN_ROOM) * INN_FACTOR
	elseif state.indoors then
		r.sheltered = INDOOR_ROOM + (r.env - INDOOR_ROOM) * INDOOR_FACTOR
	else
		r.sheltered = r.env
	end

	-- An inn is already warm; a lingering campfire aura must not make it hot.
	local campfire = state.inn and 0 or (state.campfire or 0)
	r.campfire = CAMPFIRE_WARMTH * campfire
	r.dry = r.sheltered + r.campfire
	r.wet = -WET_CHILL * wetness
	-- Fire underfoot pulls the reading toward the hot end, whatever the zone.
	local beforeBurn = r.dry + r.wet
	r.burn = math.max(0, (Model.MAX - beforeBurn) * (state.burning or 0))
	r.felt = beforeBurn + r.burn
	r.target = Model.Clamp(r.felt)

	local segment = Model.SegmentIndex(r.target)
	local byFire = (state.campfire or 0) >= 0.5
	r.cozy = (state.inn or byFire) and segment >= COZY_FIRST_SEGMENT and segment <= COZY_LAST_SEGMENT or false
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

	local raining = state.weather == "rain" and not state.indoors
	local floor = raining and RAIN_WETNESS * state.weatherIntensity or 0
	if wetness < floor then
		return math.min(floor, wetness + dt / RAIN_SOAK_TIME)
	end

	local dryTime = NORMAL_DRY_TIME
	if state.inn or (state.campfire or 0) >= 0.5 then
		dryTime = FIRESIDE_DRY_TIME
	elseif dryTemperature >= HOT_DRYING then
		dryTime = HOT_DRY_TIME
	elseif dryTemperature <= COLD_DRYING then
		dryTime = COLD_DRY_TIME
	end
	return math.max(floor, wetness - dt / dryTime)
end
