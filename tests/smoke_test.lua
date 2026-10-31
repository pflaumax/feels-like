-- Loads the addon with a fake WoW API and runs scenarios. Run with luajit tests/smoke_test.lua

local failures = 0
local function check(name, condition, detail)
	if not condition then
		failures = failures + 1
		io.write("FAIL " .. name .. (detail and (": " .. tostring(detail)) or "") .. "\n")
	end
end

-- Things the fake API records.
local fontStrings = {}
local createdFrames = {}
local vectorLayers = {}
local svg = { supported = true, result = true, missing = {} }

-- Generic widget. Unknown methods do nothing.
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
	-- false, not nil, so the method is really missing.
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

-- Fake world state.
local world

local function ResetWorld()
	world = {
		mapID = 1426, zoneText = "Dun Morogh", subzoneText = "",
		instance = { "Dun Morogh", "none", 0, "", 0, 0, false, 0 },
		hour = 5, minute = 0, -- coldest hour
		weather = { type = 2, intensity = 1 },
		indoors = false, resting = false, swimming = false,
		auras = {},
		time = 1000, combat = false,
		pos = { x = 0, y = 0, map = 0 }, speed = 0,
		hands = {}, -- item IDs by slot
		raceName = "Human", race = "Human", raceID = 1,
	}
end
ResetWorld()

