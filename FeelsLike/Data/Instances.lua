-- Base temperature and climate per instance ID.

local _, ns = ...

local function Instance(base, climate)
	return { base = base, climate = climate }
end

ns.Instances = {
	-- Dungeons
	[33] = Instance(-15, "none"), -- Shadowfang Keep
	[43] = Instance(20, "none"), -- Wailing Caverns
	[47] = Instance(30, "arid"), -- Razorfen Kraul
	[48] = Instance(-20, "none"), -- Blackfathom Deeps
	[70] = Instance(-10, "none"), -- Uldaman
	[109] = Instance(35, "none"), -- Sunken Temple
	[129] = Instance(20, "arid"), -- Razorfen Downs
	[209] = Instance(55, "desert"), -- Zul'Farrak
	[229] = Instance(80, "volcanic"), -- Blackrock Spire
	[230] = Instance(90, "volcanic"), -- Blackrock Depths
	[289] = Instance(-40, "none"), -- Scholomance
	[329] = Instance(20, "none"), -- Stratholme
	[389] = Instance(70, "volcanic"), -- Ragefire Chasm
	[429] = Instance(20, "tropical"), -- Dire Maul

	-- Raids
	[249] = Instance(60, "volcanic"), -- Onyxia's Lair
	[309] = Instance(45, "tropical"), -- Zul'Gurub
	[409] = Instance(95, "volcanic"), -- Molten Core
	[469] = Instance(80, "volcanic"), -- Blackwing Lair
	[509] = Instance(50, "desert"), -- Ruins of Ahn'Qiraj
	[531] = Instance(40, "none"), -- Ahn'Qiraj Temple
	[533] = Instance(-40, "none"), -- Naxxramas

	-- Battlegrounds
	[30] = Instance(-60, "snow"), -- Alterac Valley
	[489] = Instance(5, "temperate"), -- Warsong Gulch
	[529] = Instance(5, "temperate"), -- Arathi Basin
	[2997] = Instance(40, "tropical"), -- Darkspear Islands
	[3005] = Instance(-5, "temperate"), -- Battle for Gilneas

	-- New in Forever, check in game.
	[2720] = Instance(80, "volcanic"), -- The Searing Basin
	[2789] = Instance(50, "arid"), -- The Tainted Scar
	[2807] = Instance(60, "none"), -- Burning of Andorhal
	[2875] = Instance(-40, "none"), -- Karazhan Crypts
	[2902] = Instance(50, "desert"), -- The Scarab Dais
	[2921] = Instance(-40, "none"), -- Naxxramas
	[3109] = Instance(-10, "none"), -- Manor Mistmantle
}
