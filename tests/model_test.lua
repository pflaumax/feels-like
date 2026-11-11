-- Run with luajit tests/model_test.lua

local ns = {}
assert(loadfile("FeelsLike/Model.lua"))("FeelsLike", ns)
local Model = ns.Model

local failures = 0

local function check(name, actual, expected)
	if actual ~= expected then
		failures = failures + 1
		print(string.format("FAIL %s: expected %s, got %s", name, tostring(expected), tostring(actual)))
	end
end

local function near(name, actual, expected)
	if math.abs(actual - expected) > 1e-9 then
		failures = failures + 1
		print(string.format("FAIL %s: expected %s, got %s", name, tostring(expected), tostring(actual)))
	end
end

-- Clamp
check("clamp nan", Model.Clamp(0 / 0), 0)
check("clamp low", Model.Clamp(-500), -100)
check("clamp high", Model.Clamp(500), 100)
check("clamp inside", Model.Clamp(12), 12)

-- Angle
near("angle min", Model.Angle(-100), -135)
near("angle zero", Model.Angle(0), 0)
near("angle max", Model.Angle(100), 135)
near("angle clamped", Model.Angle(1000), 135)
near("angle half hot", Model.Angle(50), 67.5)

-- Segments
check("segment min", Model.SegmentIndex(-100), 1)
check("segment max", Model.SegmentIndex(100), 12)
check("segment zero", Model.SegmentIndex(0), 7)
check("segment colors", #Model.SEGMENT_COLORS, Model.SEGMENT_COUNT)

-- Band words
local bands = {
	{ -100, "Freezing" }, { -67, "Freezing" }, { -66, "Cold" }, { -34, "Cold" },
	{ -33, "Mild" }, { 0, "Mild" }, { 33, "Mild" }, { 34, "Warm" },
	{ 49, "Warm" }, { 50, "Hot" }, { 83, "Hot" }, { 84, "Scorching" }, { 100, "Scorching" },
}
for _, case in ipairs(bands) do
	check("band " .. case[1], Model.Band(case[1]).word, case[2])
end
check("cozy wins", Model.Band(-100, true).word, "Cozy")
check("not cozy", Model.Band(0, false).word, "Mild")

-- Extremes
local cold, hot = Model.Extremes(0)
check("extreme zero cold", cold, 0)
check("extreme zero hot", hot, 0)
cold, hot = Model.Extremes(70)
check("extreme start", hot, 0)
-- The hot glow starts with Scorching, the icy ring in Freezing.
check("hot is not extreme yet", select(2, Model.Extremes(83)), 0)
check("scorching starts the glow", select(2, Model.Extremes(84)) > 0, true)
near("extreme half hot", select(2, Model.Extremes(100 - 100 / 12)), 0.5)
check("cold is not extreme yet", (Model.Extremes(-70)), 0)
cold, hot = Model.Extremes(-85)
near("extreme half cold", cold, 0.5)
check("extreme half cold hot", hot, 0)
cold, hot = Model.Extremes(100)
check("extreme max hot", hot, 1)
check("extreme max cold", cold, 0)
cold, hot = Model.Extremes(-1000)
check("extreme clamped cold", cold, 1)

-- Day and night
near("day peak desert", Model.DayNight(15, "desert"), 40)
near("a desert afternoon stays below fire", Model.Compute({ base = 55, climate = "desert", hour = 15, weatherIntensity = 0 }, 0).target, 95)
near("night low desert", Model.DayNight(5, "desert"), -50)
near("day peak arid", Model.DayNight(15, "arid"), 30)
near("dusk desert", Model.DayNight(21, "desert"), 0)
near("dawn desert", Model.DayNight(9, "desert"), 0)
near("morning is a half sine", Model.DayNight(12, "temperate"), 10 * math.sin(math.pi / 4))
near("temperate day peak", Model.DayNight(15, "temperate"), 10)
near("temperate night goes deeper", Model.DayNight(5, "temperate"), -30)
near("night falls over 8 hours", Model.DayNight(1, "temperate"), -30 * math.sin(math.pi / 4))
near("midnight", Model.DayNight(0, "temperate"), -30 * math.sin(math.pi * 3 / 16))
near("morning climbs over 4 hours", Model.DayNight(7, "temperate"), -30 * math.sin(math.pi / 4))
near("hour 24 is midnight", Model.DayNight(24, "temperate"), Model.DayNight(0, "temperate"))
near("volcanic flat", Model.DayNight(5, "volcanic"), 0)
near("unknown climate flat", Model.DayNight(5, "nope"), 0)
-- Mild zone before dawn
check("mild zone night word", Model.Band(10 + Model.DayNight(5, "temperate")).word, "Mild")
check("mild zone night segment", Model.SegmentIndex(10 + Model.DayNight(5, "temperate")), 5)

-- Seasons and holidays
local function season(month, day)
	local step, name = Model.Season(month, day)
	return step .. " " .. tostring(name)
end
check("no calendar, no season", season(nil, nil), "0 nil")
check("spring has no step", season(4, 10), "0 nil")
check("autumn has no step", season(11, 10), "0 nil")
check("winter", season(1, 20), "-5 winter")
check("early december is winter", season(12, 15), "-5 winter")
check("winter veil starts", season(12, 16), "-8 Winter Veil")
check("winter veil over the new year", season(1, 2), "-8 Winter Veil")
check("winter veil is over", season(1, 3), "-5 winter")
check("summer", season(8, 1), "5 summer")
check("midsummer starts", season(6, 21), "8 Midsummer")
check("midsummer ends", season(7, 5), "8 Midsummer")
check("midsummer is over", season(7, 6), "5 summer")

-- Compute
local base = { base = 0, climate = "none", hour = 0, weather = nil, weatherIntensity = 0 }
local function state(fields)
	local s = {}
	for k, v in pairs(base) do s[k] = v end
	for k, v in pairs(fields) do s[k] = v end
	return s
end
-- The season moves the air of places under the sky.
near("winter in elwynn", Model.Compute(state({ base = 5, climate = "temperate", hour = 15, month = 1, day = 20 }), 0).target, 10)
near("winter veil in elwynn", Model.Compute(state({ base = 5, climate = "temperate", hour = 15, month = 12, day = 24 }), 0).target, 7)
near("midsummer in tanaris stays below fire", Model.Compute(state({ base = 55, climate = "desert", hour = 15, month = 6, day = 25 }), 0).target, 95)
near("summer night in tanaris", Model.Compute(state({ base = 55, climate = "desert", hour = 5, month = 8, day = 1 }), 0).target, 10)
near("no season in a volcanic place", Model.Compute(state({ base = 85, climate = "volcanic", month = 1, day = 20 }), 0).season, 0)
near("no season in a place with no sky", Model.Compute(state({ base = -30, climate = "none", month = 1, day = 20 }), 0).season, 0)
near("no season in ironforge", Model.Compute(state({ base = 25, climate = "temperate", inside = true, month = 1, day = 20 }), 0).season, 0)
near("no season with the setting off", Model.Compute(state({ base = 5, climate = "temperate", month = 1, day = 20, seasonsOff = true }), 0).season, 0)
near("no season without a calendar", Model.Compute(state({ base = 5, climate = "temperate" }), 0).season, 0)
check("the season has a name", Model.Compute(state({ base = 5, climate = "temperate", month = 12, day = 24 }), 0).seasonName, "Winter Veil")
-- Shelter
near("indoors in the heat is cooler", Model.Compute(state({ base = 75, indoors = true }), 0).target, 39)
near("indoors on a mild day is the same", Model.Compute(state({ base = 15, indoors = true }), 0).target, 15)
near("indoors at night is warmer", Model.Compute(state({ base = -5, indoors = true }), 0).target, 7)
near("inn", Model.Compute(state({ base = 75, indoors = true, inn = true }), 0).target, 27.3)
near("inn on a mild day is warmer", Model.Compute(state({ base = 15, indoors = true, inn = true }), 0).target, 21.3)
near("instance ignores shelter", Model.Compute(state({ base = 90, indoors = true, inInstance = true }), 0).target, 90)
near("a roof keeps no volcanic heat out", Model.Compute(state({ base = 90, climate = "volcanic", indoors = true }), 0).target, 90)
near("a volcanic rest area is no cooler", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true, inn = true }), 0).target, 85)
check("a volcanic rest area is not cozy", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true, inn = true }), 0).cozy, false)
-- A volcanic rest building is no inn: not cozy when wet clothes cool you, no fast drying, a campfire counts.
check("a volcanic rest area is no inn", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true, inn = true }), 0.5).inn, false)
check("soaked in a volcanic rest area is not cozy", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true, inn = true }), 0.5).cozy, false)
near("a volcanic rest area dries at the hot pace", Model.UpdateWetness(1, 9, state({ climate = "volcanic", indoors = true, inn = true }), 85), 0.8)
-- A roof on hot ground still keeps the weather out.
near("rain under a volcanic roof", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true, weather = "rain", weatherIntensity = 1 }), 0).target, 80.2)
near("rain on volcanic ground outdoors", Model.Compute(state({ base = 85, climate = "volcanic", weather = "rain", weatherIntensity = 1 }), 0).target, 73)
check("volcanic ground is hot", Model.HasGroundHeat("volcanic"), true)
check("desert ground is not", Model.HasGroundHeat("desert"), false)
check("an unknown climate has no hot ground", Model.HasGroundHeat(nil), false)
check("ground heat is reported under a roof", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true }), 0).groundHeat, true)
check("no ground heat report outdoors", Model.Compute(state({ base = 85, climate = "volcanic" }), 0).groundHeat, false)
check("no ground heat report in a volcanic instance", Model.Compute(state({ base = 85, climate = "volcanic", indoors = true, inInstance = true }), 0).groundHeat, false)
-- In the snow a cave is only a windbreak, an inn is still an inn.
near("a cave in winterspring at night is cold", Model.Compute(state({ base = -80, climate = "snow", hour = 5, indoors = true }), 0).target, -52.8)
check("a cave in winterspring at night reads cold", Model.Band(Model.Compute(state({ base = -80, climate = "snow", hour = 5, indoors = true }), 0).target).word, "Cold")
near("a cave in dun morogh at night", Model.Compute(state({ base = -60, climate = "snow", hour = 5, indoors = true }), 0).target, -40.8)
near("an inn in the snow is as warm as before", Model.Compute(state({ base = -80, climate = "snow", hour = 5, indoors = true, inn = true }), 0).target, 11)
near("a house in a temperate night is as before", Model.Compute(state({ base = 5, climate = "temperate", hour = 5, indoors = true }), 0).target, -1)
near("a roof still cools desert heat", Model.Compute(state({ base = 55, climate = "desert", hour = 15, indoors = true }), 0).target, 47)
near("inside place ignores the inn", Model.Compute(state({ base = -20, indoors = true, inn = true, inside = true }), 0).target, -20)
check("inside place is not cozy", Model.Compute(state({ base = -20, indoors = true, inn = true, inside = true }), 0).cozy, false)
near("inside place keeps campfire", Model.Compute(state({ base = -20, indoors = true, inn = true, inside = true, campfire = 1 }), 0).target, 15)
near("no weather inside a place", Model.Compute(state({ base = -20, inside = true, weather = "snow", weatherIntensity = 1 }), 0).target, -20)
near("no rain soaks inside a place", Model.UpdateWetness(0, 60, state({ inside = true, weather = "rain", weatherIntensity = 1 }), 0), 0)
near("campfire", Model.Compute(state({ base = -60, campfire = 1 }), 0).target, -25)
-- Fire
near("campfire stops at warm", Model.Compute(state({ base = 20, campfire = 1 }), 0).target, 45)
check("campfire on a mild day is cozy", Model.Compute(state({ base = 20, campfire = 1 }), 0).cozy, true)
near("campfire does not cool", Model.Compute(state({ base = 90, campfire = 1 }), 0).target, 90)
-- Torch
near("torch", Model.Compute(state({ base = -60, torch = true }), 0).target, -40)
near("a torch adds nothing by a warm fire", Model.Compute(state({ base = 0, campfire = 1, torch = true }), 0).target, 35)
-- A torch warms a cold body, but it makes no mild day warm.
near("torch on a mild day stops at its ceiling", Model.Compute(state({ base = 15, torch = true }), 0).target, 20)
near("torch on a warm day adds nothing", Model.Compute(state({ base = 30, torch = true }), 0).target, 30)
near("torch on a cold night gives all its warmth", Model.Compute(state({ base = -25, torch = true }), 0).target, -5)
near("torch next to a campfire", Model.Compute(state({ base = -60, campfire = 1, torch = true }), 0).target, -5)
check("torch is not cozy", Model.Compute(state({ base = 0, torch = true }), 0).cozy, false)
near("torch in an inn", Model.Compute(state({ base = 5, indoors = true, inn = true, torch = true }), 0).target, 20.3)
near("torch in water", Model.Compute(state({ base = 0, torch = true, swimming = true }), 1).target, -50)
-- Wet clothes
near("wet", Model.Compute(state({ base = 0 }), 0.5).target, -25)
check("soaked on a mild day is cold", Model.Band(Model.Compute(state({ base = 20 }), 1).target).word, "Cold")
check("soaked on a mild night is cold", Model.Band(Model.Compute(state({ base = -25 }), 1).target).word, "Cold")
check("soaked in the snow is freezing", Model.Band(Model.Compute(state({ base = -60 }), 1).target).word, "Freezing")
near("soaked at a desert noon", Model.Compute(state({ base = 100 }), 1).target, 0)
near("no wet chill below the scale", Model.Compute(state({ base = -110 }), 1).wet, 0)
-- Hot springs
near("a swim in a hot spring chills nothing", Model.Compute(state({ base = 18, swimming = true, hotWater = true }), 1).target, 18)
near("wet clothes by a hot spring chill on the shore", Model.Compute(state({ base = 18, hotWater = true }), 1).target, -41)
near("a swim in cold water still chills", Model.Compute(state({ base = 18, swimming = true }), 1).target, -41)
near("a campfire adds nothing in a hot spring", Model.Compute(state({ base = 18, swimming = true, hotWater = true, campfire = 1 }), 1).target, 18)
near("weather scaled", Model.Compute(state({ base = 0, weather = "snow", weatherIntensity = 0.5 }), 0).target, -10)
near("clamped", Model.Compute(state({ base = -120 }), 0).target, -100)
-- No air is as hot as fire: only fire underfoot reaches the top.
near("the hottest air stays below fire", Model.Compute(state({ base = 120 }), 0).target, 95)
check("the air ceiling is reported", Model.Compute(state({ base = 120 }), 0).capped, true)
check("no ceiling report below it", Model.Compute(state({ base = 90 }), 0).capped, false)
check("no ceiling report in fire", Model.Compute(state({ base = 120, burning = 1 }), 0).capped, false)
check("no ceiling report for a ghost", Model.Compute(state({ base = 120, dead = true }), 0).capped, false)
near("a tauren in the hottest air stays below fire", Model.Compute(state({ base = 95, body = { cold = 0.75, heat = 1.15 } }), 0).target, 95)
near("a sandstorm at a desert noon stays below fire", Model.Compute(
	{ base = 55, climate = "desert", hour = 15, weather = "sandstorm", weatherIntensity = 1 }, 0).target, 95)