local printed = {}
-- Flavor lines sent to the chat frame.
local chatLines = {}
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

	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text, r, g, b) chatLines[#chatLines + 1] = { text = text, r = r, g = g, b = b } end }
	_G.ChatTypeInfo = { EMOTE = { r = 1, g = 0.5, b = 0.25 } }
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
	_G.UnitIsDeadOrGhost = function() return world.dead end
	_G.GetTime = function() return world.time end
	_G.UnitPosition = function() return world.pos.y, world.pos.x, 0, world.pos.map end
	_G.GetUnitSpeed = function() return world.speed end
	_G.GetInventoryItemID = function(_, slot) return world.hands[slot] end
	_G.UnitRace = function() return world.raceName, world.race, world.raceID end
	_G.GetShapeshiftFormID = function() return world.form end
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

-- Loads every file in the TOC.
local function LoadAddon(forever, saved)
	ResetWorld()
	_G.FeelsLikeDB = saved
	printed, timers, tickers, loadedCallback = {}, {}, {}, nil
	chatLines = {}
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

-- Runs timers that are due.
local function NextFrame()
	local pending = timers
	timers = {}
	for _, fn in ipairs(pending) do fn() end
end

-- The Core event frame.
local function CoreEvent(event, ...)
	for _, frame in ipairs(createdFrames) do
		if frame.events.UNIT_COMBAT then
			frame.scripts.OnEvent(frame, event, ...)
			return true
		end
	end
	return false
end

-- Fire damage, then the next frame.
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

-- Forever client

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
-- Every SVG the dial loads exists.
for _, layer in ipairs(vectorLayers) do
	local path = layer.svg:gsub("^Interface\\AddOns\\", ""):gsub("\\", "/")
	local file = io.open(path)
	check("svg file exists", file ~= nil, path)
	if file then
		file:close()
	end
end
check("defaults saved", FeelsLikeDB.unit == "C" and FeelsLikeDB.label == "hover" and FeelsLikeDB.locked == false and FeelsLikeDB.scale == 0.53
	and FeelsLikeDB.race == true and FeelsLikeDB.undead == "numb")
check("race setting registered", settings.FEELSLIKE_RACE ~= nil)
check("undead setting registered", settings.FEELSLIKE_UNDEAD ~= nil)
check("one ticker", #tickers == 1, #tickers)

-- Dun Morogh before dawn in snow.
check("dun morogh night snow", math.abs(Gauge.target - (-88)) < 0.01, Gauge.target)
check("dun morogh word", ns.Model.Band(Gauge.target, Gauge.cozy).word == "Freezing")
-- Public API.
check("api version", FeelsLike.API_VERSION == 1, FeelsLike.API_VERSION)
local apiValue, apiWord, apiCozy = FeelsLike.GetTemperature()
check("api reading", math.abs(apiValue - (-88)) < 0.01 and apiWord == "Freezing" and apiCozy == false,
	tostring(apiValue) .. " " .. tostring(apiWord) .. " " .. tostring(apiCozy))

-- The needle moves to the matching SVG.
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
	if not onUpdate then break end -- removed once the needle settles
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
-- A point next to the minimap.
local gaugeForPosition = _G.FeelsLikeGauge
gaugeForPosition.GetCenter = function() return 450, 250 end
check("position angle and distance", ns.Gauge:DescribePosition():find("225 degrees from 12 o'clock, 0.71 of the minimap radius", 1, true),
	ns.Gauge:DescribePosition())
gaugeForPosition.GetCenter = function() return 500, 300 end

-- Forever default place and bronze ring.
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

-- Classic minimap from ClassicUI Forever.
_G.Minimap.GetWidth = function() return 140 end
_G.Minimap.hooks.OnSizeChanged()
point = gauge.point
check("classic minimap offset", point and point[2] == _G.Minimap and math.abs(point[4] - -55 / 0.53) < 0.01
	and math.abs(point[5] - -90 / 0.53) < 0.01, point and (point[4] .. ", " .. point[5]))
check("classic ring shown", ringClassic.alpha == 1 and ringBronze.alpha == 0, RingsShown())
debugText = Slash("debug")
check("debug names the classic-style minimap", debugText:find("position: default, classic-style minimap;", 1, true), debugText)
-- The label goes left there.
gauge.GetCenter = function() return 445, 210 end
ns.Gauge:ApplyPosition()
check("word left of the gauge under a classic minimap", fontStrings.GameFontHighlightSmall.point[1] == "RIGHT",
	fontStrings.GameFontHighlightSmall.point[1])
gauge.GetCenter = function() return 500, 300 end
-- A moved gauge stays, but the ring follows the minimap.
FeelsLikeDB.x, FeelsLikeDB.y = 100, 50
ns.Gauge:ApplyPosition()
check("moved gauge keeps its place by a classic minimap", gauge.point[2] == _G.UIParent and ringClassic.alpha == 1,
	RingsShown())
FeelsLikeDB.x, FeelsLikeDB.y = nil, nil
-- Back to the Blizzard minimap.
_G.Minimap.GetWidth = function() return 198 end
_G.Minimap.hooks.OnSizeChanged()
point = gauge.point
check("back to the mirror place", point and math.abs(point[4] - expectedX) < 0.01 and math.abs(point[5] - expectedY) < 0.01,
	point and (point[4] .. ", " .. point[5]))
check("back to the bronze ring", ringBronze.alpha == 1 and ringClassic.alpha == 0, RingsShown())

-- The label sits away from the minimap.
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
-- The minimap moves after placing.
gauge.GetCenter = function() return 440, 390 end
ns.Gauge:ApplyPosition()
_G.Minimap.GetCenter = function() return 300, 390 end
gauge.scripts.OnEnter()
check("word side follows a moved minimap", wordLabel.point[1] == "LEFT", wordLabel.point[1])
gauge.scripts.OnLeave()
_G.Minimap.GetCenter = function() return 500, 300 end
gauge.GetCenter = function() return 500, 300 end
ns.Gauge:ApplyPosition()

-- /feels measure by frame name.
_G.MoonButton = Widget()
_G.MoonButton.GetCenter = function() return 554, 383 end
_G.MoonButton.GetWidth = function() return 36 end
local measured = Slash("measure MoonButton")
check("measure a frame", measured:find("MoonButton: 33 degrees from 12 o'clock, 1.00 of the minimap radius from its center, as wide as the gauge at scale 0.50", 1, true), measured)
check("measure an unknown frame", Slash("measure NoSuchFrame"):find("no frame named NoSuchFrame", 1, true))
-- A frame by path.
_G.MoonCluster = { Moon = _G.MoonButton }
measured = Slash("measure MoonCluster.Moon")
check("measure a frame by path", measured:find("MoonCluster.Moon: 33 degrees from 12 o'clock", 1, true), measured)
check("measure an unknown path", Slash("measure MoonCluster.Sun"):find("no frame named MoonCluster.Sun", 1, true))
check("measure a path through a value", Slash("measure MoonCluster.Moon.GetWidth.x"):find("no frame named", 1, true))
_G.MoonButton, _G.MoonCluster = nil, nil

-- The label shows on hover.
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

-- A plain drag saves nothing.
world.shift = false
gauge.scripts.OnDragStart(gauge)
gauge.scripts.OnDragStop(gauge)
check("plain drag saves nothing", FeelsLikeDB.x == nil and gauge.point[2] == _G.Minimap)

-- Hover state does not stick when the mouse is off.
gauge.scripts.OnEnter()
FeelsLikeDB.locked, FeelsLikeDB.label = true, "never"
ns.Gauge:SetLocked(true)
ns.Gauge:SetLabelMode("never")
FeelsLikeDB.locked, FeelsLikeDB.label = false, "hover"
ns.Gauge:SetLocked(false)
ns.Gauge:SetLabelMode("hover")
check("hover does not stick", label.shown == false)

-- /feels auras lists buffs.
world.auras[7353] = { spellId = 7353 }
world.auras[1459] = { spellId = 1459 }
local aurasText = Slash("auras")
check("auras lists buffs", aurasText:find("Aura 1459 (1459)", 1, true), aurasText)
check("auras marks campfire", aurasText:find("Aura 7353 (7353) - counts as campfire", 1, true), aurasText)
for id = 1, 44 do -- more than 40 buffs
	world.auras[id] = { spellId = id }
end
check("auras lists past 40", Slash("auras"):find("(7353) - counts as campfire", 1, true))
world.auras = {}
check("auras none", Slash("auras"):find("none", 1, true))
world.auras[1232234] = { spellId = 1232234, name = "Cozy Fire", hidden = true }
aurasText = Slash("auras")
check("a hidden fire aura alone is not none", not aurasText:find("none", 1, true) and aurasText:find("(1232234)", 1, true), aurasText)
world.auras = {}

-- Unknown map is a neutral zone.
world.mapID = 9999
Tick(1)
-- Snow at night.
check("unknown map falls back to 0", math.abs(Gauge.target - (0 - 30 - 20)) < 0.01, Gauge.target)

-- Walking into an inn.
world.mapID, world.zoneText = 1436, "Westfall"
world.hour, world.weather = 15, { type = 0, intensity = 0 }
Tick(1)
local outside = Gauge.target
check("westfall afternoon outside", math.abs(outside - 20) < 0.01, outside)
local lowest = outside
world.indoors = true
for _ = 1, 2 do -- resting comes two ticks later
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
apiValue, apiWord, apiCozy = FeelsLike.GetTemperature()
check("api in an inn", math.abs(apiValue - 21.8) < 0.01 and apiWord == "Cozy" and apiCozy == true,
	tostring(apiValue) .. " " .. tostring(apiWord))

-- A capital city is not an inn.
world.indoors = false
Tick(3)
check("resting outdoors is not cozy", Gauge.cozy == false)
world.resting = false
Tick(3)

-- Undercity is fully inside.
world.mapID, world.zoneText = 1458, "Undercity"
world.indoors, world.resting = true, true
Tick(3)
check("undercity keeps its own value", math.abs(Gauge.target - (-20)) < 0.01, Gauge.target)
check("undercity is not cozy", Gauge.cozy == false)
debugText = Slash("debug")
check("debug says inside as a whole", debugText:find("inside as a whole, no shelter", 1, true), debugText)
-- Leaving the city.
world.mapID, world.zoneText = 1420, "Tirisfal Glades"
world.indoors, world.resting = false, false
Tick(1)
check("no inn reading after the undercity", Gauge.cozy == false and Gauge.target < 15, Gauge.target)
Tick(2) -- door delay, then outdoors
check("outdoors after the undercity", math.abs(Gauge.target - (-5)) < 0.01, Gauge.target)

-- A building that is not an inn.
world.mapID, world.zoneText = 1429, "Elwynn Forest"
Tick(1)
world.indoors = true
Tick(3)
check("building on a mild afternoon", math.abs(Gauge.target - 15) < 0.01, Gauge.target)
world.hour = 5
Tick(1)
check("building at night is warmer", math.abs(Gauge.target - (-1)) < 0.01, Gauge.target) -- cold night outside
world.indoors, world.hour = false, 15
Tick(3)

-- After a loading screen the new place counts at once.
world.indoors, world.resting = true, true
CoreEvent("PLAYER_ENTERING_WORLD")
check("hearth into inn counts at once", math.abs(Gauge.target - 21.3) < 0.01, Gauge.target)
world.indoors, world.resting = false, false
CoreEvent("PLAYER_ENTERING_WORLD")

-- Swimming soaks, then clothes dry.
world.mapID, world.zoneText, world.hour = 1446, "Tanaris", 15
world.swimming = true
Tick(1)
Tick(1)
local soaked = Gauge.target
check("soaked is colder than dry tanaris", soaked < 75 + 35 - 1, soaked)
world.swimming = false
Tick(120)
check("dried in the heat", math.abs(Gauge.target - 100) < 0.01, Gauge.target)

-- Drying during a loading screen.
world.mapID, world.zoneText = 1429, "Elwynn Forest"
world.swimming = true
Tick(2)
-- In the water on a mild day.
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

-- Rain keeps clothes damp.
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
world.weather = { type = 1, intensity = 1 }
Tick(200)
check("rain keeps damp", math.abs(Gauge.target - (-17.6)) < 0.01, Gauge.target)

-- Wait out the loading screens first.
Tick(6)

-- Campfire in Dun Morogh.
world.weather = { type = 0, intensity = 0 }
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 12
world.auras[7353] = { spellId = 7353 }
Tick(200)
check("campfire warms", Gauge.target > -60 + 30, Gauge.target)
-- Walked away from the fire.
world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = world.time + 50 }
Tick(1)
check("aging campfire aura gives no warmth", Gauge.target < -40, Gauge.target)
-- Into an inn with the aura on.
world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = world.time + 59 }
world.indoors, world.resting = true, true
Tick(3)
check("inn with campfire aura is cozy", Gauge.cozy == true and Gauge.target < 33, Gauge.target)
world.indoors, world.resting = false, false
world.auras[7353] = nil
Tick(3) -- aura gone, outdoors again

