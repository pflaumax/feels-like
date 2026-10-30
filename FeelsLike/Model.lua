-- Temperature math. No WoW API here, so tests run outside the game.

local _, ns = ...

local Model = {}
ns.Model = Model

Model.MIN = -100
Model.MAX = 100
Model.SWEEP = 270 -- arc in degrees
Model.SEGMENT_COUNT = 12

-- Ring and face change color past this value.
local EXTREME_START = 70

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
	rgb("2747C9"), rgb("3A78E8"), rgb("66B3F0"), rgb("A8E2F7"),
	NEUTRAL, NEUTRAL, NEUTRAL, NEUTRAL,
	rgb("F2D24B"), rgb("F5A445"), rgb("EE7135"), rgb("E0403C"),
}

-- Label words and colors.
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

-- Returns how cold and how hot, each from 0 to 1.
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

-- Felt temperature.

-- How much the time of day changes the reading per climate.
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

-- Server time. Day is from 9 to 21 and warmest at 15.
local DAY_START = 9
local DAY_END = 21
local COLDEST_HOUR = 5

-- Shelter pulls the reading toward room temperature. The factor is how much outside air gets in.
local INDOOR_ROOM = 15
local INDOOR_FACTOR = 0.4
local INN_ROOM = 22
local INN_FACTOR = 0.1

-- A new shelter must last this long before it counts, so doors do not flicker.
local SHELTER_SETTLE = 2

local CAMPFIRE_WARMTH = 35
local TORCH_WARMTH = 20
-- A fire warms you up to this and no further.
local FIRE_CEILING = 45
-- Share of warmth that soaked clothes take away.
local WET_CHILL = 0.5

-- Cozy only when the result is Mild or Warm.
local COZY_FIRST_SEGMENT = 5
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

-- The fire renews Cozy Fire while you stand near. An old aura means you walked away.
local CAMPFIRE_HOLD = 4 -- seconds since renewal that still count as near
local CAMPFIRE_RENEWAL_SLACK = 1.5 -- extra hold on top of the measured gap
local CAMPFIRE_MAX_HOLD = 16
local CAMPFIRE_FADE = 4

local FIRESIDE_DRY_TIME = 15 -- seconds to dry in an inn or by a fire

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

-- An inn counts only where shelter applies.
local function InInn(state)
	return state.inn and not HasOwnShelter(state)
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

-- Felt temperature from the game state and wetness. Returns every step for /feels debug.
function Model.Compute(state, wetness)
	local r = {}
	r.dayNight = Model.DayNight(state.hour, state.climate)
	-- No weather in places that are fully inside.
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

	-- An inn is already warm, and water puts a torch out.
	local campfire = inn and 0 or (state.campfire or 0)
	local torch = not inn and state.torch and not state.swimming
	local room = math.max(0, FIRE_CEILING - r.sheltered)
	r.campfire = math.min(CAMPFIRE_WARMTH * campfire, room)
	r.torch = torch and math.min(TORCH_WARMTH, room - r.campfire) or 0
	r.dry = r.sheltered + r.campfire + r.torch
	r.wet = -WET_CHILL * wetness * math.max(0, r.dry - Model.MIN)
	-- Fire underfoot pulls the reading toward hot.
	local beforeBurn = r.dry + r.wet
	r.burn = math.max(0, (Model.MAX - beforeBurn) * (state.burning or 0))
	r.felt = beforeBurn + r.burn
	r.target = Model.Clamp(r.felt)

	local segment = Model.SegmentIndex(r.target)
	local byFire = (state.campfire or 0) >= 0.5
	r.cozy = (inn or byFire) and segment >= COZY_FIRST_SEGMENT and segment <= COZY_LAST_SEGMENT or false
	return r
end

-- Returns the new wetness after dt seconds.
function Model.UpdateWetness(wetness, dt, state, dryTemperature)
	-- Standing in fire dries you at once.
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