near("fire underfoot in the hottest air reaches the top", Model.Compute(state({ base = 120, burning = 1 }), 0).target, 100)
check("inn cozy", Model.Compute(state({ base = 5, indoors = true, inn = true }), 0).cozy, true)
check("campfire too hot not cozy", Model.Compute(state({ base = 75, campfire = 1 }), 0).cozy, false)
check("campfire still cold not cozy", Model.Compute(state({ base = -100, campfire = 1 }), 0).cozy, false)
check("outdoors not cozy", Model.Compute(state({ base = 0 }), 0).cozy, false)
near("a campfire warms no swimmer", Model.Compute(state({ base = 15, campfire = 1, swimming = true }), 1).target, -42.5)
near("no campfire step in the water", Model.Compute(state({ base = 15, campfire = 1, swimming = true }), 1).campfire, 0)
check("a swim next to a campfire is not cozy", Model.Compute(state({ base = 15, campfire = 1, swimming = true }), 1).cozy, false)
check("a swim in an inn is not cozy", Model.Compute(state({ base = 5, indoors = true, inn = true, swimming = true }), 0).cozy, false)
check("a hot spring next to a campfire is not cozy", Model.Compute(state({ base = 15, campfire = 1, swimming = true, hotWater = true }), 1).cozy, false)
check("damp on the shore by a campfire is cozy", Model.Compute(state({ base = 15, campfire = 1 }), 0.5).cozy, true)
check("soaked on the shore by a campfire is not cozy yet", Model.Compute(state({ base = 15, campfire = 1 }), 1).cozy, false)
check("inn reported", Model.Compute(state({ base = 5, indoors = true, inn = true }), 0).inn, true)
check("no inn in an instance", Model.Compute(state({ base = 5, indoors = true, inn = true, inInstance = true }), 0).inn, false)
check("no inn outdoors", Model.Compute(state({ base = 5 }), 0).inn, false)

