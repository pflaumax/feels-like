-- Base temperature (-100..100) and climate per uiMapID. Draft values from PLAN.md section 6.1, tuned in game.
-- Forever uses the classic map IDs; Retail uses its own. Source: wago.tools UiMap, builds 1.60.1.70205 and 12.1.0.69933.

local _, ns = ...

local function Zone(base, climate, inside)
	return { base = base, climate = climate, inside = inside }
end

-- A place that is inside as a whole (in a mountain, underground). Its value already describes how it
-- feels in there, so shelter and inns do not apply, as in instances. The game reports such a city as
-- indoors and resting everywhere, so without this it would read as one big inn.
local INSIDE = true

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
	[2482] = Zone(-30, "snow"), -- Mount Hyjal (new, check in game)
	[2652] = Zone(10, "temperate"), -- Shen'dralas (new, check in game)

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
	[1455] = Zone(25, "none", INSIDE), -- Ironforge: inside the mountain, by the forges
	[1458] = Zone(-20, "none", INSIDE), -- Undercity: underground crypts
	[2548] = Zone(10, "temperate"), -- Riverglades (new, check in game)

	-- Skyborne start zone; two map IDs in the game data
	[2521] = Zone(0, "temperate"), -- Zephras Isle (new, check in game)
	[2665] = Zone(0, "temperate"), -- Zephras Isle (new, check in game)
}

-- Enough for testing on Retail before Forever launches.
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

-- Subzone overrides per areaID. The same area IDs work in both clients; an area missing in a client is skipped.
-- Sensors matches them by localized name, so a name must not belong to an area in another zone.
-- Checked against AreaTable on 2026-10-04 (Forever and Retail): Blackrock Mountain repeats, but every
-- copy is the same mountain with the same value. Check again when adding an entry.
ns.Zones.subzones = {
	[2246] = Zone(10, "snow"), -- Frostfire Hot Springs (Winterspring): warm water in the snow
	[439] = Zone(55, "desert"), -- The Shimmering Flats (Thousand Needles): salt flats
	[509] = Zone(60, "volcanic"), -- The Den of Flame (Dustwallow Marsh)
	[543] = Zone(70, "tropical"), -- Golakka Hot Springs (Un'Goro Crater)
	[254] = Zone(90, "volcanic"), -- Blackrock Mountain (Burning Steppes)
	[1445] = Zone(90, "volcanic"), -- Blackrock Mountain (Searing Gorge)
	[16513] = Zone(90, "volcanic"), -- Blackrock Mountain (Burning Steppes)
	[537] = Zone(90, "volcanic"), -- Fire Plume Ridge (Un'Goro Crater)
	[246] = Zone(100, "volcanic"), -- The Cauldron (Searing Gorge): lava pit
	[5342] = Zone(45, "none", INSIDE), -- The Great Forge (Ironforge, Retail only)
}
