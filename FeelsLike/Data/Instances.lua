-- Base temperature and climate per instanceID (8th return of GetInstanceInfo). IDs are the same in Forever and Retail.
-- Instances missing here count as a neutral indoor place. Source: wago.tools Map, build 1.60.1.70205.
-- Shelter does not apply inside instances, so these values are what the player feels there.

local _, ns = ...

local function Instance(base, climate)
	return { base = base, climate = climate }
end

ns.Instances = {
	-- Dungeons
	[33] = Instance(-15, "none"), -- Shadowfang Keep: cold stone keep
	[43] = Instance(20, "none"), -- Wailing Caverns: humid caves
	[47] = Instance(30, "arid"), -- Razorfen Kraul
	[48] = Instance(-20, "none"), -- Blackfathom Deeps: flooded ruins
	[70] = Instance(-10, "none"), -- Uldaman: stone vaults
	[109] = Instance(35, "none"), -- Sunken Temple: swamp water
	[129] = Instance(20, "arid"), -- Razorfen Downs
	[209] = Instance(55, "desert"), -- Zul'Farrak
	[229] = Instance(60, "volcanic"), -- Blackrock Spire
	[230] = Instance(70, "volcanic"), -- Blackrock Depths
	[289] = Instance(-30, "none"), -- Scholomance
	[329] = Instance(-10, "none"), -- Stratholme
	[389] = Instance(70, "volcanic"), -- Ragefire Chasm
	[429] = Instance(20, "tropical"), -- Dire Maul

	-- Raids
	[249] = Instance(60, "volcanic"), -- Onyxia's Lair
	[309] = Instance(45, "tropical"), -- Zul'Gurub
	[409] = Instance(100, "volcanic"), -- Molten Core
	[469] = Instance(60, "volcanic"), -- Blackwing Lair
	[509] = Instance(50, "desert"), -- Ruins of Ahn'Qiraj
	[531] = Instance(40, "none"), -- Ahn'Qiraj Temple
	[533] = Instance(-30, "none"), -- Naxxramas

	-- Battlegrounds
	[30] = Instance(-60, "snow"), -- Alterac Valley
	[489] = Instance(5, "temperate"), -- Warsong Gulch
	[529] = Instance(5, "temperate"), -- Arathi Basin
	[2997] = Instance(40, "tropical"), -- Darkspear Islands (new battleground)
	[3005] = Instance(-5, "temperate"), -- Battle for Gilneas

	-- In the Forever game data; names suggest the climate. Check in game.
	[2720] = Instance(80, "volcanic"), -- The Searing Basin
	[2789] = Instance(50, "arid"), -- The Tainted Scar (Blasted Lands)
	[2807] = Instance(60, "none"), -- Burning of Andorhal
	[2875] = Instance(-30, "none"), -- Karazhan Crypts
	[2902] = Instance(50, "desert"), -- The Scarab Dais
	[2921] = Instance(-30, "none"), -- Naxxramas (dungeon)
	[3109] = Instance(-10, "none"), -- Manor Mistmantle
}
