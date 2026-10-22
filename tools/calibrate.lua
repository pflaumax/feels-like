-- Prints the tooltip word for every Forever zone and instance at 15:00 and 05:00 (the warmest and the coldest hour), outdoors and dry.
-- Run from the project root: luajit tools/calibrate.lua

local ns = {}
for _, file in ipairs({ "Model.lua", "Data/Zones.lua", "Data/Instances.lua" }) do
	assert(loadfile("FeelsLike/" .. file))("FeelsLike", ns)
end
local Model = ns.Model

-- Names come from the comments next to each entry, read only inside the given table:
-- map IDs and area IDs overlap, so one name list per table.
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
		local state = { base = entry.base, climate = entry.climate, hour = hour, weatherIntensity = 0 }
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

Print("Forever zones", ns.Zones.forever, Names("FeelsLike/Data/Zones.lua", "ns.Zones.forever = {"))
Print("Subzones", ns.Zones.subzones, Names("FeelsLike/Data/Zones.lua", "ns.Zones.subzones = {"))
Print("Instances", ns.Instances, Names("FeelsLike/Data/Instances.lua", "ns.Instances = {"))