-- Dead
near("a ghost feels cold", Model.Compute(state({ base = -60, dead = true }), 0).target, Model.DEAD_FEEL)
near("a ghost in the desert too", Model.Compute(state({ base = 105, dead = true }), 0).target, Model.DEAD_FEEL)
check("a ghost by a fire is not cozy", Model.Compute(state({ base = 15, campfire = 1, dead = true }), 0).cozy, false)
check("a ghost in an inn is not cozy", Model.Compute(state({ base = 5, indoors = true, inn = true, dead = true }), 0).cozy, false)
near("a ghost does not burn", Model.Compute(state({ base = 0, burning = 1, dead = true }), 0).target, Model.DEAD_FEEL)
near("a ghost has no race", Model.Compute(state({ base = -60, dead = true, body = { cold = 1.2, heat = 0.8 } }), 0).target, Model.DEAD_FEEL)
check("the ghost's cold is Cold, not Freezing", Model.Band(Model.DEAD_FEEL).word, "Cold")
check("the ghost's cold has no icy ring", (Model.Extremes(Model.DEAD_FEEL)), 0)

-- Humid air
near("humid jungle afternoon", Model.Compute(state({ base = 45, climate = "tropical", hour = 15 }), 0).target, 58.75)
near("humid step", Model.Compute(state({ base = 45, climate = "tropical", hour = 15 }), 0).humid, 7.75)
near("humid jungle night", Model.Compute(state({ base = 45, climate = "tropical", hour = 5 }), 0).target, 43.75)
near("humid below the start", Model.Compute(state({ base = 15, climate = "tropical", hour = 5 }), 0).target, 9)
near("humid at the start", Model.Compute(state({ base = 20, climate = "tropical", hour = 9 }), 0).humid, 0)
near("humid just above the start", Model.Compute(state({ base = 21, climate = "tropical", hour = 9 }), 0).humid, 0.25)
near("no humid air without the climate", Model.Compute(state({ base = 60, climate = "none" }), 0).humid, 0)
-- Humid air dries nothing: Un'Goro before dawn dries like the plain 49, not the felt 56.
local ungoroNight = state({ base = 55, climate = "tropical", hour = 5 })
near("humid night feels hotter", Model.Compute(ungoroNight, 0).dry, 56.25)
near("humid night dries like the plain air", Model.Compute(ungoroNight, 0).drying, 49)
near("plain air dries at the normal pace", Model.UpdateWetness(1, 45, ungoroNight, Model.Compute(ungoroNight, 0).drying), 0.5)
near("humid air in a building dries like the plain air", Model.Compute(state({ base = 55, climate = "tropical", hour = 5, indoors = true }), 0).drying, 28.6)
near("dry air dries as it feels", Model.Compute(state({ base = 60, climate = "arid", hour = 0 }), 0).drying,
	Model.Compute(state({ base = 60, climate = "arid", hour = 0 }), 0).dry)
