-- How strongly each race feels the cold and the heat. 1 is like a human. Keys are UnitRace's English names.
-- A shift moves the whole feel, for a body that runs cold.

local _, ns = ...

local function Body(cold, heat, shift)
	return { cold = cold, heat = heat, shift = shift }
end

ns.Races = {
	Human = Body(1, 1),
	Orc = Body(1, 1),
	Dwarf = Body(0.75, 1),
	NightElf = Body(1, 1),
	Scourge = Body(0.5, 0.6), -- Undead
	Tauren = Body(0.75, 1.15),
	Gnome = Body(1, 1),
	Troll = Body(1.2, 0.8),
	Skyborne = Body(1, 1), -- both factions
}

-- The undead choose how they feel. Numb is the default.
ns.UndeadFeel = {
	numb = ns.Races.Scourge,
	cold = Body(0.4, 0.4, -40), -- runs cold: chilly almost everywhere
	living = Body(1, 1),
}
ns.UndeadFeelNames = { numb = "Numb", cold = "Always cold", living = "Like the living" }
ns.UndeadFeelOrder = { "numb", "cold", "living" } -- as the settings list them

-- Forms with fur feel like a tauren. Keys are GetShapeshiftFormID's IDs.
ns.Fur = Body(0.75, 1.15)
ns.FurForms = {
	[1] = "Cat Form",
	[3] = "Travel Form",
	[5] = "Bear Form",
	[8] = "Dire Bear Form",
	[31] = "Moonkin Form", -- feathers over fur
}
