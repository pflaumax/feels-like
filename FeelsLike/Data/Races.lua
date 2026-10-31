-- How strongly each race feels the cold and the heat. 1 is like a human. Keys are UnitRace's English names.

local _, ns = ...

local function Body(cold, heat)
	return { cold = cold, heat = heat }
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