near("dry heat is not humid", Model.Compute(state({ base = 60, climate = "arid", hour = 0 }), 0).humid, 0)
near("rain first, then humid", Model.Compute(state({ base = 45, climate = "tropical", hour = 15, weather = "rain", weatherIntensity = 1 }), 0).target, 43.75)
near("humid in a building", Model.Compute(state({ base = 45, climate = "tropical", hour = 15, indoors = true }), 0).target, 32.5)
near("troll feels humid heat less", Model.Compute(state({ base = 45, climate = "tropical", hour = 15, body = { cold = 1.2, heat = 0.8 } }), 0).target, 47)

-- Race
local dwarf = { cold = 0.75, heat = 1 }
local undead = { cold = 0.5, heat = 0.6 }
local tauren = { cold = 0.75, heat = 1.15 }
local troll = { cold = 1.2, heat = 0.8 }
check("no body feels like a human", Model.BodyFeel(-60, nil), -60)
check("neutral body", Model.BodyFeel(-60, { cold = 1, heat = 1 }), -60)
near("no race without a body", Model.Compute(state({ base = -60 }), 0).race, 0)
near("dwarf in the snow", Model.Compute(state({ base = -60, body = dwarf }), 0).target, -45)
near("dwarf race step", Model.Compute(state({ base = -60, body = dwarf }), 0).race, 15)
near("tauren in the heat", Model.Compute(state({ base = 50, body = tauren }), 0).target, 57.5)
near("undead scaled before the clamp", Model.Compute(state({ base = 105, body = undead }), 0).target, 63)
near("undead in lava", Model.Compute(state({ base = -60, burning = 1, body = undead }), 0).target, 100)
near("wet clothes scaled too", Model.Compute(state({ base = -60, body = dwarf }), 1).target, -60)
near("human by a fire at night", Model.Compute(state({ base = -56, campfire = 1 }), 0).target, -21)
check("human by a fire at night is cozy", Model.Compute(state({ base = -56, campfire = 1 }), 0).cozy, true)
near("troll by a fire at night", Model.Compute(state({ base = -56, campfire = 1, body = troll }), 0).target, -25.2)
check("troll by a fire at night is not cozy", Model.Compute(state({ base = -56, campfire = 1, body = troll }), 0).cozy, false)
-- By a campfire in Dun Morogh: Cozy by day, too close to Cold before dawn.
check("dun morogh day by a fire is cozy", Model.Compute(state({ base = -60, climate = "snow", hour = 15, campfire = 1 }), 0).cozy, true)
check("dun morogh night by a fire is not cozy", Model.Compute(state({ base = -60, climate = "snow", hour = 5, campfire = 1 }), 0).cozy, false)
check("dun morogh night by a fire with a drink is cozy", Model.Compute(state({ base = -60, climate = "snow", hour = 5, campfire = 1, drunk = 1 }), 0).cozy, true)
-- Cozy is never close to Cold.
near("the cold edge of mild by a fire", Model.Compute(state({ base = -68, campfire = 1 }), 0).target, -33)
check("the cold edge of mild by a fire is not cozy", Model.Compute(state({ base = -68, campfire = 1 }), 0).cozy, false)
for name, body in pairs({ dwarf = dwarf, undead = undead, tauren = tauren, troll = troll }) do
	near("mild stays mild for " .. name, Model.Compute(state({ base = 0, body = body }), 0).target, 0)
end
-- A fire warms every body only up to Warm.
near("tauren by a fire on a mild day", Model.Compute(state({ base = 15, campfire = 1, body = tauren }), 0).target, 45)
check("tauren by a fire on a mild day is cozy", Model.Compute(state({ base = 15, campfire = 1, body = tauren }), 0).cozy, true)
near("tauren with a torch on a warm day", Model.Compute(state({ base = 30, torch = true, body = tauren }), 0).target, 34.5)
near("tauren by a fire and a torch", Model.Compute(state({ base = 10, campfire = 1, torch = true, body = tauren }), 0).target, 45)
-- A fire never cools a body that is hotter without it.
near("hot tauren by a fire", Model.Compute(state({ base = 50, campfire = 1, body = tauren }), 0).target, 57.5)
near("warm tauren by a fire", Model.Compute(state({ base = 42, campfire = 1, body = tauren }), 0).target, 48.3)
near("warm tauren without a fire", Model.Compute(state({ base = 42, body = tauren }), 0).target, 48.3)
near("damp warm tauren by a fire", Model.Compute(state({ base = 44, campfire = 1, body = tauren }), 0.01).target,
	Model.Compute(state({ base = 44, body = tauren }), 0.01).target)
