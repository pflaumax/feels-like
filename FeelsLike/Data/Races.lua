-- How strongly each race feels the cold and the heat. 1 is like a human. Keys are UnitRace's English names.
-- Fire spells in a fight burn a body with fireSpells.

local _, ns = ...

local function Body(cold, heat)
	return { cold = cold, heat = heat }
end

-- Dead flesh fears fire: a fire spell scorches it, not only fire underfoot.
local function Undead(body)
	body.fireSpells = true
	return body
end

ns.Races = {
	Human = Body(1, 1),
	Orc = Body(1, 1),
	Dwarf = Body(0.75, 1),
	NightElf = Body(1, 1),
	Scourge = Undead(Body(0.5, 0.6)),
	Tauren = Body(0.75, 1.15),
	Gnome = Body(1, 1),
	Troll = Body(1.2, 0.8),
	Skyborne = Body(1, 1), -- both factions
}

-- The undead choose how they feel: dead flesh that hardly feels the weather, or like everyone else. Numb is the default.
ns.UndeadFeel = {
	numb = ns.Races.Scourge,
	living = ns.Races.Human, -- also in fire
}
ns.UndeadFeelNames = { numb = "Numb", living = "Like the living" }
ns.UndeadFeelOrder = { "numb", "living" } -- as the settings list them

-- Forms with fur feel like a tauren. Keys are GetShapeshiftFormID's IDs.
ns.Fur = ns.Races.Tauren
ns.FurForms = {
	[1] = "Cat Form",
	[3] = "Travel Form",
	[4] = "Aquatic Form",
	[5] = "Bear Form",
	[8] = "Dire Bear Form",
	[31] = "Moonkin Form", -- feathers over fur
}
