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
cold, hot = Model.Extremes(-85)
near("extreme half cold", cold, 0.5)
check("extreme half cold hot", hot, 0)
cold, hot = Model.Extremes(100)
check("extreme max hot", hot, 1)
check("extreme max cold", cold, 0)
cold, hot = Model.Extremes(-1000)
check("extreme clamped cold", cold, 1)

-- Day and night
near("day peak desert", Model.DayNight(15, "desert"), 50)
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

-- Compute
local base = { base = 0, climate = "none", hour = 0, weather = nil, weatherIntensity = 0 }
local function state(fields)
	local s = {}
	for k, v in pairs(base) do s[k] = v end
	for k, v in pairs(fields) do s[k] = v end
	return s
end
-- Shelter
near("indoors in the heat is cooler", Model.Compute(state({ base = 75, indoors = true }), 0).target, 39)
near("indoors on a mild day is the same", Model.Compute(state({ base = 15, indoors = true }), 0).target, 15)
near("indoors at night is warmer", Model.Compute(state({ base = -5, indoors = true }), 0).target, 7)
near("inn", Model.Compute(state({ base = 75, indoors = true, inn = true }), 0).target, 27.3)
near("inn on a mild day is warmer", Model.Compute(state({ base = 15, indoors = true, inn = true }), 0).target, 21.3)
near("instance ignores shelter", Model.Compute(state({ base = 100, indoors = true, inInstance = true }), 0).target, 100)
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
near("torch and campfire share the limit", Model.Compute(state({ base = 0, campfire = 1, torch = true }), 0).target, 45)
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
near("weather scaled", Model.Compute(state({ base = 0, weather = "snow", weatherIntensity = 0.5 }), 0).target, -10)
near("clamped", Model.Compute(state({ base = 120 }), 0).target, 100)
check("inn cozy", Model.Compute(state({ base = 5, indoors = true, inn = true }), 0).cozy, true)
check("campfire too hot not cozy", Model.Compute(state({ base = 75, campfire = 1 }), 0).cozy, false)
check("campfire still cold not cozy", Model.Compute(state({ base = -100, campfire = 1 }), 0).cozy, false)
check("outdoors not cozy", Model.Compute(state({ base = 0 }), 0).cozy, false)

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
near("human by a fire at night", Model.Compute(state({ base = -68, campfire = 1 }), 0).target, -33)
check("human by a fire at night is cozy", Model.Compute(state({ base = -68, campfire = 1 }), 0).cozy, true)
near("troll by a fire at night", Model.Compute(state({ base = -68, campfire = 1, body = troll }), 0).target, -39.6)
check("troll by a fire at night is not cozy", Model.Compute(state({ base = -68, campfire = 1, body = troll }), 0).cozy, false)
for name, body in pairs({ dwarf = dwarf, undead = undead, tauren = tauren, troll = troll }) do
	near("mild stays mild for " .. name, Model.Compute(state({ base = 0, body = body }), 0).target, 0)
end
-- A fire warms every body only up to Warm.
near("tauren by a fire on a mild day", Model.Compute(state({ base = 15, campfire = 1, body = tauren }), 0).target, 45)
check("tauren by a fire on a mild day is cozy", Model.Compute(state({ base = 15, campfire = 1, body = tauren }), 0).cozy, true)
near("tauren with a torch on a warm day", Model.Compute(state({ base = 30, torch = true, body = tauren }), 0).target, 45)
near("tauren by a fire and a torch", Model.Compute(state({ base = 0, campfire = 1, torch = true, body = tauren }), 0).target, 45)
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
for race, body in pairs(ns.Races) do
	check("race factors: " .. race, type(body.cold) == "number" and body.cold > 0
		and type(body.heat) == "number" and body.heat > 0, true)
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
near("burning freezing zone", Model.Compute(state({ base = -100, burning = 1 }), 0).target, 100)
near("half burning", Model.Compute(state({ base = -60, burning = 0.5 }), 0).target, 20)
near("burning wet", Model.Compute(state({ base = 0, burning = 1 }), 1).target, 100)
check("burning not cozy", Model.Compute(state({ base = 5, indoors = true, inn = true, burning = 1 }), 0).cozy, false)
near("no negative burn when already hot", Model.Compute(state({ base = 100, campfire = 1, burning = 1 }), 0).burn, 0)

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

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all model tests passed")