-- Below the ceiling the fire row stays as before.
near("dwarf by a fire at night", Model.Compute(state({ base = -68, campfire = 1, body = dwarf }), 0).target, -24.75)
-- Every Forever race is in the table, and every entry has both factors.
assert(loadfile("FeelsLike/Data/Races.lua"))("FeelsLike", ns)
for _, race in ipairs({ "Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "Gnome", "Troll", "Skyborne" }) do
	check("race in table: " .. race, ns.Races[race] ~= nil, true)
end
local bodies = { Fur = ns.Fur }
for name, body in pairs(ns.Races) do
	bodies[name] = body
end
for name, body in pairs(ns.UndeadFeel) do
	bodies["undead " .. name] = body
	check("undead choice has a name: " .. name, type(ns.UndeadFeelNames[name]) == "string", true)
end
for name, body in pairs(bodies) do
	check("body factors: " .. name, type(body.cold) == "number" and body.cold > 0
		and type(body.heat) == "number" and body.heat > 0, true)
end
check("numb is the race's own body", ns.UndeadFeel.numb, ns.Races.Scourge)
local listed = {}
for _, name in ipairs(ns.UndeadFeelOrder) do
	check("listed undead choice exists: " .. name, ns.UndeadFeel[name] ~= nil, true)
	listed[name] = true
end
for name in pairs(ns.UndeadFeel) do
	check("undead choice is listed: " .. name, listed[name], true)
end
for id, name in pairs(ns.FurForms) do
	check("fur form " .. id, type(id) == "number" and type(name) == "string", true)
end

-- Campfire nearness
check("fresh aura", Model.CampfireNearness(0), 1)
check("renewed recently", Model.CampfireNearness(4), 1)
near("walking away", Model.CampfireNearness(6), 0.5)
check("walked away", Model.CampfireNearness(8), 0)
-- Measured renewal gap
check("slow fire still near", Model.CampfireNearness(6, 6), 1)
near("slow fire walking away", Model.CampfireNearness(10, 6), 0.375)
check("slow fire walked away", Model.CampfireNearness(12, 6), 0)
check("fast fire keeps the minimum hold", Model.CampfireNearness(4, 1), 1)
near("hold is capped", Model.CampfireNearness(17, 60), 0.75)
check("capped hold ends", Model.CampfireNearness(20, 60), 0)
check("old aura", Model.CampfireNearness(50), 0)
near("half near", Model.Compute(state({ base = -60, campfire = 0.5 }), 0).target, -42.5)
check("half near is not cozy", Model.Compute(state({ base = 0, campfire = 0.4 }), 0).cozy, false)
near("inn ignores campfire", Model.Compute(state({ base = 5, indoors = true, inn = true, campfire = 1 }), 0).target, 20.3)

-- Fire underfoot
check("no hit", Model.Burning(nil), 0)
check("just hit", Model.Burning(0), 1)
check("still holding", Model.Burning(2.5), 1)
near("fading", Model.Burning(4.5), 0.5)
check("faded", Model.Burning(6.5), 0)
check("long ago", Model.Burning(100), 0)
check("lava: swimming with a fresh hit burns", Model.Burning(1, true), 1)
check("water puts the fire out", Model.Burning(3, true), 0)
near("out of the water it fades as usual", Model.Burning(4.5, false), 0.5)

-- Fire spells in a fight
check("no fire spell", Model.FireSpellBurning(nil), 0)
check("fire spell just hit", Model.FireSpellBurning(0), 1)
check("fire spell holds a moment", Model.FireSpellBurning(1), 1)
near("fire spell fading", Model.FireSpellBurning(2.5), 0.5)
check("fire spell faded", Model.FireSpellBurning(4), 0)
local numbUndead = ns.UndeadFeel.numb
near("a fire spell scorches the undead", Model.Compute(state({ base = -60, fireSpell = 1, body = numbUndead }), 0).target, 100)
near("a fading fire spell", Model.Compute(state({ base = -60, fireSpell = 0.5, body = numbUndead }), 0).target, 35)
near("a fire spell does not burn a human", Model.Compute(state({ base = -60, fireSpell = 1 }), 0).target, -60)
near("a fire spell does not burn undead like the living", Model.Compute(state({ base = -60, fireSpell = 1, body = ns.UndeadFeel.living }), 0).target, -60)
near("a fire spell does not burn a dwarf", Model.Compute(state({ base = -60, fireSpell = 1, body = ns.Races.Dwarf }), 0).target, -45)
near("burning reports the fire spell", Model.Compute(state({ base = -60, fireSpell = 0.5, body = numbUndead }), 0).burning, 0.5)
near("burning takes the stronger fire", Model.Compute(state({ base = -60, burning = 1, fireSpell = 0.5, body = numbUndead }), 0).burning, 1)
near("burning without a fire spell for a human", Model.Compute(state({ base = -60, fireSpell = 1 }), 0).burning, 0)
check("the undead fear fire", ns.Races.Scourge.fireSpells, true)
check("numb undead by a fire are cozy", Model.Compute(state({ base = 15, campfire = 1, body = ns.UndeadFeel.numb }), 0).cozy, true)
-- Two choices for the undead: numb or like the living.
check("two undead choices", #ns.UndeadFeelOrder, 2)
check("always cold is gone", ns.UndeadFeel.cold, nil)
check("only the undead fear fire", ns.UndeadFeel.living.fireSpells or ns.Races.Dwarf.fireSpells or ns.Fur.fireSpells, nil)

-- Frost spells chill every body for a moment
check("no frost spell", Model.FrostSpellChill(nil), 0)
check("frost spell just hit", Model.FrostSpellChill(0), 1)
near("frost spell fading", Model.FrostSpellChill(2.5), 0.5)
check("frost spell faded", Model.FrostSpellChill(4), 0)
near("a frost spell chills a mild day", Model.Compute(state({ base = 15, frostSpell = 1 }), 0).target, -85)
near("a fading frost spell", Model.Compute(state({ base = 15, frostSpell = 0.5 }), 0).target, -35)
near("frost step", Model.Compute(state({ base = 15, frostSpell = 0.5 }), 0).frost, -50)
near("a frost spell warms no one who is colder", Model.Compute(state({ base = -95, frostSpell = 1 }), 0).target, -95)
near("a frost spell chills the undead the same", Model.Compute(state({ base = 15, frostSpell = 1, body = ns.UndeadFeel.numb }), 0).target, -85)
near("a frost spell in the hottest air", Model.Compute(state({ base = 120, frostSpell = 1 }), 0).target, -85)
check("no ceiling report under a frost spell", Model.Compute(state({ base = 120, frostSpell = 0.5 }), 0).capped, false)
near("fire underfoot beats a frost spell", Model.Compute(state({ base = 15, frostSpell = 1, burning = 1 }), 0).target, 100)
near("a ghost feels no frost spell", Model.Compute(state({ base = 15, frostSpell = 1, dead = true }), 0).target, Model.DEAD_FEEL)
check("a frost spell is not cozy", Model.Compute(state({ base = 5, indoors = true, inn = true, frostSpell = 1 }), 0).cozy, false)

-- A drink warms a cold body
near("sober", Model.Compute(state({ base = -60, drunk = 0 }), 0).target, -60)
near("tipsy in the snow", Model.Compute(state({ base = -60, drunk = 1 }), 0).target, -50)
near("drunk in the snow", Model.Compute(state({ base = -60, drunk = 2 }), 0).target, -40)
near("completely smashed in the snow", Model.Compute(state({ base = -60, drunk = 3 }), 0).target, -30)
near("drink step", Model.Compute(state({ base = -60, drunk = 2 }), 0).drink, 20)
near("no drink step when sober", Model.Compute(state({ base = -60 }), 0).drink, 0)
near("a drink stops at the middle of mild", Model.Compute(state({ base = -5, drunk = 3 }), 0).target, 0)
near("a drink does not warm mild", Model.Compute(state({ base = 0, drunk = 3 }), 0).target, 0)
near("a drink does not heat the heat", Model.Compute(state({ base = 50, drunk = 3 }), 0).target, 50)
near("a drink after the race", Model.Compute(state({ base = -60, drunk = 1, body = ns.Races.Dwarf }), 0).target, -35)
near("a drink after the race, troll", Model.Compute(state({ base = -60, drunk = 1, body = ns.Races.Troll }), 0).target, -62)
near("a drink in wet clothes", Model.Compute(state({ base = 0, drunk = 1 }), 1).target, -40)
near("a drink by a fire at night", Model.Compute(state({ base = -68, campfire = 1, drunk = 3, body = ns.Races.Troll }), 0).target, -9.6)
check("a drink by a fire at night is cozy", Model.Compute(state({ base = -68, campfire = 1, drunk = 3, body = ns.Races.Troll }), 0).cozy, true)
near("a drink and fire underfoot", Model.Compute(state({ base = -60, drunk = 3, burning = 1 }), 0).target, 100)
near("a drink for a ghost", Model.Compute(state({ base = -60, drunk = 3, dead = true }), 0).target, Model.DEAD_FEEL)
near("burning freezing zone", Model.Compute(state({ base = -100, burning = 1 }), 0).target, 100)
near("half burning", Model.Compute(state({ base = -60, burning = 0.5 }), 0).target, 20)
near("burning wet", Model.Compute(state({ base = 0, burning = 1 }), 1).target, 100)
check("burning not cozy", Model.Compute(state({ base = 5, indoors = true, inn = true, burning = 1 }), 0).cozy, false)
near("fire burns the rest above the hottest air", Model.Compute(state({ base = 100, campfire = 1, burning = 1 }), 0).burn, 5)

-- Wetness
check("swimming soaks", Model.UpdateWetness(0, 1, state({ swimming = true }), 0), 1)
near("normal drying", Model.UpdateWetness(1, 9, state({}), 0), 0.9)
near("hot drying", Model.UpdateWetness(1, 9, state({}), 60), 0.8)
near("cold drying", Model.UpdateWetness(1, 15, state({}), -60), 0.9)
check("dry stays dry", Model.UpdateWetness(0, 10, state({}), 0), 0)
near("rain soaks slowly", Model.UpdateWetness(0, 6, state({ weather = "rain", weatherIntensity = 1 }), 0), 0.1)
near("rain caps", Model.UpdateWetness(0.39, 6, state({ weather = "rain", weatherIntensity = 1 }), 0), 0.4)
near("rain keeps damp", Model.UpdateWetness(1, 90, state({ weather = "rain", weatherIntensity = 1 }), 0), 0.4)
check("rain indoors dries", Model.UpdateWetness(0, 6, state({ weather = "rain", weatherIntensity = 1, indoors = true }), 0), 0)
near("inn dries fast", Model.UpdateWetness(1, 7.5, state({ inn = true }), 0), 0.5)
near("inside place is no inn for drying", Model.UpdateWetness(1, 9, state({ inn = true, inside = true }), 0), 0.9)
near("campfire dries fast", Model.UpdateWetness(1, 7.5, state({ campfire = 1 }), -60), 0.5)
check("fire dries at once", Model.UpdateWetness(1, 1, state({ burning = 0.3 }), -60), 0)
check("lava does not soak", Model.UpdateWetness(0, 1, state({ swimming = true, burning = 1 }), 100), 0)
check("a fire hit in the water may be lava: no soaking yet", Model.UpdateWetness(0, 1, state({ swimming = true, maybeLava = true }), 100), 0)
check("a fire hit in the water keeps wet clothes wet", Model.UpdateWetness(1, 1, state({ swimming = true, maybeLava = true }), 100), 1)

-- Reasons for the tooltip
local function reasons(fields, wetness)
	local s = state(fields)
	local colder, warmer = Model.Reasons(s, Model.Compute(s, wetness or 0))
	return table.concat(colder, ", ") .. " / " .. table.concat(warmer, ", ")
end
check("reasons in the snow at night", reasons({ base = -60, climate = "snow", hour = 5, weather = "snow", weatherIntensity = 1 }),
	"a cold place, snow, the night / ")
check("reasons by a fire with a drink", reasons({ base = -60, campfire = 1, drunk = 2 }), " / a campfire")
check("reasons at a desert noon", reasons({ base = 55, climate = "desert", hour = 15 }), " / a hot place, the sun")
check("reasons in the water", reasons({ base = 15, swimming = true }, 1), "the water / ")
check("reasons in wet clothes", reasons({ base = 15 }, 1), "wet clothes / ")
check("reasons in a cool place at night", reasons({ base = -15, climate = "temperate", hour = 5 }), "the night, a cool place / ")
check("reasons under a roof in the heat", reasons({ base = 75, indoors = true }), " / a hot place")
check("reasons in an inn in the cold", reasons({ base = -60, indoors = true, inn = true }), " / the inn")
check("reasons name the body", reasons({ base = -60, body = { cold = 0.75, heat = 1 }, bodyWord = "your fur" }), "a cold place / ")
check("reasons in fire", reasons({ base = 0, burning = 1 }), " / fire")
check("small steps get no word", reasons({ base = 2 }), " / ")
check("at most three reasons a side", reasons({ base = -60, climate = "snow", hour = 5, weather = "snow", weatherIntensity = 1 }, 1),
	"a cold place, snow, the night / ")
check("a ghost's reason", reasons({ base = 60, dead = true }), "death / ")
check("reasons name the holiday", reasons({ base = 5, climate = "temperate", hour = 15, month = 12, day = 24 }), "Winter Veil / the sun, a warm place")
check("reasons name the season", reasons({ base = 5, climate = "temperate", hour = 15, month = 7, day = 20 }), " / the sun, a warm place, summer")
-- One line that never argues with the word: a cold word names no warmth, Cozy names only its source.
check("a cold word names no sun", reasons({ base = -60, climate = "snow", hour = 15, weather = "snow", weatherIntensity = 1 }),
	"a cold place, snow / ")
check("cozy in an inn in the snow names only the inn",
	reasons({ base = -60, climate = "snow", hour = 15, weather = "snow", weatherIntensity = 1, indoors = true, inn = true }), " / the inn")
check("mild names both sides", reasons({ base = -30, torch = true }), "a cool place / a torch")
check("no sun and no snow under a roof",
	reasons({ base = -60, climate = "snow", hour = 15, weather = "snow", weatherIntensity = 1, indoors = true }), "a cold place / ")
check("the night still counts under a roof", reasons({ base = -15, climate = "temperate", hour = 5, indoors = true }), "the night, a cool place / a roof")
check("reasons name a frost spell", reasons({ base = 15, frostSpell = 1 }), "a frost spell / ")

-- A fight warms you
check("a fight builds warmth over 8 s", Model.UpdateExertion(0, 4, true), 0.5)
check("the warmth of a fight stops at full", Model.UpdateExertion(0.9, 4, true), 1)
check("it fades over 30 s after the fight", Model.UpdateExertion(1, 15, false), 0.5)
check("and is gone then", Model.UpdateExertion(0.2, 30, false), 0)
check("a fight warms by 12", Model.Compute(state({ base = -60, exertion = 1 }), 0).target, -48)
check("half a fight warms by 6", Model.Compute(state({ base = 20, exertion = 0.5 }), 0).target, 26)
check("a fight warms the numb undead alike", Model.Compute(state({ base = -60, exertion = 1, body = { cold = 0.5, heat = 0.6 } }), 0).target, -18)
check("a fight warms no further than a fire", Model.Compute(state({ base = 40, exertion = 1 }), 0).target, 45)
check("a fight changes nothing in the heat", Model.Compute(state({ base = 60, exertion = 1 }), 0).target, 60)
check("and takes no blame there", Model.Compute(state({ base = 60, exertion = 1 }), 0).fight, 0)
local byFire = Model.Compute(state({ base = 20, campfire = 1, exertion = 1 }), 0)
check("cozy by a fire stays cozy in a fight", byFire.cozy and byFire.target, 45)
check("a ghost feels no fight", Model.Compute(state({ base = 20, exertion = 1, dead = true }), 0).target, Model.DEAD_FEEL)
check("reasons name the fight", reasons({ base = 40, exertion = 1 }), " / a hot place, a fight")
check("reasons name the fight in a mild place", reasons({ base = 10, exertion = 1 }), " / a fight, a warm place")

-- The needle on its spring
local function glide(from, aim, seconds, dt)
	local position, velocity, extreme = from, 0, from
	for _ = 1, math.floor(seconds / dt + 0.5) do
		position, velocity = Model.NeedleStep(position, velocity, aim, dt)
		extreme = aim > from and math.max(extreme, position) or math.min(extreme, position)
	end
	return position, velocity, extreme
end
local needleAt, needleSpeed, needlePeak = glide(0, 100, 3, 0.01)
check("the needle comes to rest on its aim", math.abs(needleAt - 100) < 0.01 and math.abs(needleSpeed) < 0.01, true)
check("the needle swings a little past its aim", needlePeak > 104 and needlePeak < 109, true)
local downAt, _, downPeak = glide(50, -50, 3, 0.01)
check("the same on the way down", math.abs(downAt + 50) < 0.01 and downPeak < -54 and downPeak > -59, true)
local slowFrames, slowSpeed = glide(0, 100, 0.4, 0.1)
local fastFrames, fastSpeed = glide(0, 100, 0.4, 0.004)
check("the needle moves the same at any frame rate", math.abs(slowFrames - fastFrames) < 1e-6 and math.abs(slowSpeed - fastSpeed) < 1e-6, true)
check("the needle starts gently", select(1, Model.NeedleStep(0, 0, 100, 0.016)) < 1, true)
check("a needle at rest stays", select(1, Model.NeedleStep(30, 0, 30, 1)), 30)
check("a long freeze of the game is no trouble", math.abs(select(1, Model.NeedleStep(0, 0, 100, 60)) - 100) < 1e-6, true)

-- Shelter delay
local memory = {}
check("first reading counts at once", Model.SettleShelter(memory, "outdoors", 0), "outdoors")
check("door: indoors waits", Model.SettleShelter(memory, "indoors", 10), "outdoors")
check("door: resting a moment later waits", Model.SettleShelter(memory, "inn", 10.5), "outdoors")
check("inn not yet", Model.SettleShelter(memory, "inn", 12.4), "outdoors")
check("inn after 2 s", Model.SettleShelter(memory, "inn", 12.5), "inn")
check("flicker back cancels nothing", Model.SettleShelter(memory, "inn", 20), "inn")
check("short step outside ignored", Model.SettleShelter(memory, "outdoors", 21), "inn")
check("back inside clears it", Model.SettleShelter(memory, "inn", 22), "inn")
check("new pending starts over", Model.SettleShelter(memory, "outdoors", 23), "inn")
check("outdoors after 2 s", Model.SettleShelter(memory, "outdoors", 25), "outdoors")

-- Languages: every word and every line in chat has a text in every language.
local LANGUAGES = {
	{ code = "uk", name = "Українська", cold = "Холодно" },
	{ code = "de", name = "Deutsch", cold = "Kalt", clients = { "deDE" } },
	{ code = "fr", name = "Français", cold = "Froid", clients = { "frFR" } },
}
assert(loadfile("FeelsLike/Locale.lua"))("FeelsLike", ns)
-- Keeps each table, to compare them.
local added = {}
local add = ns.Locale.Add
ns.Locale.Add = function(language, name, texts, clients)
	added[language] = texts
	add(language, name, texts, clients)
end
local order = { "en" }
for _, language in ipairs(LANGUAGES) do
	assert(loadfile("FeelsLike/Locale/" .. language.code .. ".lua"))("FeelsLike", ns)
	order[#order + 1] = language.code
end
assert(loadfile("FeelsLike/Flavor.lua"))("FeelsLike", ns)
check("english is the default", ns.T("Cold"), "Cold")
check("an unknown language is english", (function() ns.Locale.Set("xx") return ns.Locale.language .. ns.T("Cold") end)(), "enCold")
check("the languages in the settings", table.concat(ns.Locale.order, ","), table.concat(order, ","))
check("an english game is english", ns.Locale.ForClient("enUS"), "en")
check("a game language with no translation is english", ns.Locale.ForClient("koKR"), "en")
local texts = { "Freezing", "Cold", "Mild", "Warm", "Hot", "Scorching", "Cozy", "Why:",
	"your fur", "your race", "dead flesh" }
for _, word in ipairs(Model.REASON_WORDS) do
	texts[#texts + 1] = word
end
local lineCount = 0
for _, set in ipairs(ns.Flavor.SETS) do
	for _, lines in pairs(set) do
		for _, line in ipairs(lines) do
			texts[#texts + 1] = line
			lineCount = lineCount + 1
		end
	end
end
check("the chat lines were found", lineCount, 60)

-- Letters, not bytes.
local function Length(text)
	return select(2, text:gsub("[^\128-\191]", ""))
end
-- The last sign of a sentence. French puts a space before "!" and "?", and that changes nothing here.
local function Ending(text)
	return text:match("[%.!%?%)]$") or ""
end
local STATUS_WORDS = { "Freezing", "Cold", "Mild", "Warm", "Hot", "Scorching", "Cozy" }
-- A text that names other texts has to name them as they are translated.
local NAMES_INSIDE = {
	["The status is one word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."] = STATUS_WORDS,
	["Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."] =
		{ "Feel by race", "Numb", "Like the living" },
}
-- What a player types stays as it is in every language.
local KEPT = { "/shiver", "/feels test off", "/feels", "/reload", "Feels Like" }

for _, language in ipairs(LANGUAGES) do
	local code = language.code
	local own = added[code]
	check(code .. " is listed with its own name", ns.Locale.names[code], language.name)
	for _, client in ipairs(language.clients or {}) do
		check(code .. " is the default for " .. client, ns.Locale.ForClient(client), code)
	end
	ns.Locale.Set(code)
	check(code .. " word", ns.T("Cold"), language.cold)
	for _, text in ipairs(texts) do
		local translated = ns.T(text)
		-- The same word as English is fine: Mild and Warm are German too.
		check(code .. " for: " .. text, own[text] ~= nil and translated == own[text] and translated ~= "", true)
	end
	check(code .. ": no text without a translation", next(ns.Locale.missing), nil)
	-- The same texts as Ukrainian, the first translation: none forgotten and none left over.
	for text in pairs(added.uk) do
		check(code .. " has: " .. text, own[text] ~= nil, true)
	end
	for text, translated in pairs(own) do
		check(code .. " knows: " .. text, added.uk[text] ~= nil, true)
		check(code .. " is tidy: " .. text, translated ~= "" and not translated:find("^%s") and not translated:find("%s$")
			and not translated:find("  ", 1, true), true)
		check(code .. " ends like english: " .. text, Ending(translated), Ending(text))
		for _, kept in ipairs(KEPT) do
			if text:find(kept, 1, true) then
				check(code .. " keeps " .. kept .. ": " .. text, translated:find(kept, 1, true) ~= nil, true)
			end
		end
	end
	-- The status sits next to a small gauge.
	for _, word in ipairs(STATUS_WORDS) do
		check(code .. " status is short: " .. word, Length(own[word]) <= 12, true)
	end
	for text, names in pairs(NAMES_INSIDE) do
		for _, name in ipairs(names) do
			check(code .. " names " .. name .. " as translated", own[text]:find(own[name], 1, true) ~= nil, true)
		end
	end
end
check("a text with no translation stays english", ns.T("no such text"), "no such text")
check("and it is noted", ns.Locale.missing["no such text"], true)
ns.Locale.Set("en")
-- Every reason the model gives is in the list the translations are checked against.
local known = {}
for _, word in ipairs(Model.REASON_WORDS) do
	known[word] = true
end
for _, fields in ipairs({
	{ base = -60, climate = "snow", hour = 5, weather = "snow", weatherIntensity = 1 },
	{ base = 55, climate = "desert", hour = 15, weather = "sandstorm", weatherIntensity = 1 },
	{ base = 45, climate = "tropical", hour = 15, weather = "rain", weatherIntensity = 1, month = 7, day = 20 },
	{ base = 5, climate = "temperate", hour = 5, month = 12, day = 24, campfire = 1, torch = true, drunk = 3 },
	{ base = 5, climate = "temperate", hour = 15, month = 6, day = 25, indoors = true, inn = true },
	{ base = -20, indoors = true, frostSpell = 1 }, { base = 20, swimming = true }, { base = 20, burning = 1 },
	{ base = 60, dead = true }, { base = 20, exertion = 1 }, { base = -60, body = { cold = 0.75, heat = 1 } }, { base = 5, climate = "temperate", hour = 15, month = 1, day = 20 },
}) do
	local s = state(fields)
	local colder, warmer = Model.Reasons(s, Model.Compute(s, fields.swimming and 1 or 0.6))
	for _, list in ipairs({ colder, warmer }) do
		for _, word in ipairs(list) do
			check("reason word is in the list: " .. word, known[word], true)
		end
	end
end

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all model tests passed")