-- A fire with a 6 s beat.
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
Tick(5) -- 6 s after renewal
check("slow fire stays fully warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug shows renewal gap", debugText:find("every 6.0 s", 1, true), debugText)
Tick(6) -- 12 s after renewal
check("slow fire cools within 12 s", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
-- A late return is not a new beat.

-- In combat warmth still fades.
Renew()
Tick(1)
check("by the fire again", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
check("gap still 6 s after stepping away", Slash("debug"):find("every 6.0 s", 1, true))
local realIsSecret = _G.issecretvalue
_G.issecretvalue = function(value) return type(value) == "table" and value.spellId == 7353 end
for _ = 1, 13 do
	Tick(1)
	Renew() -- the addon cannot see renewals
end
check("secret aura does not linger", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
_G.issecretvalue = realIsSecret
-- Hidden fields count as a hidden aura.
Renew()
Tick(1)
check("by the fire before hidden fields", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
_G.issecretvalue = function(value) return value == 60 end -- aura duration
for _ = 1, 13 do
	Tick(1)
	Renew()
end
check("secret aura fields do not linger", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
_G.issecretvalue = function(value) return value == 7353 end -- buff spell ID
check("auras with a secret spell ID", Slash("auras"):find("hidden while auras are restricted", 1, true))
_G.issecretvalue = realIsSecret
world.auras[7353] = nil
Tick(1)
check("gap forgotten once the aura is gone", not Slash("debug"):find("every", 1, true))

-- Aura without a timer, distance decides.
world.pos, world.speed = { x = 100, y = 100, map = 0 }, 7
world.auras[7353] = { spellId = 7353, auraInstanceID = 501 } -- aura starts at the edge
Tick(1)
world.pos, world.speed = { x = 108, y = 100, map = 0 }, 0 -- stop by the fire
Tick(1)
check("untimed aura by the fire", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug shows distance", debugText:find("0.0 yd from where you stood by it", 1, true), debugText)
world.pos, world.speed = { x = 102, y = 100, map = 0 }, 7 -- still within reach
Tick(1)
check("moving around the fire stays warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos = { x = 125, y = 100, map = 0 } -- 17 yd away, gone
Tick(1)
Tick(5)
check("walked away cools in seconds", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.pos = {} -- position hidden
Tick(1)
check("hidden position keeps you away", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.pos, world.speed = { x = 109, y = 101, map = 0 }, 0 -- back to the fire
Tick(1)
check("back by the fire warms again", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos = { x = 108, y = 100, map = 1 } -- hearth away
Tick(5)
check("another map counts as gone", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
debugText = Slash("debug")
check("debug says far", debugText:find("far from the fire", 1, true), debugText)
-- Hearth with the aura on.
world.pos = { x = 108, y = 100, map = 0 }
Tick(1)
check("by the fire before the hearth", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } })
world.pos = { x = 900, y = 40, map = 0 }
CoreEvent("PLAYER_ENTERING_WORLD")
check("arrive away from the fire", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } }) -- client refreshing aura data
Tick(1)
check("aura refresh after a loading screen is no renewal", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.auras[7353] = { spellId = 7353, auraInstanceID = 601 }
Tick(1)
world.auras[7353] = nil
Tick(1)
world.auras[7353] = { spellId = 7353, auraInstanceID = 602 }
Tick(3)
check("same aura after a loading screen is not a new fire", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
-- A fire here warms again.
Tick(1)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 602 } })
Tick(1)
check("a fire after the loading screen warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
-- A reload by the fire.
CoreEvent("PLAYER_ENTERING_WORLD", false, true)
Tick(1)
check("reload by the fire stays warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
-- Position hidden at a new fire.
world.pos = {}
world.auras[7353] = { spellId = 7353, auraInstanceID = 603 }
Tick(1)
world.pos = { x = 500, y = 500, map = 0 }
Tick(5)
check("a fire found without a position anchors where you are", math.abs(Gauge.target - fullyWarm) < 0.01,
	Gauge.target)

-- Into an instance and out.
world.pos = {}
CoreEvent("PLAYER_ENTERING_WORLD")
Tick(6)
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 603 } }) -- fire inside
Tick(1)
check("fire inside an instance warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.pos = { x = 300, y = 300, map = 0 }
CoreEvent("PLAYER_ENTERING_WORLD")
Tick(1)
check("an instance fire stays behind", math.abs(Gauge.target - awayFromFire) < 0.01, Gauge.target)
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(6) -- aura gone

-- A new fire anchors anew.
world.auras[7353] = { spellId = 7353, auraInstanceID = 777 }
Tick(1)
check("new fire warms where you are", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.auras[7353] = nil
Tick(1)

-- Timed aura, then a hearth.
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
Renew700() -- a fire here
Tick(1)
check("first renewal after the hearth warms", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
Tick(7)
Renew700() -- this fire renews every 8 s
Tick(1)
check("beat measured afresh after the hearth", Slash("debug"):find("every 8.0 s", 1, true))
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(6)

-- Two fires 15 yd apart.
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
CoreEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 12345 } }) -- other aura
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

-- Back at the fire from the other side.
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

-- A slow fire fades smoothly.
Tick(13)
Renew950()
Tick(1)
check("14 s beat measured", Slash("debug"):find("every 14.0 s", 1, true))
Tick(16) -- 17 s after renewal
check("slow fire fades, not drops", math.abs(Gauge.target - (awayFromFire + 35 * 0.625)) < 0.01, Gauge.target)
world.auras[7353] = nil
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)

-- Away long enough, measure again.
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

-- From a fast fire to a slow one.
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
Tick(12) -- 13 s after renewal
check("slow fire after a fast one stays warm", math.abs(Gauge.target - fullyWarm) < 0.01, Gauge.target)
world.auras[7353] = nil
Tick(1)

-- Missed renewals at the edge.
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
-- Small jitter.
for _ = 1, 2 do
	Tick(5)
	local lastRenewal = world.auras[7353].expirationTime - 60
	world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = lastRenewal + 6.4 + 60 }
	Tick(1)
end
check("jitter does not stretch the beat", Slash("debug"):find("every 6.0 s", 1, true))
-- A real slower fire is learned.
for _ = 1, 3 do
	Tick(11)
	local lastRenewal = world.auras[7353].expirationTime - 60
	world.auras[7353] = { spellId = 7353, duration = 60, expirationTime = lastRenewal + 12 + 60 }
	Tick(1)
end
check("a slower fire at twice the beat is learned", Slash("debug"):find("every 12.0 s", 1, true))
world.auras[7353] = nil
Tick(1)

-- Forever camp fire.
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
-- Stepping around the fire.
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
-- Camp Benefits do not warm elsewhere.
GotCampBenefits()
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)
check("camp benefits alone do not warm", math.abs(Gauge.target - 20) < 0.01, Gauge.target)

-- Sitting through the minute.
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
world.pos, world.speed = { x = 6, y = 0, map = 0 }, 7 -- around the fire
Tick(1)
check("around the camp fire stays warm", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.pos = { x = 17, y = 0, map = 0 }
Tick(5)
check("walking off the camp cools", math.abs(Gauge.target - 20) < 0.01, Gauge.target)
world.pos, world.speed = { x = 0, y = 0, map = 0 }, 0
Tick(1)
check("the seat warms no more once you left", math.abs(Gauge.target - 20) < 0.01, Gauge.target)

-- A camp fire burns out.
SitAtCamp(1229739, 1102)
Tick(1)
Tick(59)
world.auras[1229739] = nil
GotCampBenefits()
Tick(1)
Tick(839) -- 899 s after sitting
check("seat still warm before the fire burns out", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
Tick(2)
check("seat cold once the fire burned out", math.abs(Gauge.target - 20) < 0.01, Gauge.target)

-- Campfire Nearby ends.
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

-- Sitting again starts anew.
SitAtCamp(1229739, 1106)
Tick(1)
Tick(59)
world.auras[1229739] = nil
Tick(600)
SitAtCamp(1229739, 1107)
Tick(1)
Tick(59)
world.auras[1229739] = nil
Tick(400)
check("sitting again counts from then", math.abs(Gauge.target - 45) < 0.01, Gauge.target)
world.pos = { x = 30, y = 0, map = 0 }
Tick(5)
world.pos = { x = 0, y = 0, map = 0 }
Tick(1)

-- A seat through a loading screen.
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

-- Forever's own Cozy Fire.
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

-- /feels auras with camp auras.
world.auras[1229739] = { spellId = 1229739 }
GotCampBenefits()
world.auras[1232234] = { spellId = 1232234, name = "Cozy Fire", hidden = true }
aurasText = Slash("auras")
check("auras marks welcoming campfire", aurasText:find("(1229739) - counts as campfire", 1, true), aurasText)
check("auras marks camp benefits", aurasText:find("(1229741) - camp buffs, not counted", 1, true), aurasText)
check("auras finds a hidden fire aura", aurasText:find("Cozy Fire (1232234), not in the buff list - counts as campfire", 1, true), aurasText)
world.auras = {}
Tick(1)

-- A torch warms a little.
world.hour = 5
Tick(1)
check("westfall before dawn", math.abs(Gauge.target - (-20)) < 0.01, Gauge.target)
world.auras[1309410] = { spellId = 1309410, duration = 300, expirationTime = world.time + 300 } -- Night Watchman's Torch
Tick(1)
check("lit torch warms", math.abs(Gauge.target - 0) < 0.01, Gauge.target)
world.auras[1309410] = nil
world.auras[1321139] = { spellId = 1321139, hidden = true } -- an ally's torch
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
world.hands[17] = 1172 -- Grayson's Torch
Tick(1)
check("torch held in the off hand warms", math.abs(Gauge.target - 0) < 0.01, Gauge.target)
world.hands[17], world.hands[16] = 3675, 2808 -- unlit torch and lit torch
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

-- Fire underfoot.
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 3
world.weather = { type = 0, intensity = 0 }
Tick(200) -- dry off
local coldReading = Gauge.target
check("core listens to UNIT_COMBAT", FireHit())
check("fire hit is scorching at once", Gauge.target == 100, Gauge.target)
debugText = Slash("debug")
check("debug shows fire", debugText:find("fire underfoot 1.00", 1, true), debugText)
Tick(2)
FireHit() -- still in it
Tick(2)
check("standing in fire stays scorching", Gauge.target == 100, Gauge.target)
Tick(3)
check("stepping out fades", Gauge.target > coldReading and Gauge.target < 100, Gauge.target)
Tick(5)
check("faded back", math.abs(Gauge.target - coldReading) < 0.01, Gauge.target)

-- Lava burns instead of soaking.
world.swimming = true
FireHit()
Tick(1)
FireHit()
Tick(1)
check("lava keeps burning while you swim in it", Gauge.target == 100, Gauge.target)
world.swimming = false
Tick(10)
check("lava leaves you dry", math.abs(Gauge.target - coldReading) < 0.01, Gauge.target)

-- Fire, then a lake.
FireHit()
world.swimming = true
Tick(4)
check("water puts the fire out and soaks", Gauge.target < coldReading - 1, Gauge.target)
world.swimming = false
Tick(200)

-- Not counted as fire.
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
FireHit(20) -- frostfire
check("mixed school with fire counts", Gauge.target == 100, Gauge.target)
Tick(20)
local realSecret = _G.issecretvalue
_G.issecretvalue = function(value) return value == 4 end
FireHit()
_G.issecretvalue = realSecret
check("secret values ignored", Gauge.target == coldReading, Gauge.target)

-- A fire mob's first hit.
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 120, 4)
world.combat = true
NextFrame()
check("first hit of a fight ignored", Gauge.target == coldReading, Gauge.target)
-- Fire DoTs after a fight.
world.combat = false
CoreEvent("PLAYER_REGEN_ENABLED")
Tick(5)
FireHit()
check("fire DoT after combat ignored", Gauge.target == coldReading, Gauge.target)
Tick(11)
FireHit()
check("fire after the grace counts", Gauge.target == 100, Gauge.target)
Tick(20)

-- A test ends by itself.
timers = {}
Slash("test 42")
check("held test", Gauge.target == 42, Gauge.target)
local pendingTimers = timers
timers = {}
for _, fn in ipairs(pendingTimers) do fn() end
check("test ends by itself", Gauge.target ~= 42, Gauge.target)
check("test end is announced", table.concat(printed, "\n"):find("test ended", 1, true))

-- Test commands.
Slash("test 42")
Tick(1)
check("test value holds", Gauge.target == 42, Gauge.target)
local apiDuringTest = FeelsLike.GetTemperature()
Slash("test cozy")
check("test cozy", Gauge.cozy == true)
Slash("test off")
check("test off returns to reading", Gauge.target ~= 42 and Gauge.cozy == false, Gauge.target)
local realReading = Gauge.target
check("api gives the real reading during a test", apiDuringTest ~= 42 and math.abs(apiDuringTest - realReading) < 0.01,
	tostring(apiDuringTest) .. " vs " .. tostring(realReading))
Slash("test cozy") -- no test running
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

-- Missing new art.
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

-- Old saved scale.
ns = LoadAddon(true, { scale = 0.45, unit = "F" })
check("old default scale moves to the new one", FeelsLikeDB.scale == 0.53 and FeelsLikeDB.version == 2, FeelsLikeDB.scale)
check("other saved settings stay", FeelsLikeDB.unit == "F")
ns = LoadAddon(true, { scale = 0.6 })
check("a chosen scale stays", FeelsLikeDB.scale == 0.6, FeelsLikeDB.scale)
ns = LoadAddon(true, { scale = 0.45, version = 2 })
check("0.45 chosen after the move stays", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
ns = LoadAddon(false, { scale = 0.45 })
check("retail keeps 0.45", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
check("old save gets the race setting", FeelsLikeDB.race == true, FeelsLikeDB.race)
check("old save gets the undead setting", FeelsLikeDB.undead == "numb", FeelsLikeDB.undead)

-- Humid air in Stranglethorn on a clear afternoon.
ns = LoadAddon(true)
world.mapID, world.zoneText, world.hour = 1434, "Stranglethorn Vale", 15
world.weather = { type = 0, intensity = 0 }
Tick(1)
check("stranglethorn feels humid", math.abs(ns.Gauge.target - 58.75) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug shows humid air", debugText:find("humid air: +7.8", 1, true), debugText)
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 5
world.weather = { type = 2, intensity = 1 }
Tick(1)
check("no humid air in the snow", Slash("debug"):find("humid air: +0.0", 1, true))
-- Humid air dries nothing: after a swim in Un'Goro before dawn clothes dry at the plain air's pace.
world.mapID, world.zoneText, world.hour = 1449, "Un'Goro Crater", 5
world.weather = { type = 0, intensity = 0 }
world.swimming = true
Tick(2)
world.swimming = false
Tick(46) -- the first tick still counts the swim
debugText = Slash("debug")
check("humid air keeps the normal drying pace", debugText:find("wetness 0.50", 1, true), debugText)

-- Flavor lines, in Dun Morogh before dawn in snow (Freezing).
local function LastLine()
	return chatLines[#chatLines] and chatLines[#chatLines].text
end
local function GoMild()
	world.mapID, world.zoneText, world.weather = 1429, "Elwynn Forest", { type = 0, intensity = 0 }
end
local function GoFreezing()
	world.mapID, world.zoneText, world.weather = 1426, "Dun Morogh", { type = 2, intensity = 1 }
end
-- Loads and waits out the quiet moment after login.
local function LoadQuietly(saved)
	ns, settings = LoadAddon(true, saved)
	Tick(10)
end
ns, settings = LoadAddon(true)
check("flavor on by default", FeelsLikeDB.flavor == true)
check("flavor setting registered", settings.FEELSLIKE_FLAVOR ~= nil)
Tick(10)
check("the word at login says nothing", #chatLines == 0, #chatLines)
GoMild()
Tick(2)
check("mild says nothing", #chatLines == 0, #chatLines)
GoFreezing()
Tick(3)
check("no line before the word settles", #chatLines == 0, #chatLines)
Tick(1)
check("a line once the word holds", #chatLines == 1 and LastLine() == "You shiver from the cold. (/shiver)", LastLine())
check("the line has the emote color", chatLines[1] and chatLines[1].r == 1 and chatLines[1].g == 0.5 and chatLines[1].b == 0.25)
check("debug names the last line", Slash("debug"):find("flavor lines on, last: Freezing 0 s ago", 1, true))
Tick(20 * 60)
check("no second line while the word holds", #chatLines == 1, #chatLines)
GoMild()
Tick(60)
GoFreezing()
Tick(4)
check("the word again after the cooldown, the next line", #chatLines == 2 and LastLine() == "Your teeth chatter. You need a fire.", LastLine())
GoMild()
Tick(60)
GoFreezing()
Tick(20 * 60)
check("back within the cooldown stays quiet", #chatLines == 2, #chatLines)
-- Fire underfoot has its own lines.
for _ = 1, 4 do
	FireHit(4)
	Tick(2)
end
check("fire underfoot line", LastLine() == "Ouch! That burns!", LastLine())
check("debug names fire underfoot", Slash("debug"):find("last: Scorching from fire underfoot", 1, true))
-- The game reports the place late at login: what comes within the quiet moment is no change.
LoadQuietly()
GoMild()
Tick(20 * 60)
CoreEvent("PLAYER_ENTERING_WORLD", false, true) -- a /reload
GoFreezing()
Tick(9)
check("the place found after a reload says nothing", #chatLines == 0, #chatLines)
Tick(20)
check("it stays quiet after the quiet moment", #chatLines == 0, #chatLines)
-- A loading screen that moved you is a real change.
GoMild()
Tick(2)
CoreEvent("PLAYER_ENTERING_WORLD", false, false)
GoFreezing()
Tick(4)
check("a hearth into the cold speaks", #chatLines == 1, #chatLines)
-- Cold, then Freezing within the minute: the second waits for the minute.
LoadQuietly()
world.hour, world.weather = 15, { type = 0, intensity = 0 }
Tick(4)
check("cold line", #chatLines == 1 and LastLine() == "A chill runs down your back.", LastLine())
world.hour = 5
Tick(4)
check("the next word waits for the minute", #chatLines == 1, #chatLines)
Tick(60)
check("then it speaks", #chatLines == 2 and LastLine() == "You shiver from the cold. (/shiver)", LastLine())
-- Nothing in combat, the line after it.
LoadQuietly()
GoMild()
Tick(1)
world.combat = true
GoFreezing()
Tick(10)
check("no line in combat", #chatLines == 0, #chatLines)
world.combat = false
Tick(1)
check("the line after combat", #chatLines == 1, #chatLines)
-- Nothing as a ghost, the line after coming back.
LoadQuietly()
GoMild()
Tick(1)
world.dead = true
GoFreezing()
Tick(10)
check("no line as a ghost", #chatLines == 0, #chatLines)
world.dead = false
Tick(1)
check("the line after coming back", #chatLines == 1, #chatLines)
-- Nothing during a test.
LoadQuietly()
GoMild()
Tick(1)
Slash("test 50")
GoFreezing()
Tick(10)
check("no line during a test", #chatLines == 0, #chatLines)
Slash("test off")
Tick(1)
check("the line after the test", #chatLines == 1, #chatLines)
-- The setting off drops the line; turned on, it waits for the next change.
LoadQuietly({ flavor = false })
GoMild()
Tick(1)
GoFreezing()
Tick(10)
check("no line with the setting off", #chatLines == 0, #chatLines)
check("debug says flavor lines off", Slash("debug"):find("flavor lines off", 1, true))
FeelsLikeDB.flavor = true
Tick(10)
check("turned on, an old word stays quiet", #chatLines == 0, #chatLines)
GoMild()
Tick(1)
GoFreezing()
Tick(4)
check("turned on, the next change speaks", #chatLines == 1, #chatLines)
-- Cozy in an inn.
LoadQuietly()
world.indoors, world.resting = true, true
Tick(8)
check("cozy inn line", #chatLines == 1 and LastLine() == "The warmth of the inn wraps around you.", LastLine())

-- Race, in Dun Morogh before dawn in snow (-88 for a human).
ns = LoadAddon(true)
-- English name, and the local one when it differs.
local function RaceTarget(race, name)
	world.race, world.raceName = race, name or race
	Tick(1)
	return ns.Gauge.target
end
check("human race", math.abs(RaceTarget("Human") - (-88)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug shows a neutral race", debugText:find("race Human, cold x1.00, heat x1.00: +0.0", 1, true), debugText)
check("dwarf feels less cold", math.abs(RaceTarget("Dwarf") - (-66)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug shows the race", debugText:find("race Dwarf, cold x0.75, heat x1.00: +22.0", 1, true), debugText)
check("undead still cold", math.abs(RaceTarget("Scourge", "Undead") - (-44)) < 0.01
	and ns.Model.Band(ns.Gauge.target).word == "Cold", ns.Gauge.target)
debugText = Slash("debug")
check("debug adds the local name", debugText:find("race Scourge (Undead), numb, cold x0.50, heat x0.60: +44.0", 1, true), debugText)
-- The undead choose how they feel.
FeelsLikeDB.undead = "cold"
check("undead always cold", math.abs(RaceTarget("Scourge", "Undead") - (-75.2)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug says always cold", debugText:find("race Scourge (Undead), always cold, cold x0.40, heat x0.40, shift -40: +12.8", 1, true), debugText)
FeelsLikeDB.undead = "living"
check("undead like the living", math.abs(RaceTarget("Scourge", "Undead") - (-88)) < 0.01, ns.Gauge.target)
check("debug says like the living", Slash("debug"):find("race Scourge (Undead), like the living, cold x1.00, heat x1.00: +0.0", 1, true))
FeelsLikeDB.undead = "zombie"
check("a bad undead value is numb", math.abs(RaceTarget("Scourge", "Undead") - (-44)) < 0.01, ns.Gauge.target)
FeelsLikeDB.undead = "cold"
check("the undead choice leaves dwarves alone", math.abs(RaceTarget("Dwarf") - (-66)) < 0.01, ns.Gauge.target)
FeelsLikeDB.race = false
check("race off wins over the undead choice", math.abs(RaceTarget("Scourge", "Undead") - (-88)) < 0.01, ns.Gauge.target)
FeelsLikeDB.race = true
FeelsLikeDB.undead = "numb"
RaceTarget("Dwarf", "Nain")
check("debug adds a translated name", Slash("debug"):find("race Dwarf (Nain), cold x0.75", 1, true))
check("troll clamped at the bottom", RaceTarget("Troll") == -100, ns.Gauge.target)
-- Turned off in the settings.
FeelsLikeDB.race = false
check("race off feels like a human", math.abs(RaceTarget("Dwarf") - (-88)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug says race off", debugText:find("race Dwarf, off in settings: +0.0", 1, true), debugText)
FeelsLikeDB.race = true
check("race back on", math.abs(RaceTarget("Dwarf") - (-66)) < 0.01, ns.Gauge.target)
-- A race not in the table.
check("unknown race feels like a human", math.abs(RaceTarget("Goblin") - (-88)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug says not in the table", debugText:find("race Goblin, not in the table, feels like a human: +0.0", 1, true), debugText)
-- A secret race.
local raceIsSecret = _G.issecretvalue
_G.issecretvalue = function(value) return value == "Dwarf" or value == "Nain" end
check("secret race feels like a human", math.abs(RaceTarget("Dwarf", "Nain") - (-88)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug says race unknown", debugText:find("race unknown: +0.0", 1, true), debugText)
check("debug hides a secret local name", not debugText:find("Nain", 1, true), debugText)
-- Secret and turned off.
FeelsLikeDB.race = false
Tick(1)
check("debug says off for an unknown race", Slash("debug"):find("race unknown, off in settings: +0.0", 1, true))
FeelsLikeDB.race = true
_G.issecretvalue = raceIsSecret
-- No race at all, as in a very early load.
check("no race feels like a human", math.abs(RaceTarget(nil, false) - (-88)) < 0.01, ns.Gauge.target)
check("debug says race unknown without a race", Slash("debug"):find("race unknown: +0.0", 1, true))
-- Druid forms with fur.
local function FormTarget(form, race)
	world.form = form
	if race then
		return RaceTarget(race)
	end
	return RaceTarget("NightElf", "Night Elf")
end
check("cat form has fur", math.abs(FormTarget(1) - (-66)) < 0.01, ns.Gauge.target)
debugText = Slash("debug")
check("debug shows the fur form", debugText:find("race NightElf (Night Elf), in Cat Form (fur), cold x0.75, heat x1.15: +22.0", 1, true), debugText)
for _, form in ipairs({ 3, 5, 8, 31 }) do
	check("fur form " .. form, math.abs(FormTarget(form) - (-66)) < 0.01, ns.Gauge.target)
end
check("a tauren bear feels like a tauren", math.abs(FormTarget(5, "Tauren") - (-66)) < 0.01, ns.Gauge.target)
check("ghost wolf has no fur", math.abs(FormTarget(16, "Orc") - (-88)) < 0.01, ns.Gauge.target)
check("debug names a form without fur", Slash("debug"):find("race Orc, in form 16, cold x1.00, heat x1.00: +0.0", 1, true))
FormTarget(0)
check("form 0 is no form", not Slash("debug"):find("race NightElf (Night Elf), in", 1, true))
FeelsLikeDB.race = false
check("fur off with the race setting", math.abs(FormTarget(1) - (-88)) < 0.01, ns.Gauge.target)
check("debug says off in a form", Slash("debug"):find("in Cat Form (fur), off in settings: +0.0", 1, true))
FeelsLikeDB.race = true
local formIsSecret, secretForm = _G.issecretvalue, {}
_G.issecretvalue = function(value) return value == secretForm end
check("secret form has no fur", math.abs(FormTarget(secretForm) - (-88)) < 0.01, ns.Gauge.target)
_G.issecretvalue = formIsSecret
local realFormID = _G.GetShapeshiftFormID
_G.GetShapeshiftFormID = nil
check("no form API, no fur", math.abs(FormTarget(1) - (-88)) < 0.01, ns.Gauge.target)
_G.GetShapeshiftFormID = realFormID
-- Shifting updates at once.
FormTarget(nil)
local formEventRegistered = false
for _, frame in ipairs(createdFrames) do
	formEventRegistered = formEventRegistered or frame.events.UPDATE_SHAPESHIFT_FORM == true
end
check("form event registered", formEventRegistered)
local reads, realRead = 0, ns.Sensors.Read
ns.Sensors.Read = function()
	reads = reads + 1
	return realRead()
end
CoreEvent("UPDATE_SHAPESHIFT_FORM")
check("form event without a new form reads nothing", reads == 0, reads)
world.form = 5
CoreEvent("UPDATE_SHAPESHIFT_FORM")
check("form event updates at once", reads == 1 and math.abs(ns.Gauge.target - (-66)) < 0.01, ns.Gauge.target)
ns.Sensors.Read = realRead
world.form = nil
-- Retail reads the race too.
ns = LoadAddon(false)
world.mapID, world.zoneText, world.hour = 27, "Dun Morogh", 5
check("retail dwarf", math.abs(RaceTarget("Dwarf") - (-51)) < 0.01, ns.Gauge.target)
world.race, world.raceName = "Human", "Human"

-- Line dial when SVG fails

svg.result = false
ns = LoadAddon(true)
svg.result = true
check("svg failure falls back to lines", ns.Gauge.renderer == "lines", ns.Gauge.renderer)
check("no more svg loaded after a failure", #vectorLayers == 1, #vectorLayers)
for _, layer in ipairs(vectorLayers) do
	check("failed svg layer hidden", layer.shown == false)
end

-- Retail client without weather and SVG

svg.supported = false
ns = LoadAddon(false)
svg.supported = true
check("no svg support uses lines", ns.Gauge.renderer == "lines", ns.Gauge.renderer)
check("retail detected", not ns.Sensors.isForever)
check("retail default scale", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
-- Retail default place.
local retailPoint = _G.FeelsLikeGauge.point
check("retail minimap offset", retailPoint and math.abs(retailPoint[4] - 198 / 2 * 1.66 * math.sin(math.rad(158)) / 0.45) < 0.01,
	retailPoint and retailPoint[4])
-- Classic minimap on Retail.
_G.Minimap.GetWidth = function() return 140 end
_G.Minimap.hooks.OnSizeChanged()
retailPoint = _G.FeelsLikeGauge.point
check("retail keeps its place by a classic minimap", retailPoint and math.abs(retailPoint[4] - 140 / 2 * 1.66 * math.sin(math.rad(158)) / 0.45) < 0.01,
	retailPoint and retailPoint[4])
check("retail debug does not name a classic minimap", not Slash("debug"):find("classic-style", 1, true))
_G.Minimap.GetWidth = function() return 198 end
world.mapID, world.zoneText, world.hour = 27, "Dun Morogh", 5
Tick(1)
-- No weather.
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
