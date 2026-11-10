-- Base temperature from -100 to 100 and climate per map ID.

local _, ns = ...

local function Zone(base, climate, inside)
	return { base = base, climate = climate, inside = inside }
end

-- Places that are fully inside, like Ironforge and Undercity. Shelter and inns do not apply there.
local INSIDE = true

-- A place with hot water: a swim there chills nothing. Wet clothes chill again on the shore.
local function HotSpring(base, climate)
	local zone = Zone(base, climate)
	zone.hotWater = true
	return zone
end

-- A place with lava that is not volcanic as a whole. Lava burns there in a fight too.
local function WithLava(zone)
	zone.lava = true
	return zone
end

ns.Zones = {}

ns.Zones.forever = {
	-- Kalimdor
	[1411] = Zone(25, "arid"), -- Durotar
	[1412] = Zone(10, "temperate"), -- Mulgore
	[1413] = Zone(30, "arid"), -- The Barrens
	[1438] = Zone(0, "temperate"), -- Teldrassil
	[1439] = Zone(-10, "temperate"), -- Darkshore
	[1440] = Zone(0, "temperate"), -- Ashenvale
	[1441] = Zone(40, "arid"), -- Thousand Needles
	[1442] = Zone(5, "temperate"), -- Stonetalon Mountains
	[1443] = Zone(30, "arid"), -- Desolace
	[1444] = Zone(25, "tropical"), -- Feralas
	[1445] = Zone(35, "tropical"), -- Dustwallow Marsh
	[1446] = Zone(55, "desert"), -- Tanaris
	[1447] = Zone(5, "temperate"), -- Azshara
	[1448] = Zone(-10, "temperate"), -- Felwood
	[1449] = Zone(55, "tropical"), -- Un'Goro Crater
	[1450] = Zone(0, "temperate"), -- Moonglade
	[1451] = Zone(50, "desert"), -- Silithus
	[1452] = Zone(-80, "snow"), -- Winterspring
	[1454] = Zone(25, "arid"), -- Orgrimmar
	[1456] = Zone(10, "temperate"), -- Thunder Bluff
	[1457] = Zone(0, "temperate"), -- Darnassus
	[2482] = Zone(-45, "snow"), -- Mount Hyjal
	[2652] = Zone(10, "temperate"), -- Shen'dralas

	-- Eastern Kingdoms
	[1416] = Zone(-50, "snow"), -- Alterac Mountains
	[1417] = Zone(5, "temperate"), -- Arathi Highlands
	[1418] = Zone(60, "arid"), -- Badlands
	[1419] = Zone(50, "arid"), -- Blasted Lands
	[1420] = Zone(-15, "temperate"), -- Tirisfal Glades
	[1421] = Zone(-15, "temperate"), -- Silverpine Forest
	[1422] = Zone(-10, "temperate"), -- Western Plaguelands
	[1423] = Zone(-10, "temperate"), -- Eastern Plaguelands
	[1424] = Zone(0, "temperate"), -- Hillsbrad Foothills
	[1425] = Zone(0, "temperate"), -- The Hinterlands
	[1426] = Zone(-60, "snow"), -- Dun Morogh
	[1427] = Zone(85, "volcanic"), -- Searing Gorge
	[1428] = Zone(85, "volcanic"), -- Burning Steppes
	[1429] = Zone(5, "temperate"), -- Elwynn Forest
	[1430] = Zone(-10, "temperate"), -- Deadwind Pass
	[1431] = Zone(-5, "temperate"), -- Duskwood
	[1432] = Zone(-15, "temperate"), -- Loch Modan
	[1433] = Zone(5, "temperate"), -- Redridge Mountains
	[1434] = Zone(45, "tropical"), -- Stranglethorn Vale
	[1435] = Zone(35, "tropical"), -- Swamp of Sorrows
	[1436] = Zone(10, "temperate"), -- Westfall
	[1437] = Zone(-10, "temperate"), -- Wetlands
	[1453] = Zone(5, "temperate"), -- Stormwind City
	[1455] = Zone(25, "none", INSIDE), -- Ironforge
	[1458] = Zone(-20, "none", INSIDE), -- Undercity
	[2548] = Zone(10, "temperate"), -- Riverglades

	-- Skyborne start zone has two map IDs.
	[2521] = Zone(0, "temperate"), -- Zephras Isle
	[2665] = Zone(0, "temperate"), -- Zephras Isle
}

-- A few zones for testing on Retail.
ns.Zones.retail = {
	[1] = Zone(25, "arid"), -- Durotar
	[27] = Zone(-60, "snow"), -- Dun Morogh
	[37] = Zone(5, "temperate"), -- Elwynn Forest
	[71] = Zone(55, "desert"), -- Tanaris
	[83] = Zone(-80, "snow"), -- Winterspring
	[84] = Zone(5, "temperate"), -- Stormwind City
	[85] = Zone(25, "arid"), -- Orgrimmar
	[87] = Zone(25, "none", INSIDE), -- Ironforge
	[90] = Zone(-20, "none", INSIDE), -- Undercity
}

-- Subzone overrides per area ID.
ns.Zones.subzones = {
	[2246] = HotSpring(10, "snow"), -- Frostfire Hot Springs
	[439] = Zone(55, "desert"), -- The Shimmering Flats
	[509] = Zone(60, "volcanic"), -- The Den of Flame
	[543] = HotSpring(60, "tropical"), -- Golakka Hot Springs
	[254] = Zone(90, "volcanic"), -- Blackrock Mountain
	[1445] = Zone(90, "volcanic"), -- Blackrock Mountain
	[16513] = Zone(90, "volcanic"), -- Blackrock Mountain
	[537] = Zone(90, "volcanic"), -- Fire Plume Ridge
	[246] = Zone(95, "volcanic"), -- The Cauldron
	[5342] = WithLava(Zone(45, "none", INSIDE)), -- The Great Forge
}
