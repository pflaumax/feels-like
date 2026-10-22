-- Loads the whole addon against stubbed WoW API and runs a few scenarios.
-- It catches runtime errors and wrong wiring; it does not prove anything about rendering.
-- Run from the project root: luajit tests/smoke_test.lua

local failures = 0
local function check(name, condition, detail)
	if not condition then
		failures = failures + 1
		io.write("FAIL " .. name .. (detail and (": " .. tostring(detail)) or "") .. "\n")
	end
end

-- Font strings by template, so tests can find the label; every frame CreateFrame made;
-- VectorGraphics layers in creation order. svg.supported and svg.result control the SVG stubs; files named
-- in svg.missing fail to load, like art added after the game started.
local fontStrings = {}
local createdFrames = {}
local vectorLayers = {}
local svg = { supported = true, result = true, missing = {} }

-- Generic widget: any unknown method is a no-op. Scripts, points, visibility and mouse state are kept.
local function Widget()
	local widget = { scripts = {}, scale = 1, shown = true }
	widget.SetScript = function(self, name, fn) self.scripts[name] = fn end
	widget.GetScript = function(self, name) return self.scripts[name] end
	widget.hooks = {}
	widget.HookScript = function(self, name, fn) self.hooks[name] = fn end
	widget.SetScale = function(self, s) self.scale = s end
	widget.GetScale = function(self) return self.scale end
	widget.GetCenter = function() return 500, 300 end
	widget.CreateTexture = function() return Widget() end
	widget.CreateMaskTexture = function() return Widget() end
	widget.CreateLine = function() return Widget() end
	widget.CreateFontString = function(_, _, _, template)
		local fontString = Widget()
		fontStrings[template] = fontString
		return fontString
	end
	widget.SetPoint = function(self, ...) self.point = { ... } end
	widget.Show = function(self) self.shown = true end
	widget.Hide = function(self) self.shown = false end
	widget.EnableMouse = function(self, enabled) self.mouse = enabled end
	widget.StartMoving = function(self) self.moving = true end
	widget.GetEffectiveScale = function() return 1 end
	widget.GetWidth = function() return 198 end
	widget.SetAlpha = function(self, alpha) self.alpha = alpha end
	widget.SetSVG = function(self, path) self.svg = path return svg.result and not svg.missing[path:match("[^\\]+$")] end
	-- false, not nil: the metatable would turn a missing method into a no-op function.
	widget.CreateVectorGraphics = svg.supported and function()
		local layer = Widget()
		vectorLayers[#vectorLayers + 1] = layer
		return layer
	end or false
	widget.SetText = function(self, text) self.text = text end
	widget.events = {}
	widget.RegisterEvent = function(self, event) self.events[event] = true end
	widget.RegisterUnitEvent = function(self, event) self.events[event] = true end
	return setmetatable(widget, { __index = function() return function() end end })
end

-- World state the stubs read. Scenarios change it.
local world

local function ResetWorld()
	world = {
		mapID = 1426, zoneText = "Dun Morogh", subzoneText = "",
		instance = { "Dun Morogh", "none", 0, "", 0, 0, false, 0 },
		hour = 5, minute = 0, -- the coldest hour
		weather = { type = 2, intensity = 1 },
		indoors = false, resting = false, swimming = false,
		auras = {},
		time = 1000, combat = false,
		pos = { x = 0, y = 0, map = 0 }, speed = 0,
		hands = {}, -- item IDs by inventory slot
	}
end
ResetWorld()

local printed = {}
local timers, tickers = {}, {}
local loadedCallback

local function InstallGlobals(forever)
	_G.print = function(...) local parts = {} for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end printed[#printed + 1] = table.concat(parts, " ") end
	_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	_G.strsplit = function(sep, s, limit)
		local out, start = {}, 1
		while true do
			if limit and #out == limit - 1 then out[#out + 1] = s:sub(start) break end
			local i = s:find(sep, start, true)
			if not i then out[#out + 1] = s:sub(start) break end
			out[#out + 1] = s:sub(start, i - 1)
			start = i + #sep
		end
		return unpack(out)
	end

	_G.UIParent = Widget()
	_G.GameTooltip = Widget()
	_G.GameTooltip.IsOwned = function() return false end
	_G.CreateFrame = function(_, name)
		local frame = Widget()
		createdFrames[#createdFrames + 1] = frame
		if name then _G[name] = frame end
		return frame
	end
	_G.Minimap = Widget()
	_G.InCombatLockdown = function() return world.combat end
	_G.GetTime = function() return world.time end
	_G.UnitPosition = function() return world.pos.y, world.pos.x, 0, world.pos.map end
	_G.GetUnitSpeed = function() return world.speed end
	_G.GetInventoryItemID = function(_, slot) return world.hands[slot] end
	_G.IsShiftKeyDown = function() return world.shift end
	_G.SlashCmdList = {}

	_G.EventUtil = { ContinueOnAddOnLoaded = function(_, fn) loadedCallback = fn end }
	_G.C_Timer = {
		After = function(_, fn) timers[#timers + 1] = fn end,
		NewTicker = function(_, fn) tickers[#tickers + 1] = fn end,
	}
	_G.C_EventUtils = { IsEventValid = function(event) return event ~= "WEATHER_CHANGED" or forever end }

	local parents = { [1426] = 1415, [1415] = 947, [427] = 27 }
	_G.C_Map = {
		GetBestMapForUnit = function() return world.mapID end,
		GetMapInfo = function(id) return { parentMapID = parents[id] or 0 } end,
		GetAreaInfo = function(id) return ({ [439] = "The Shimmering Flats", [537] = "Fire Plume Ridge" })[id] end,
	}
	_G.GetInstanceInfo = function() return unpack(world.instance) end
	_G.GetGameTime = function() return world.hour, world.minute end
	_G.GetZoneText = function() return world.zoneText end
	_G.GetSubZoneText = function() return world.subzoneText end
	_G.IsIndoors = function() return world.indoors end
	_G.IsResting = function() return world.resting end
	_G.IsSwimming = function() return world.swimming end
	_G.C_UnitAuras = {
		GetPlayerAuraBySpellID = function(id) return world.auras[id] end,
		GetAuraDataByIndex = function(_, index)
			local list = {}
			for id, aura in pairs(world.auras) do
				if not aura.hidden then list[#list + 1] = { name = "Aura " .. id, spellId = id } end
			end
			table.sort(list, function(a, b) return a.spellId < b.spellId end)
			return list[index]
		end,
	}
	_G.issecretvalue = function() return false end

	if forever then
		_G.WOW_PROJECT_CAMELOT = 18
		_G.WOW_PROJECT_ID = 18
		_G.Enum = { WeatherType = { Clear = 0, Rain = 1, Snow = 2, Sandstorm = 3, Miscellaneous = 4 } }
		_G.C_Weather = { GetCurrentWeather = function() return world.weather end }
		_G.C_DateAndTime = { IsDayTime = function() return world.hour >= 6 and world.hour < 18 end }
	else
		_G.C_DateAndTime = nil
		_G.WOW_PROJECT_CAMELOT = nil
		_G.WOW_PROJECT_ID = 1
		_G.Enum = {}
		_G.C_Weather = nil
	end

	local settings = {}
	_G.Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function() return { GetID = function() return 7 end }, Widget() end,
		RegisterAddOnSetting = function(_, variable, key, tbl, _, _, default)
			if tbl[key] == nil then tbl[key] = default end
			local setting = { variable = variable }
			setting.SetValueChangedCallback = function(self, fn) self.callback = fn end
			settings[variable] = setting
			return setting
		end,
		CreateDropdown = function(_, _, options) options() end,
		CreateCheckbox = function() end,
		CreateSlider = function() end,
		CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
		CreateControlTextContainer = function()
			local data = {}
			return { Add = function(_, value, label) data[#data + 1] = { value = value, label = label } end, GetData = function() return data end }
		end,
		RegisterAddOnCategory = function() end,
		OpenToCategory = function(id) settings.opened = id end,
	}
	_G.MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }
	_G.CreateSettingsButtonInitializer = function() return {} end
	return settings
end

-- Loads every file listed in the TOC, in order, with a fresh namespace.
-- saved: the FeelsLikeDB the game loads from disk (nil: a new install).
local function LoadAddon(forever, saved)
	ResetWorld()
	_G.FeelsLikeDB = saved
	printed, timers, tickers, loadedCallback = {}, {}, {}, nil
	createdFrames, vectorLayers = {}, {}
	local settings = InstallGlobals(forever)
	local ns = {}
	for line in io.lines("FeelsLike/FeelsLike.toc") do
		if line ~= "" and not line:find("^##") then
			local path = "FeelsLike/" .. line:gsub("\\", "/")
			assert(loadfile(path))("FeelsLike", ns)
		end
	end
	check("loaded callback registered", loadedCallback ~= nil)
	loadedCallback()
	return ns, settings
end

local function Tick(seconds)
	for _ = 1, seconds do
		world.time = world.time + 1
		for _, fn in ipairs(tickers) do fn() end
	end
end

-- Runs the timers that are due now (C_Timer.After(0, ...) runs on the next frame).
local function NextFrame()
	local pending = timers
	timers = {}
	for _, fn in ipairs(pending) do fn() end
end

-- The Core event frame is the one listening to UNIT_COMBAT.
local function CoreEvent(event, ...)
	for _, frame in ipairs(createdFrames) do
		if frame.events.UNIT_COMBAT then
			frame.scripts.OnEvent(frame, event, ...)
			return true
		end
	end
	return false
end

-- Fire damage to the player, then the next frame, where Core confirms it outside combat.
local function FireHit(schoolMask)
	local delivered = CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 120, schoolMask or 4)
	NextFrame()
	return delivered
end

local function Slash(text)
	printed = {}
	SlashCmdList.FEELSLIKE(text)
	return table.concat(printed, "\n")
end

-- Forever client ---------------------------------------------------------------

local ns, settings = LoadAddon(true)
local Gauge = ns.Gauge

check("forever detected", ns.Sensors.isForever)
check("vector renderer", ns.Gauge.renderer == "vector", ns.Gauge.renderer)
check("9 layers plus 91 needles", #vectorLayers == 100, #vectorLayers)
local function LayerBySvg(suffix)
	for _, layer in ipairs(vectorLayers) do
		if layer.svg and layer.svg:sub(-#suffix) == suffix then
			return layer
		end
	end
end
local function VisibleNeedles()
	local visible = {}
	for _, layer in ipairs(vectorLayers) do
		if layer.svg and layer.svg:find("Needle", 1, true) and layer.alpha == 1 then
			visible[#visible + 1] = layer.svg:match("(%d%d)%.svg$")
		end
	end
	return visible
end
local unitLayer, ringIcy, faceHot = LayerBySvg("unit_c.svg"), LayerBySvg("ring_icy.svg"), LayerBySvg("face_hot.svg")
check("needles loaded once, one visible", #VisibleNeedles() == 1, table.concat(VisibleNeedles(), ","))
check("svg path", vectorLayers[1].svg == "Interface\\AddOns\\FeelsLike\\Media\\face.svg", vectorLayers[1].svg)
-- Every SVG the dial loads exists on disk, so NEEDLE_STEPS matches the generated needle files.
for _, layer in ipairs(vectorLayers) do
	local path = layer.svg:gsub("^Interface\\AddOns\\", ""):gsub("\\", "/")
	local file = io.open(path)
	check("svg file exists", file ~= nil, path)
	if file then
		file:close()
	end
end
check("defaults saved", FeelsLikeDB.unit == "C" and FeelsLikeDB.label == "hover" and FeelsLikeDB.locked == false and FeelsLikeDB.scale == 0.53)
check("one ticker", #tickers == 1, #tickers)

-- Dun Morogh, 05:00, full snow, outdoors: -60 - 8 - 20 = -88.
check("dun morogh night snow", math.abs(Gauge.target - (-88)) < 0.01, Gauge.target)
check("dun morogh word", ns.Model.Band(Gauge.target, Gauge.cozy).word == "Freezing")

-- The needle glides through OnUpdate and swaps to the matching pre-rotated SVG (-88 is step 5).
local gaugeFrame = _G.FeelsLikeGauge
local needleFiles = {}
for _, layer in ipairs(vectorLayers) do
	if layer.svg and layer.svg:find("Needle", 1, true) then
		needleFiles[layer] = layer.svg
	end
end
local alwaysOneNeedle, filesNeverReloaded = true, true
for _ = 1, 60 do
	local onUpdate = gaugeFrame.scripts.OnUpdate
	if not onUpdate then break end -- the gauge removes it once the needle settles
	onUpdate(gaugeFrame, 0.05)
	alwaysOneNeedle = alwaysOneNeedle and #VisibleNeedles() == 1
	for layer, file in pairs(needleFiles) do
		filesNeverReloaded = filesNeverReloaded and layer.svg == file
	end
end
check("exactly one needle visible during the glide", alwaysOneNeedle)
check("needle layers never load a new file", filesNeverReloaded)
check("needle stops updating once settled", gaugeFrame.scripts.OnUpdate == nil)
check("needle settled", Gauge.display == Gauge.target, Gauge.display)
check("needle at step 05", VisibleNeedles()[1] == "05", table.concat(VisibleNeedles(), ","))
check("icy ring shown", ringIcy.alpha and math.abs(ringIcy.alpha - 0.6) < 0.01, ringIcy.alpha)
check("hot face hidden", faceHot.alpha == 0, faceHot.alpha)
ns.Gauge:SetUnit("F")
check("unit svg", unitLayer.svg:find("unit_f.svg", 1, true), unitLayer.svg)
ns.Gauge:SetUnit("C")

local debugText = Slash("debug")
check("debug mentions Forever", debugText:find("Forever client", 1, true), debugText)
check("debug shows weather", debugText:find("weather: snow", 1, true), debugText)
check("debug shows place", debugText:find("Dun Morogh (map 1426)", 1, true), debugText)

check("debug shows game day/night", debugText:find("(game: night)", 1, true), debugText)
check("debug shows renderer", debugText:find("renderer: vector", 1, true), debugText)
check("debug shows position", debugText:find("position: default", 1, true), debugText)
-- 50 px left of and 50 px below the minimap center: 225 degrees, 70.7 / 99 = 0.71 of the radius.
local gaugeForPosition = _G.FeelsLikeGauge
gaugeForPosition.GetCenter = function() return 450, 250 end
check("position angle and distance", ns.Gauge:DescribePosition():find("225 degrees from 12 o'clock, 0.71 of the minimap radius", 1, true),
	ns.Gauge:DescribePosition())
gaugeForPosition.GetCenter = function() return 500, 300 end

-- Forever's default place: the mirror image of the day/night button, which Blizzard anchors 55 right and
-- 86 up from the minimap center; offsets divided by Forever's 0.53 scale. The ring is bronze, like Forever's minimap.
local gauge = _G.FeelsLikeGauge
local point = gauge.point
local expectedX = -55 / 0.53
local expectedY = 86 / 0.53
check("anchored to minimap", point and point[2] == _G.Minimap, point and tostring(point[2]))
check("minimap offset", point and math.abs(point[4] - expectedX) < 0.01 and math.abs(point[5] - expectedY) < 0.01,
	point and (point[4] .. ", " .. point[5]))
check("bronze ring in forever", LayerBySvg("ring_bronze.svg") ~= nil and LayerBySvg("ring_gold.svg") == nil)
local ringBronze, ringClassic = LayerBySvg("ring_bronze.svg"), LayerBySvg("ring_classic.svg")
local function RingsShown()
	return tostring(ringBronze.alpha) .. ", " .. tostring(ringClassic.alpha)
end
check("bronze ring shown by Blizzard's minimap", ringBronze.alpha == 1 and ringClassic.alpha == 0, RingsShown())

-- A classic-style minimap (ClassicUI Forever) is 140 wide. Once the minimap takes that size, the gauge goes
-- under its ring, 55 left of and 90 below its center, and wears the classic buttons' ring.
_G.Minimap.GetWidth = function() return 140 end
_G.Minimap.hooks.OnSizeChanged()
point = gauge.point
check("classic minimap offset", point and point[2] == _G.Minimap and math.abs(point[4] - -55 / 0.53) < 0.01
	and math.abs(point[5] - -90 / 0.53) < 0.01, point and (point[4] .. ", " .. point[5]))
check("classic ring shown", ringClassic.alpha == 1 and ringBronze.alpha == 0, RingsShown())
debugText = Slash("debug")
check("debug names the classic-style minimap", debugText:find("position: default, classic-style minimap;", 1, true), debugText)
-- There the word goes left, away from the coordinates line under the map.
gauge.GetCenter = function() return 445, 210 end
ns.Gauge:ApplyPosition()
check("word left of the gauge under a classic minimap", fontStrings.GameFontHighlightSmall.point[1] == "RIGHT",
	fontStrings.GameFontHighlightSmall.point[1])
gauge.GetCenter = function() return 500, 300 end
-- A moved gauge stays where it was put, but its ring still follows the minimap.
FeelsLikeDB.x, FeelsLikeDB.y = 100, 50
ns.Gauge:ApplyPosition()
check("moved gauge keeps its place by a classic minimap", gauge.point[2] == _G.UIParent and ringClassic.alpha == 1,
	RingsShown())
FeelsLikeDB.x, FeelsLikeDB.y = nil, nil
-- Back to Blizzard's minimap (the addon's minimap switched off): the mirror place and bronze again.
_G.Minimap.GetWidth = function() return 198 end
_G.Minimap.hooks.OnSizeChanged()
point = gauge.point
check("back to the mirror place", point and math.abs(point[4] - expectedX) < 0.01 and math.abs(point[5] - expectedY) < 0.01,
	point and (point[4] .. ", " .. point[5]))
check("back to the bronze ring", ringBronze.alpha == 1 and ringClassic.alpha == 0, RingsShown())

-- The word sits on the side away from the minimap (the minimap is 198 wide, its center at 500, 300).
local wordLabel = fontStrings.GameFontHighlightSmall
local function LabelSideAt(x, y)
	gauge.GetCenter = function() return x, y end
	ns.Gauge:ApplyPosition()
	return wordLabel.point[1]
end
check("word left of a gauge at the upper left", LabelSideAt(440, 390) == "RIGHT", wordLabel.point[1])
check("word right of a gauge at the right", LabelSideAt(600, 300) == "LEFT", wordLabel.point[1])
check("word above a gauge over the minimap", LabelSideAt(490, 410) == "BOTTOM", wordLabel.point[1])
check("word below a gauge under the minimap", LabelSideAt(510, 190) == "TOP", wordLabel.point[1])
check("word below a gauge far away", LabelSideAt(100, 900) == "TOP", wordLabel.point[1])
-- The minimap moves after the gauge was placed (another addon): the word follows when it shows.
gauge.GetCenter = function() return 440, 390 end
ns.Gauge:ApplyPosition()
_G.Minimap.GetCenter = function() return 300, 390 end
gauge.scripts.OnEnter()
check("word side follows a moved minimap", wordLabel.point[1] == "LEFT", wordLabel.point[1])
gauge.scripts.OnLeave()
_G.Minimap.GetCenter = function() return 500, 300 end
gauge.GetCenter = function() return 500, 300 end
ns.Gauge:ApplyPosition()

-- /feels measure: where a minimap button sits, by its case-sensitive frame name.
_G.MoonButton = Widget()
_G.MoonButton.GetCenter = function() return 554, 383 end -- 33 degrees, 1.00 radius
_G.MoonButton.GetWidth = function() return 36 end
local measured = Slash("measure MoonButton")
check("measure a frame", measured:find("MoonButton: 33 degrees from 12 o'clock, 1.00 of the minimap radius from its center, as wide as the gauge at scale 0.50", 1, true), measured)
check("measure an unknown frame", Slash("measure NoSuchFrame"):find("no frame named NoSuchFrame", 1, true))
-- A frame without a global name, by its path from a named one (like MinimapCluster.DielFrame).
_G.MoonCluster = { Moon = _G.MoonButton }
measured = Slash("measure MoonCluster.Moon")
check("measure a frame by path", measured:find("MoonCluster.Moon: 33 degrees from 12 o'clock", 1, true), measured)
check("measure an unknown path", Slash("measure MoonCluster.Sun"):find("no frame named MoonCluster.Sun", 1, true))
check("measure a path through a value", Slash("measure MoonCluster.Moon.GetWidth.x"):find("no frame named", 1, true))
_G.MoonButton, _G.MoonCluster = nil, nil

-- The word: hidden until hover, then the current band word.
local label = fontStrings.GameFontHighlightSmall
check("label exists", label ~= nil)
check("label hidden before hover", label.shown == false)
gauge.scripts.OnEnter()
check("label on hover", label.shown and label.text == "Freezing", label.text)
gauge.scripts.OnLeave()
check("label hidden after hover", label.shown == false)
settings.FEELSLIKE_LABEL.callback(nil, "always")
check("label always", label.shown == true)
settings.FEELSLIKE_LABEL.callback(nil, "hover")
check("label back to hover", label.shown == false and FeelsLikeDB.label == "hover")

-- Moving needs Shift and an unlocked gauge.
gauge.moving = false
world.shift = false
gauge.scripts.OnDragStart(gauge)
check("no move without shift", not gauge.moving)
world.shift = true
gauge.scripts.OnDragStart(gauge)
check("shift drag moves", gauge.moving)
gauge.scripts.OnDragStop(gauge)
check("drag saves position", FeelsLikeDB.x ~= nil and gauge.point[2] == _G.UIParent)
ns.Gauge:ResetPosition()
check("reset back to minimap", FeelsLikeDB.x == nil and gauge.point[2] == _G.Minimap)
gauge.moving = false
ns.Gauge:SetLocked(true)
gauge.scripts.OnDragStart(gauge)
check("locked does not move", not gauge.moving)
world.shift = false
check("mouse on while label shows on hover", gauge.mouse == true)
FeelsLikeDB.label = "never"
ns.Gauge:SetLabelMode("never")
check("locked without label lets clicks through", gauge.mouse == false)
FeelsLikeDB.label = "always"
ns.Gauge:SetLabelMode("always")
check("locked with the word always shown lets clicks through", gauge.mouse == false)
FeelsLikeDB.locked, FeelsLikeDB.label = false, "hover"
ns.Gauge:SetLocked(false)
ns.Gauge:SetLabelMode("hover")
check("mouse back on", gauge.mouse == true)

-- A plain drag (no Shift) saves nothing: the gauge stays on the minimap.
world.shift = false
gauge.scripts.OnDragStart(gauge)
gauge.scripts.OnDragStop(gauge)
check("plain drag saves nothing", FeelsLikeDB.x == nil and gauge.point[2] == _G.Minimap)

-- Hovered, then the mouse is switched off (locked, no word): the hover state must not stick.
gauge.scripts.OnEnter()
FeelsLikeDB.locked, FeelsLikeDB.label = true, "never"
ns.Gauge:SetLocked(true)
ns.Gauge:SetLabelMode("never")
FeelsLikeDB.locked, FeelsLikeDB.label = false, "hover"
ns.Gauge:SetLocked(false)
ns.Gauge:SetLabelMode("hover")
check("hover does not stick", label.shown == false)

-- /feels auras lists buffs and marks campfire ones.
world.auras[7353] = { spellId = 7353 }
world.auras[1459] = { spellId = 1459 }
local aurasText = Slash("auras")
check("auras lists buffs", aurasText:find("Aura 1459 (1459)", 1, true), aurasText)
check("auras marks campfire", aurasText:find("Aura 7353 (7353) - counts as campfire", 1, true), aurasText)
for id = 1, 44 do -- more than 40 buffs: the campfire one is 46th
	world.auras[id] = { spellId = id }
end
check("auras lists past 40", Slash("auras"):find("(7353) - counts as campfire", 1, true))
world.auras = {}
check("auras none", Slash("auras"):find("none", 1, true))
world.auras[1232234] = { spellId = 1232234, name = "Cozy Fire", hidden = true }
aurasText = Slash("auras")
check("a hidden fire aura alone is not none", not aurasText:find("none", 1, true) and aurasText:find("(1232234)", 1, true), aurasText)
world.auras = {}

-- A map missing from the table and without a known parent counts as a neutral temperate zone.
world.mapID = 9999
Tick(1)
-- 05:00, full snow: 0 - 30 (a temperate night) - 20.
check("unknown map falls back to 0", math.abs(Gauge.target - (0 - 30 - 20)) < 0.01, Gauge.target)

-- Walking into the Westfall inn at 15:00, no weather. Outside: 10 + 10 = 20. A plain building would
-- be 15 + (20 - 15) * 0.4 = 17, the inn 22 + (20 - 22) * 0.1 = 21.8. The game reports indoors before
-- resting; the needle must not dip to the plain-building value on the way in.
world.mapID, world.zoneText = 1436, "Westfall"
world.hour, world.weather = 15, { type = 0, intensity = 0 }
Tick(1)
local outside = Gauge.target
check("westfall afternoon outside", math.abs(outside - 20) < 0.01, outside)
local lowest = outside
world.indoors = true
for _ = 1, 2 do -- resting arrives two ticks after indoors
	Tick(1)
	lowest = math.min(lowest, Gauge.target)
end
world.resting = true
for _ = 1, 4 do
	Tick(1)
	lowest = math.min(lowest, Gauge.target)
end
check("no dip at the inn door", lowest >= outside - 0.01, lowest)
check("inn value", math.abs(Gauge.target - 21.8) < 0.01, Gauge.target)
check("inn cozy", Gauge.cozy == true)

-- Capital city outdoors is a rest area but not an inn.
world.indoors = false
Tick(3)
check("resting outdoors is not cozy", Gauge.cozy == false)
world.resting = false
Tick(3)

-- The Undercity is underground as a whole: indoors and resting everywhere, yet its own value counts,
-- not an inn.
world.mapID, world.zoneText = 1458, "Undercity"
world.indoors, world.resting = true, true
Tick(3)
check("undercity keeps its own value", math.abs(Gauge.target - (-20)) < 0.01, Gauge.target)
check("undercity is not cozy", Gauge.cozy == false)
debugText = Slash("debug")
check("debug says inside as a whole", debugText:find("inside as a whole, no shelter", 1, true), debugText)
-- Out through the city gate into Tirisfal at 15:00 (-15 + 10): the city's reading does not linger
-- for the shelter delay.
world.mapID, world.zoneText = 1420, "Tirisfal Glades"
world.indoors, world.resting = false, false
Tick(1)
check("no inn reading after the undercity", Gauge.cozy == false and Gauge.target < 15, Gauge.target)
Tick(2) -- the usual door delay, then outdoors
check("outdoors after the undercity", math.abs(Gauge.target - (-5)) < 0.01, Gauge.target)

-- A building that is not an inn (the Goldshire smithy): not colder than a mild afternoon outside,
-- warmer than the night outside. Elwynn at 15:00 is 15 outside.
world.mapID, world.zoneText = 1429, "Elwynn Forest"
Tick(1)
world.indoors = true
Tick(3)
check("building on a mild afternoon", math.abs(Gauge.target - 15) < 0.01, Gauge.target)
world.hour = 5
Tick(1)
check("building at night is warmer", math.abs(Gauge.target - (-1)) < 0.01, Gauge.target) -- outside -25
world.indoors, world.hour = false, 15
Tick(3)

-- After a loading screen (hearth into an inn) the new place counts at once.
world.indoors, world.resting = true, true
CoreEvent("PLAYER_ENTERING_WORLD")
check("hearth into inn counts at once", math.abs(Gauge.target - 21.3) < 0.01, Gauge.target)
world.indoors, world.resting = false, false
CoreEvent("PLAYER_ENTERING_WORLD")

-- Swimming in Tanaris at noon soaks, then clothes dry.
world.mapID, world.zoneText, world.hour = 1446, "Tanaris", 15
world.swimming = true
Tick(1)
Tick(1)
local soaked = Gauge.target
check("soaked is colder than dry tanaris", soaked < 75 + 35 - 1, soaked)
world.swimming = false
Tick(120)
check("dried in the heat", math.abs(Gauge.target - 100) < 0.01, Gauge.target)

-- Soaked, then a 20 s loading screen into an inn. That time counts where you were (Elwynn at 15:00 is
-- 15, so clothes dry in 90 s): 1 - 20 / 90 = 0.78 left, not the inn's fast drying.
world.mapID, world.zoneText = 1429, "Elwynn Forest"
world.swimming = true
Tick(2)
-- In the water on a mild afternoon: 15 - 0.5 * (15 + 100) = -42.5, Cold.
check("swimming on a mild day is cold", math.abs(Gauge.target - (-42.5)) < 0.01, Gauge.target)
world.swimming = false
Tick(1)
world.time = world.time + 20
world.indoors, world.resting = true, true
CoreEvent("PLAYER_ENTERING_WORLD")
debugText = Slash("debug")
check("loading time dries where you were", debugText:find("wetness 0.78", 1, true), debugText)
world.indoors, world.resting = false, false
CoreEvent("PLAYER_ENTERING_WORLD")

-- Rain outdoors keeps clothes damp.
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
world.weather = { type = 1, intensity = 1 }
Tick(200)
-- 5 + 10 - 12 = 3 env; wetness settles at 0.4, which takes 0.4 * 0.5 of the 103 above -100: 3 - 20.6.
check("rain keeps damp", math.abs(Gauge.target - (-17.6)) < 0.01, Gauge.target)

-- The loading screens above must be over for the campfire scenarios: more than 5 s without an aura.
Tick(6)

-- Campfire in Dun Morogh at noon: -60 + 7.07 - 20 (snow) + 35, outdoors.
world.weather = { type = 0, intensity = 0 }
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 12
world.auras[7353] = { spellId = 7353 }
Tick(200)
check("campfire warms", Gauge.target > -60 + 30, Gauge.target)
-- Walked away: the 60 s aura was last renewed 10 s ago, so its warmth is gone.
world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = world.time + 50 }
Tick(1)
check("aging campfire aura gives no warmth", Gauge.target < -40, Gauge.target)
-- Straight into an inn with the aura still on: cozy, not hot.
world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = world.time + 59 }
world.indoors, world.resting = true, true
Tick(3)
check("inn with campfire aura is cozy", Gauge.cozy == true and Gauge.target < 33, Gauge.target)
world.indoors, world.resting = false, false
world.auras[7353] = nil
Tick(3) -- the aura is gone: this fire is over; outdoors again

-- A fire that renews Cozy Fire every 6 s. Once the gap is measured, standing by it stays fully warm
-- between renewals, and walking away still cools down within the gap plus a few seconds.
local function Renew()
	world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = world.time + 60 }
end
local fullyWarm = -60 + 8 * math.cos(2 * math.pi * (12 - 15) / 24) + 35
local awayFromFire = fullyWarm - 35
Renew()
Tick(1)
for _ = 1, 3 do
	Tick(5)
	Renew()
	Tick(1)
end
Tick(5) -- 6 s after the last renewal
check("slow fire stays fully warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug shows renewal gap", debugText:find("every 6.0 s", 1, true), debugText)
Tick(6) -- 12 s after the last renewal, no renewal since
check("slow fire cools within 12 s", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
-- Coming back after 12 s is not a 12 s beat: the measured gap stays 6 s.

-- In combat aura data is secret: warmth must still fade instead of holding the last value.
Renew()
Tick(1)
check("by the fire again", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
check("gap still 6 s after stepping away", Slash("debug"):find("every 6.0 s", 1, true))
local realIsSecret = _G.issecretvalue
_G.issecretvalue = function(value) return type(value) == "table" and value.spellId == 7353 end
for _ = 1, 13 do
	Tick(1)
	Renew() -- the fire keeps renewing, but the addon cannot see it
end
check("secret aura does not linger", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
_G.issecretvalue = realIsSecret
-- A client may hide only the aura's fields, not the table: the same as a hidden aura.
Renew()
Tick(1)
check("by the fire before hidden fields", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
_G.issecretvalue = function(value) return value == 60 end -- the aura's duration
for _ = 1, 13 do
	Tick(1)
	Renew()
end
check("secret aura fields do not linger", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
_G.issecretvalue = function(value) return value == 7353 end -- the buff's spell ID
check("auras with a secret spell ID", Slash("auras"):find("hidden while auras are restricted", 1, true))
_G.issecretvalue = realIsSecret
world.auras[7353] = nil
Tick(1)
check("gap forgotten once the aura is gone", not Slash("debug"):find("every", 1, true))

-- An aura without a timer (Retail gives addons none for Cozy Fire): freshness cannot tell, and the
-- aura stays up to a minute after you leave. Distance from where you stood by the fire decides.
world.pos, world.speed = { x = 100, y = 100, map = 0 }, 7
world.auras[7353] = { spellId = 7353, auraInstanceID = 501 } -- appears at the edge of its reach
Tick(1)
world.pos, world.speed = { x = 108, y = 100, map = 0 }, 0 -- you stop by the fire
Tick(1)
check("untimed aura by the fire", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug shows distance", debugText:find("0.0 yd from where you stood by it", 1, true), debugText)
world.pos, world.speed = { x = 102, y = 100, map = 0 }, 7 -- around the fire, still within reach
Tick(1)
check("moving around the fire stays warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos = { x = 125, y = 100, map = 0 } -- 17 yd from where you stood: gone
Tick(1)
Tick(5)
check("walked away cools in seconds", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.pos = {} -- the game hides the position (an instance): the fire you left stays left
Tick(1)
check("hidden position keeps you away", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.pos, world.speed = { x = 109, y = 101, map = 0 }, 0 -- back to the fire, aura still on
Tick(1)
check("back by the fire warms again", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos = { x = 108, y = 100, map = 1 } -- hearth to another continent with the aura still on
Tick(5)
check("another map counts as gone", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug says far", debugText:find("far from the fire", 1, true), debugText)
-- Hearth with the aura still on. The fire renewed the aura just before the loading screen, and after
-- it the client may renumber the aura or drop it for a moment: none of that is a fire at the
-- destination, and you arrive cold, not fading.
world.pos = { x = 108, y = 100, map = 0 }
Tick(1)
check("by the fire before the hearth", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } })
world.pos = { x = 900, y = 40, map = 0 }
CoreEvent("PLAYER_ENTERING_WORLD")
check("arrive away from the fire", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } }) -- the client refreshing its aura data
Tick(1)
check("aura refresh after a loading screen is no renewal", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.auras[7353] = { spellId = 7353, auraInstanceID = 601 }
Tick(1)
world.auras[7353] = nil
Tick(1)
world.auras[7353] = { spellId = 7353, auraInstanceID = 602 }
Tick(3)
check("same aura after a loading screen is not a new fire", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
-- A fire here renews the aura on its next beat: now it warms.
Tick(1)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 602 } })
Tick(1)
check("a fire after the loading screen warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
-- A /reload (or a login) by the fire leaves you there.
CoreEvent("PLAYER_ENTERING_WORLD", false, true)
Tick(1)
check("reload by the fire stays warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
-- The position hidden for a while, at a new fire (new aura). Once the position is back, that fire is
-- where you are, not the last fire's spot.
world.pos = {}
world.auras[7353] = { spellId = 7353, auraInstanceID = 603 }
Tick(1)
world.pos = { x = 500, y = 500, map = 0 }
Tick(5)
check("a fire found without a position anchors where you are", math.abs(Gauge.target - fullyWarm) < 0.01,
	Gauge.target)

-- Into an instance (no position) and out again: a fire you sat by inside does not follow you out.
world.pos = {}
CoreEvent("PLAYER_ENTERING_WORLD")
Tick(6)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 603 } }) -- a fire inside renews it
Tick(1)
check("fire inside an instance warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos = { x = 300, y = 300, map = 0 }
CoreEvent("PLAYER_ENTERING_WORLD")
Tick(1)
check("an instance fire stays behind", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(6) -- the aura is gone, long enough after the loading screen

-- A new fire (new aura) anchors anew, even far from the last one.
world.auras[7353] = { spellId = 7353, auraInstanceID = 777 }
Tick(1)
check("new fire warms where you are", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.auras[7353] = nil
Tick(1)

-- A timed aura (6 s beat), then a hearth. The client refreshing the aura's data afterwards (UNIT_AURA)
-- is no renewal: the timer tells. The first renewal where you arrive starts the beat afresh, so a gap
-- across the loading screen is never learned as a beat.
local function Renew700()
	world.auras[7353] = { spellId = 7353, auraInstanceID = 700, duration = 60, expirationTime = world.time + 60 }
end
Renew700()
Tick(1)
Tick(5)
Renew700()
Tick(1)
check("timed fire beat before the hearth", Slash("debug"):find("every 6.0 s", 1, true))
world.pos = { x = 900, y = 900, map = 0 }
CoreEvent("PLAYER_ENTERING_WORLD")
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 700 } })
Tick(1)
check("aura refresh after a hearth is no renewal", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
Renew700() -- a fire here, 2 s after the last renewal at the old one
Tick(1)
check("first renewal after the hearth warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
Tick(7)
Renew700() -- this fire renews every 8 s
Tick(1)
check("beat measured afresh after the hearth", Slash("debug"):find("every 8.0 s", 1, true))
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(6)

-- Two fires 15 yd apart, one aura without a timer. Fire B renews the same aura, and the game reports
-- that in UNIT_AURA: the anchor moves to fire B.
world.auras[7353] = { spellId = 7353, auraInstanceID = 900 }
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)
world.pos, world.speed = { x = 15, y = 0, map = 0 }, 7
Tick(1)
world.speed = 0
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 900 } })
Tick(1)
check("second fire warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos, world.speed = { x = 40, y = 0, map = 0 }, 7
Tick(6)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 12345 } }) -- some other aura
Tick(1)
check("other aura updates do not count", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
local secretIsSecret = _G.issecretvalue
_G.issecretvalue = function(value) return type(value) == "table" and value.updatedAuraInstanceIDs ~= nil end
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 900 } })
_G.issecretvalue = secretIsSecret
Tick(1)
check("secret aura updates ignored", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
_G.issecretvalue = function(value) return type(value) == "table" and value[1] == 900 end -- only the ID list
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 900 } })
_G.issecretvalue = secretIsSecret
Tick(1)
check("secret aura ID list ignored", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)

-- Timed aura: away long enough to start over, then back at the fire from its other side,
-- 15 yd from where you stood before. The first renewal after the reset moves the anchor.
local function Renew950()
	world.auras[7353] = { spellId = 7353, auraInstanceID = 950, duration = 60, expirationTime = world.time + 60 }
end
Renew950()
Tick(1)
Tick(5)
Renew950()
Tick(1)
world.pos, world.speed = { x = 40, y = 0, map = 0 }, 7
Tick(25)
check("timed fire left behind", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.pos, world.speed = { x = 15, y = 0, map = 0 }, 0
Renew950()
Tick(1)
check("back at a timed fire after a reset warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)

-- A slow fire (renews every 14 s): when it stops renewing, warmth fades instead of dropping at once.
Tick(13)
Renew950()
Tick(1)
check("14 s beat measured", Slash("debug"):find("every 14.0 s", 1, true))
Tick(16) -- 17 s after the last renewal: hold 15.5 s, then 4 s of fading, so 62.5% warm
check("slow fire fades, not drops", math.abs(Gauge.target - (awayFromFire + 35 * 0.625)) < 0.01, Gauge.target)
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)

-- Away for more than 15 s while the aura still lasts: the next fire is measured from scratch.
Renew()
Tick(1)
Tick(5)
Renew()
Tick(1)
check("gap measured", Slash("debug"):find("every 6.0 s", 1, true))
Tick(20)
Renew()
Tick(1)
check("long absence starts over", Slash("debug"):find("gap not measured yet", 1, true))
world.auras[7353] = nil
Tick(1)

-- From a 6 s fire to one nearby that renews the same aura every 14 s. One longer gap is a step away,
-- but the same gap again is the new beat: by the slow fire it stays fully warm between renewals.
Renew()
Tick(1)
Tick(5)
Renew()
Tick(1)
for _ = 1, 3 do
	Tick(13)
	Renew()
	Tick(1)
end
check("slower beat learned", Slash("debug"):find("every 14.0 s", 1, true))
Tick(12) -- 13 s after the last renewal
check("slow fire after a fast one stays warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.auras[7353] = nil
Tick(1)

-- At the edge of a 6 s fire, missing every other renewal gives 12 s gaps: not a slower fire.
Renew()
Tick(1)
Tick(5)
Renew()
Tick(1)
for _ = 1, 2 do
	Tick(11)
	Renew()
	Tick(1)
end
check("a multiple of the beat is not a new beat", Slash("debug"):find("every 6.0 s", 1, true))
-- Small jitter (6.4 s twice) does not stretch the beat either.
for _ = 1, 2 do
	Tick(5)
	local lastRenewal = world.auras[7353].expirationTime - 60
	world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = lastRenewal + 6.4 + 60 }
	Tick(1)
end
check("jitter does not stretch the beat", Slash("debug"):find("every 6.0 s", 1, true))
-- A real fire at twice the beat keeps coming: it is learned on the third 12 s gap.
for _ = 1, 3 do
	Tick(11)
	local lastRenewal = world.auras[7353].expirationTime - 60
	world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = lastRenewal + 12 + 60 }
	Tick(1)
end
check("a slower fire at twice the beat is learned", Slash("debug"):find("every 12.0 s", 1, true))
world.auras[7353] = nil
Tick(1)

-- Forever's camp fire: sitting by it puts Welcoming Campfire on you for 60 s, and no fire renews it.
-- Westfall at 15:00 is 20 outside; a fire warms up to 45 at most: Warm and Cozy, not Hot.
world.mapID, world.zoneText, world.hour = 1436, "Westfall", 15
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)
check("westfall afternoon before the camp", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
local function SitAtCamp(id, auraID)
	world.auras[id] = { spellId = id, auraInstanceID = auraID, duration = 60, expirationTime = world.time + 60 }
end
local function GotCampBenefits()
	world.auras[1229741] = { spellId = 1229741, auraInstanceID = 1199, duration = 3600, expirationTime = world.time + 3600 }
end
SitAtCamp(1289723, 1100)
Tick(1)
check("sitting by a camp fire warms", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
check("sitting by a camp fire is cozy", Gauge.cozy == true)
debugText = Slash("debug")
check("debug says sitting by a camp fire", debugText:find("sitting by a camp fire", 1, true), debugText)
Tick(20)
check("welcoming campfire needs no renewal", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
-- Standing up and stepping around the fire takes the buff off, but you are still by the fire.
world.auras[1289723] = nil
world.pos, world.speed = { x = 3, y = 0, map = 0 }, 7
Tick(1)
check("standing by the camp fire after sitting stays warm", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug says near where you sat", debugText:find("near where you sat by a camp fire", 1, true), debugText)
world.pos = { x = 17, y = 0, map = 0 }
Tick(5)
check("walking off the seat cools", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
check("off the seat is not cozy", Gauge.cozy == false)
-- Camp Benefits from that camp do not warm you anywhere else.
GotCampBenefits()
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)
check("camp benefits alone do not warm", math.abs(Gauge.target - 20) < 0.01, Gauge.target)

-- Sitting through the minute: it turns into Camp Benefits (none at a bare fire, as here), and the
-- warmth stays while you stay near.
world.auras[1229741] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
SitAtCamp(1229739, 1101)
Tick(1)
Tick(59)
world.auras[1229739] = nil
Tick(1)
check("sat through the minute, still warm by the fire", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug says you stayed where you sat", debugText:find("near where you sat", 1, true), debugText)
world.pos, world.speed = { x = 6, y = 0, map = 0 }, 7 -- up and around the fire
Tick(1)
check("around the camp fire stays warm", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.pos = { x = 17, y = 0, map = 0 }
Tick(5)
check("walking off the camp cools", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)
check("the seat warms no more once you left", math.abs(Gauge.target - 20) < 0.01, Gauge.target)

-- A camp fire burns out: the seat counts 15 min after you sat down at most.
SitAtCamp(1229739, 1102)
Tick(1)
Tick(59)
world.auras[1229739] = nil
GotCampBenefits()
Tick(1)
Tick(839) -- 899 s after sitting down
check("seat still warm before the fire burns out", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
Tick(2)
check("seat cold once the fire burned out", math.abs(Gauge.target - 20) < 0.01, Gauge.target)

-- Campfire Nearby seen by the seat: its end means the fire went out, long before 15 min.
world.auras[1283391] = { spellId = 1283391 }
SitAtCamp(1229739, 1108)
Tick(1)
world.auras[1229739] = nil
world.pos, world.speed = { x = 2, y = 0, map = 0 }, 7
Tick(30)
check("standing by a burning camp fire stays warm", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.auras[1283391] = nil
Tick(1)
check("fire out: Campfire Nearby gone", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0

-- Sitting down again starts the count anew: a fire put Welcoming Campfire on you, so it burns.
SitAtCamp(1229739, 1106)
Tick(1)
Tick(59)
world.auras[1229739] = nil
Tick(600)
SitAtCamp(1229739, 1107)
Tick(1)
Tick(59)
world.auras[1229739] = nil
Tick(400) -- 1060 s after the first seat, 460 s after the second
check("sitting again counts from then", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.pos = { x = 30, y = 0, map = 0 }
Tick(5)
world.pos = { x = 0, y = 0, map = 0 }
Tick(1)

-- A seat through a loading screen: nothing warms where you arrive. A camp fire there does, even
-- within the first seconds after loading.
SitAtCamp(1229739, 1103)
Tick(1)
Tick(59)
world.auras[1229739] = nil
GotCampBenefits()
Tick(1)
CoreEvent("PLAYER_ENTERING_WORLD")
check("a seat does not travel", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
Tick(1)
SitAtCamp(1229739, 1104)
Tick(1)
check("a camp fire right after loading warms", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.auras[1229739] = nil
Tick(1)

-- Forever's own Cozy Fire: 3 s long, renewed within 20 yd of a camp fire. It tells better than a seat:
-- once it is gone, the fire is out.
local function RenewCampCozy()
	world.auras[1232234] = { spellId = 1232234, auraInstanceID = 1200, duration = 3, expirationTime = world.time + 3 }
end
SitAtCamp(1229739, 1105)
Tick(1)
Tick(59)
world.auras[1229739] = nil
GotCampBenefits()
for _ = 1, 3 do
	RenewCampCozy()
	Tick(2)
end
check("forever cozy fire warms", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.auras[1232234] = nil
Tick(1)
check("fire out, the seat does not warm", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
world.auras[1229741] = nil

-- /feels auras names the camp auras, and asks by ID for the ones the buff list leaves out.
world.auras[1229739] = { spellId = 1229739 }
GotCampBenefits()
world.auras[1232234] = { spellId = 1232234, name = "Cozy Fire", hidden = true }
aurasText = Slash("auras")
check("auras marks welcoming campfire", aurasText:find("(1229739) - counts as campfire", 1, true), aurasText)
check("auras marks camp benefits", aurasText:find("(1229741) - camp buffs, not counted", 1, true), aurasText)
check("auras finds a hidden fire aura", aurasText:find("Cozy Fire (1232234), not in the buff list - counts as campfire", 1, true), aurasText)
world.auras = {}
Tick(1)

-- A torch in hand warms a little: Westfall at 05:00 is 10 - 30 = -20, with a torch -20 + 20 = 0.
world.hour = 5
Tick(1)
check("westfall before dawn", math.abs(Gauge.target - (-20)) < 0.01, Gauge.target)
world.auras[1309410] = { spellId = 1309410, duration = 300, expirationTime = world.time + 300 } -- Night Watchman's Torch
Tick(1)
check("lit torch warms", math.abs(Gauge.target - 0) < 0.01, Gauge.target)
world.auras[1309410] = nil
world.auras[1321139] = { spellId = 1321139, hidden = true } -- an ally's torch lights you
Tick(1)
check("an ally's torch warms", math.abs(Gauge.target - 0) < 0.01, Gauge.target)
check("debug names an ally's torch", Slash("debug"):find("torch from an ally's torch: +20.0", 1, true))
world.auras[1321139] = nil
world.auras[1309410] = { spellId = 1309410, duration = 300, expirationTime = world.time + 300 }
Tick(1)
check("a torch is not cozy", Gauge.cozy == false)
debugText = Slash("debug")
check("debug shows the torch", debugText:find("torch in hand: +20.0", 1, true), debugText)
check("auras marks the torch", Slash("auras"):find("(1309410) - counts as a torch", 1, true))
world.auras[1309410] = nil
Tick(1)
check("torch out", math.abs(Gauge.target - (-20)) < 0.01, Gauge.target)
world.hands[17] = 1172 -- Grayson's Torch in the off hand
Tick(1)
check("torch held in the off hand warms", math.abs(Gauge.target - 0) < 0.01, Gauge.target)
world.hands[17], world.hands[16] = 3675, 2808 -- Burnt Out Torch off hand, Torch of Flame main hand
Tick(1)
check("torch held in the main hand warms", math.abs(Gauge.target - 0) < 0.01, Gauge.target)
world.hands[16] = nil
Tick(1)
check("a burnt out torch does not warm", math.abs(Gauge.target - (-20)) < 0.01, Gauge.target)
world.hands, world.hour = {}, 15
Tick(1)

-- Instance overrides the zone.
world.instance = { "Molten Core", "raid", 9, "", 40, 0, false, 409 }
world.indoors = true
Tick(1)
check("molten core", Gauge.target == 100, Gauge.target)
world.instance = { "Deadmines", "party", 1, "", 5, 0, false, 36 }
Tick(1)
check("unknown instance neutral", Gauge.target == 0, Gauge.target)
world.instance = { "Dun Morogh", "none", 0, "", 0, 0, false, 0 }
world.indoors = false

-- Subzone overrides the zone.
world.mapID, world.zoneText, world.subzoneText, world.hour = 1449, "Un'Goro Crater", "Fire Plume Ridge", 15
Tick(1)
check("subzone override", Gauge.target == 90, Gauge.target)
world.subzoneText = ""

-- Fire underfoot: Dun Morogh at night, stepping into a campfire outside combat.
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 3
world.weather = { type = 0, intensity = 0 }
Tick(200) -- dry off
local coldReading = Gauge.target
check("core listens to UNIT_COMBAT", FireHit())
check("fire hit is scorching at once", Gauge.target == 100, Gauge.target)
debugText = Slash("debug")
check("debug shows fire", debugText:find("fire underfoot 1.00", 1, true), debugText)
Tick(2)
FireHit() -- still standing in it
Tick(2)
check("standing in fire stays scorching", Gauge.target == 100, Gauge.target)
Tick(3)
check("stepping out fades", Gauge.target > coldReading and Gauge.target < 100, Gauge.target)
Tick(5)
check("faded back", math.abs(Gauge.target - coldReading) < 0.01, Gauge.target)

-- Lava: you swim in it, but it burns instead of soaking.
world.swimming = true
FireHit()
Tick(1)
FireHit()
Tick(1)
check("lava keeps burning while you swim in it", Gauge.target == 100, Gauge.target)
world.swimming = false
Tick(10)
check("lava leaves you dry", math.abs(Gauge.target - coldReading) < 0.01, Gauge.target)

-- From the fire straight into a lake: the water puts the fire out and soaks you.
FireHit()
world.swimming = true
Tick(4)
check("water puts the fire out and soaks", Gauge.target < coldReading - 1, Gauge.target)
world.swimming = false
Tick(200)

-- Not counted: physical damage, fire in combat, heals, zero amount, secret values.
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
NextFrame()
check("physical ignored", Gauge.target == coldReading, Gauge.target)
world.combat = true
FireHit()
world.combat = false
check("fire in combat ignored", Gauge.target == coldReading, Gauge.target)
CoreEvent("UNIT_COMBAT", "player", "HEAL", "", 120, 4)
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 0, 4)
NextFrame()
check("heal and zero ignored", Gauge.target == coldReading, Gauge.target)
FireHit(20) -- frostfire: fire bit set
check("mixed school with fire counts", Gauge.target == 100, Gauge.target)
Tick(20)
local realSecret = _G.issecretvalue
_G.issecretvalue = function(value) return value == 4 end
FireHit()
_G.issecretvalue = realSecret
check("secret values ignored", Gauge.target == coldReading, Gauge.target)

-- A fire mob's first hit arrives a frame before the combat flag: not fire underfoot.
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 120, 4)
world.combat = true
NextFrame()
check("first hit of a fight ignored", Gauge.target == coldReading, Gauge.target)
-- Fire DoTs tick on after the fight ends: ignored for 15 s after combat.
world.combat = false
CoreEvent("PLAYER_REGEN_ENABLED")
Tick(5)
FireHit()
check("fire DoT after combat ignored", Gauge.target == coldReading, Gauge.target)
Tick(11)
FireHit()
check("fire after the grace counts", Gauge.target == 100, Gauge.target)
Tick(20)

-- A held test value ends by itself after 30 s.
timers = {}
Slash("test 42")
check("held test", Gauge.target == 42, Gauge.target)
local pendingTimers = timers
timers = {}
for _, fn in ipairs(pendingTimers) do fn() end
check("test ends by itself", Gauge.target ~= 42, Gauge.target)
check("test end is announced", table.concat(printed, "\n"):find("test ended", 1, true))

-- Test commands take over the gauge and give it back.
Slash("test 42")
Tick(1)
check("test value holds", Gauge.target == 42, Gauge.target)
Slash("test cozy")
check("test cozy", Gauge.cozy == true)
Slash("test off")
check("test off returns to reading", Gauge.target ~= 42 and Gauge.cozy == false, Gauge.target)
local realReading = Gauge.target
Slash("test cozy") -- with no test running, the needle stays on the real reading
check("test cozy keeps the needle", Gauge.target == realReading and Gauge.cozy == true, Gauge.target)
Slash("test off")
Slash("test nan")
check("test nan rejected", Gauge.target == Gauge.target and Gauge.target == realReading, Gauge.target)
Slash("test inf")
check("test inf clamps", Gauge.target == 100, Gauge.target)
Slash("test off")
Slash("test sweep")
check("sweep starts cold", Gauge.target == -100, Gauge.target)
for _ = 1, 20 do
	local pending = timers
	timers = {}
	for _, fn in ipairs(pending) do fn() end
end
check("sweep ends on real reading", Gauge.target ~= 100, Gauge.target)

-- Settings and slash.
Slash("")
check("slash opens settings", settings.opened == 7)
settings.FEELSLIKE_UNIT.callback(nil, "F")
check("unit setting switches the glyph", unitLayer.svg:find("unit_f.svg", 1, true), unitLayer.svg)
check("usage on unknown", Slash("nope"):find("/feels debug", 1, true))

-- Art added after 0.1.0, missing until the game restarts: gold stands in, no classic ring, still vector.
svg.missing = { ["ring_bronze.svg"] = true, ["ring_classic.svg"] = true }
ns = LoadAddon(true)
svg.missing = {}
check("missing new rings keep the vector dial", ns.Gauge.renderer == "vector", ns.Gauge.renderer)
local goldShown, newShown = false, false
for _, layer in ipairs(vectorLayers) do
	if layer.svg:find("ring_gold.svg", 1, true) then
		goldShown = layer.shown and (rawget(layer, "alpha") or 1) == 1
	elseif layer.svg:find("ring_bronze.svg", 1, true) or layer.svg:find("ring_classic.svg", 1, true) then
		newShown = newShown or layer.shown
	end
end
check("gold stands in for bronze", goldShown)
check("missing rings stay hidden", not newShown)
_G.Minimap.GetWidth = function() return 140 end
_G.Minimap.hooks.OnSizeChanged()
check("no classic ring, no error", goldShown and ns.Gauge.renderer == "vector")
_G.Minimap.GetWidth = nil

-- 0.1.0 saved its default scale (0.45) as if chosen: in Forever it moves to the new default once.
ns = LoadAddon(true, { scale = 0.45, unit = "F" })
check("old default scale moves to the new one", FeelsLikeDB.scale == 0.53 and FeelsLikeDB.version == 2, FeelsLikeDB.scale)
check("other saved settings stay", FeelsLikeDB.unit == "F")
ns = LoadAddon(true, { scale = 0.6 })
check("a chosen scale stays", FeelsLikeDB.scale == 0.6, FeelsLikeDB.scale)
ns = LoadAddon(true, { scale = 0.45, version = 2 })
check("0.45 chosen after the move stays", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
ns = LoadAddon(false, { scale = 0.45 })
check("retail keeps 0.45", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)

-- SVG files that fail to load fall back to the line dial ------------------------

svg.result = false
ns = LoadAddon(true)
svg.result = true
check("svg failure falls back to lines", ns.Gauge.renderer == "lines", ns.Gauge.renderer)
check("no more svg loaded after a failure", #vectorLayers == 1, #vectorLayers)
for _, layer in ipairs(vectorLayers) do
	check("failed svg layer hidden", layer.shown == false)
end

-- Retail client without C_Weather and without SVG ---------------------------------

svg.supported = false
ns = LoadAddon(false)
svg.supported = true
check("no svg support uses lines", ns.Gauge.renderer == "lines", ns.Gauge.renderer)
check("retail detected", not ns.Sensors.isForever)
check("retail default scale", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
-- Retail's default place: below the minimap at 158 degrees, 1.66 radii out.
local retailPoint = _G.FeelsLikeGauge.point
check("retail minimap offset", retailPoint and math.abs(retailPoint[4] - 198 / 2 * 1.66 * math.sin(math.rad(158)) / 0.45) < 0.01,
	retailPoint and retailPoint[4])
-- Retail's place was picked by a classic-style minimap already: a 140-wide one keeps it.
_G.Minimap.GetWidth = function() return 140 end
_G.Minimap.hooks.OnSizeChanged()
retailPoint = _G.FeelsLikeGauge.point
check("retail keeps its place by a classic minimap", retailPoint and math.abs(retailPoint[4] - 140 / 2 * 1.66 * math.sin(math.rad(158)) / 0.45) < 0.01,
	retailPoint and retailPoint[4])
check("retail debug does not name a classic minimap", not Slash("debug"):find("classic-style", 1, true))
_G.Minimap.GetWidth = function() return 198 end
world.mapID, world.zoneText, world.hour = 27, "Dun Morogh", 5
Tick(1)
-- No weather: -60 - 8 = -68.
check("retail dun morogh", math.abs(ns.Gauge.target - (-68)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("retail debug says no weather", debugText:find("no C_Weather", 1, true), debugText)
world.mapID, world.zoneText = 90, "Undercity"
world.indoors, world.resting = true, true
Tick(3)
check("retail undercity keeps its own value", math.abs(ns.Gauge.target - (-20)) < 0.01 and ns.Gauge.cozy == false,
	ns.Gauge.target)

if failures > 0 then
	io.write(failures .. " failed\n")
	os.exit(1)
end
io.write("all smoke tests passed\n")
