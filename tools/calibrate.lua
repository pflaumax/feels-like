-- Prints the label for every Forever zone and instance by day and night. Run with luajit tools/calibrate.lua
-- Add a race to see how it feels, like luajit tools/calibrate.lua Scourge.

local ns = {}
for _, file in ipairs({ "Model.lua", "Data/Zones.lua", "Data/Instances.lua", "Data/Races.lua" }) do
	assert(loadfile("FeelsLike/" .. file))("FeelsLike", ns)
end
local Model = ns.Model

local race = arg and arg[1]
local body = race and ns.Races[race]
if race and not body then
	local known = {}
	for name in pairs(ns.Races) do
		known[#known + 1] = name
	end
	table.sort(known)
	io.stderr:write("Unknown race " .. race .. ". Known: " .. table.concat(known, ", ") .. "\n")
	os.exit(1)
end

-- Names come from the comments next to each entry.
local function Names(path, header)
	local names, inside = {}, false
	for line in io.lines(path) do
		if line:find(header, 1, true) then
			inside = true
		elseif inside and line:match("^}") then
			break
		elseif inside then
			local id, name = line:match("%[(%d+)%]%s*=.-%-%-%s*(.+)$")
			if id then
				names[tonumber(id)] = name
			end
		end
	end
	return names
end

local function Row(name, entry)
	local function At(hour)
		local state = { base = entry.base, climate = entry.climate, hour = hour, weatherIntensity = 0, body = body }
		local r = Model.Compute(state, 0)
		return string.format("%-9s %4d", Model.Band(r.target).word, math.floor(r.target + 0.5))
	end
	return string.format("  %-44s %-9s day %s   night %s", name, entry.climate, At(15), At(5))
end

local function Print(title, entries, names)
	print(title)
	local ids = {}
	for id in pairs(entries) do
		ids[#ids + 1] = id
	end
	table.sort(ids, function(a, b)
		return entries[a].base < entries[b].base
	end)
	for _, id in ipairs(ids) do
		print(Row(string.format("%s [%d]", names[id] or "?", id), entries[id]))
	end
end

if body then
	print(string.format("Race %s: cold x%.2f, heat x%.2f", race, body.cold, body.heat))
end
Print("Forever zones", ns.Zones.forever, Names("FeelsLike/Data/Zones.lua", "ns.Zones.forever = {"))
Print("Subzones", ns.Zones.subzones, Names("FeelsLike/Data/Zones.lua", "ns.Zones.subzones = {"))
Print("Instances", ns.Instances, Names("FeelsLike/Data/Instances.lua", "ns.Instances = {"))
