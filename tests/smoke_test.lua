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
	widget.GetFont = function() return "Fonts\\FRIZQT__.TTF", 10, "" end
	widget.SetFont = function(self, file, size, flags) self.font = { file, size, flags } end
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
		resist = {},
	}
end
ResetWorld()

local printed = {}
-- Flavor lines sent to the chat frame.
local chatLines = {}
local timers, tickers = {}, {}
local loadedCallback

-- The language of the game client.
local clientLocale = "enUS"

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
	-- Forever's GlobalStrings, build 1.60.1.70707.
	_G.DRUNK_MESSAGE_SELF1 = "You feel sober again."
	_G.DRUNK_MESSAGE_SELF2 = "You feel tipsy. Whee!"
	_G.DRUNK_MESSAGE_SELF3 = "You feel drunk.  Woah!"
	_G.DRUNK_MESSAGE_SELF4 = "You feel completely smashed."
	_G.DRUNK_MESSAGE_ITEM_SELF1 = "You feel sober after the %s."
	_G.DRUNK_MESSAGE_ITEM_SELF2 = "You feel a little tipsy from the %s."
	_G.DRUNK_MESSAGE_ITEM_SELF3 = "You're feeling drunk off of %s."
	_G.DRUNK_MESSAGE_ITEM_SELF4 = "You feel completely smashed after that %s."
	_G.UIParent = Widget()
	_G.GameTooltip = Widget()
	_G.GameTooltip.IsOwned = function() return false end
	-- The tooltip keeps its lines, the title first.
	_G.GameTooltip.lines = {}
	_G.GameTooltip.SetOwner = function(self, owner, anchor) self.owner, self.anchor, self.lines = owner, anchor, {} end
	_G.GameTooltip.SetText = function(self, text) self.lines[1] = text end
	_G.GameTooltip.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
	-- The window that offers a reload.
	_G.StaticPopupDialogs = {}
	_G.StaticPopup_Show = function(name) world.popup = name end
	_G.StaticPopup_Hide = function(name) if world.popup == name then world.popup = nil end end
	_G.ReloadUI = function() world.reloaded = true end
	_G.CreateFrame = function(_, name)
		local frame = Widget()
		createdFrames[#createdFrames + 1] = frame
		if name then _G[name] = frame end
		return frame
	end
	_G.Minimap = Widget()
	_G.InCombatLockdown = function() return world.combat end
	_G.GetLocale = function() return clientLocale end
	_G.UnitIsDeadOrGhost = function() return world.dead end
	_G.UnitIsFeignDeath = function() return world.feign end
	_G.GetTime = function() return world.time end
	_G.UnitPosition = function() return world.pos.y, world.pos.x, 0, world.pos.map end
	_G.GetUnitSpeed = function() return world.speed end
	_G.GetInventoryItemID = function(_, slot) return world.hands[slot] end
	_G.UnitRace = function() return world.raceName, world.race, world.raceID end
	_G.GetShapeshiftFormID = function() return world.form end
	-- base, real, effective and bonus by damage class.
	_G.UnitResistance = function(_, class) return unpack(world.resist[class] or { 0, 0, 0, 0 }) end
	_G.IsShiftKeyDown = function() return world.shift end
	_G.SlashCmdList = {}
	_G.LibStub = nil -- no panel addon by default

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
		GetAreaInfo = function(id)
			return ({ [439] = "The Shimmering Flats", [537] = "Fire Plume Ridge", [2246] = "Frostfire Hot Springs", [5342] = "The Great Forge" })[id]
		end,
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
		_G.C_DateAndTime = {
			IsDayTime = function() return world.hour >= 6 and world.hour < 18 end,
			-- The server's calendar. No date by default, so the old readings have no season.
			GetCurrentCalendarTime = function() return world.date end,
		}
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
-- Every needle that shows at all, solid or fading, as step numbers.
local function ShownNeedles()
	local solid, fading = {}, {}
	for _, layer in ipairs(vectorLayers) do
		if layer.svg and layer.svg:find("Needle", 1, true) and layer.alpha > 0 then
			local list = layer.alpha == 1 and solid or fading
			list[#list + 1] = tonumber(layer.svg:match("(%d%d)%.svg$"))
		end
	end
	return solid, fading
end
local neverGone, neighboursOnly, sawFading, filesNeverReloaded = true, true, false, true
local lowest = Gauge.display
for _ = 1, 200 do
	local onUpdate = gaugeFrame.scripts.OnUpdate
	if not onUpdate then break end -- removed once the needle settles
	onUpdate(gaugeFrame, 0.02)
	lowest = math.min(lowest, Gauge.display)
	local solid, fading = ShownNeedles()
	-- One needle is always solid. At most one more shows, right next to it.
	neverGone = neverGone and #solid >= 1
	local all = {}
	for _, step in ipairs(solid) do all[#all + 1] = step end
	for _, step in ipairs(fading) do all[#all + 1] = step end
	neighboursOnly = neighboursOnly and #all <= 2 and (#all == 1 or math.abs(all[1] - all[2]) == 1)
	sawFading = sawFading or #fading == 1
	for layer, file in pairs(needleFiles) do
		filesNeverReloaded = filesNeverReloaded and layer.svg == file
	end
end
check("a solid needle shows all through the glide", neverGone)
check("at most two needles, side by side", neighboursOnly)
check("the needle glides between two steps", sawFading)
check("needle layers never load a new file", filesNeverReloaded)
check("needle stops updating once settled", gaugeFrame.scripts.OnUpdate == nil)
-- It rests on the step nearest the reading, so only one needle shows.
check("needle settled on the nearest step", math.abs(Gauge.display - (-100 + 200 * 5 / 90)) < 1e-9
	and math.abs(Gauge.display - Gauge.target) <= 200 / 90 / 2, Gauge.display)
check("the needle swings a little past the reading", lowest < Gauge.display - 2 and lowest > Gauge.display - 9, lowest)
local solidAtRest, fadingAtRest = ShownNeedles()
check("one needle at rest", #solidAtRest == 1 and #fadingAtRest == 0, #solidAtRest .. " " .. #fadingAtRest)
check("needle at step 05", VisibleNeedles()[1] == "05", table.concat(VisibleNeedles(), ","))
-- The glow shows the reading itself, not the step the needle rests on.
check("icy ring shown", ringIcy.alpha and math.abs(ringIcy.alpha - 0.6) < 0.01, ringIcy.alpha)
check("the word has a dark outline", fontStrings.GameFontHighlightSmall.font and fontStrings.GameFontHighlightSmall.font[3] == "OUTLINE")
-- A needle that swings past the reading lights no ring the reading does not reach.
Slash("test 82")
local hotRing, flashed = LayerBySvg("ring_hot.svg"), false
for _ = 1, 200 do
	local onUpdate = gaugeFrame.scripts.OnUpdate
	if not onUpdate then break end
	onUpdate(gaugeFrame, 0.02)
	flashed = flashed or hotRing.alpha > 0
end
check("the needle swings past 82", gaugeFrame.scripts.OnUpdate == nil)
check("the hot ring stays dark below Scorching", not flashed, hotRing.alpha)
Slash("test 100")
for _ = 1, 200 do
	local onUpdate = gaugeFrame.scripts.OnUpdate
	if not onUpdate then break end
	onUpdate(gaugeFrame, 0.02)
end
check("the hot ring glows at the top", hotRing.alpha == 1, hotRing.alpha)
Slash("test off")
for _ = 1, 300 do
	local onUpdate = gaugeFrame.scripts.OnUpdate
	if not onUpdate then break end
	onUpdate(gaugeFrame, 0.02)
end
check("the hot ring is dark again in the cold", hotRing.alpha == 0 and math.abs(ringIcy.alpha - 0.6) < 0.01, hotRing.alpha)
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
check("debug shows no resistance", debugText:find("resistance, not counted yet: frost base 0, real 0, effective 0, bonus 0; fire base 0, real 0, effective 0, bonus 0", 1, true), debugText)
world.resist[4], world.resist[2] = { 0, 15, 15, 15 }, { 5, 5, 5, 0 }
debugText = Slash("debug")
check("debug shows frost and fire resistance", debugText:find("frost base 0, real 15, effective 15, bonus 15; fire base 5, real 5, effective 5, bonus 0", 1, true), debugText)
Tick(1)
check("resistance does not count yet", math.abs(Gauge.target - (-88)) < 0.01, Gauge.target)
local resistIsSecret = _G.issecretvalue
_G.issecretvalue = function(value) return value == 15 end
check("secret frost resistance is hidden", Slash("debug"):find("frost hidden; fire base 5", 1, true))
_G.issecretvalue = resistIsSecret
local realResistance = _G.UnitResistance
_G.UnitResistance = nil
check("no resistance API", Slash("debug"):find("resistance, not counted yet: not in this client", 1, true))
_G.UnitResistance = realResistance
world.resist = {}
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
-- The move starts at the press, not after the drag threshold.
local function Press(button)
	gauge.scripts.OnMouseDown(gauge, button or "LeftButton")
end
-- Lets go of the mouse, at a new place when dx is given.
local function Release(dx)
	local realCenter = gauge.GetCenter
	if dx then
		gauge.GetCenter = function() return 500 + dx, 300 end
	end
	gauge.scripts.OnMouseUp(gauge, "LeftButton")
	gauge.GetCenter = realCenter
end
gauge.moving = false
world.shift = false
Press()
check("no move without shift", not gauge.moving)
Release(40)
check("no shift, nothing saved", FeelsLikeDB.x == nil)
printed = {}
gauge.scripts.OnDragStart(gauge)
check("a drag without shift says how to move", #printed == 1 and printed[1]:find("hold Shift and drag", 1, true), printed[1])
gauge.scripts.OnDragStart(gauge)
check("the hint comes once", #printed == 1, #printed)
world.shift = true
Press("RightButton")
check("the right button does not move", not gauge.moving)
Press()
check("shift press moves at once", gauge.moving)
Release()
check("a press without a move saves nothing", FeelsLikeDB.x == nil and gauge.point[2] == _G.Minimap)
gauge.moving = false
Press()
Release(40)
check("drag saves position", FeelsLikeDB.x ~= nil and gauge.point[2] == _G.UIParent)
ns.Gauge:ResetPosition()
check("reset back to minimap", FeelsLikeDB.x == nil and gauge.point[2] == _G.Minimap)
gauge.moving = false
ns.Gauge:SetLocked(true)
Press()
check("locked does not move", not gauge.moving)
world.shift = false
check("mouse on while label shows on hover", gauge.mouse == true)
FeelsLikeDB.label = "never"
ns.Gauge:SetLabelMode("never")
check("locked with the tooltip on keeps the mouse for it", gauge.mouse == true)
settings.FEELSLIKE_TOOLTIP.callback(nil, false)
check("locked without label and tooltip lets clicks through", gauge.mouse == false)
FeelsLikeDB.label = "always"
ns.Gauge:SetLabelMode("always")
check("locked with the word always shown and no tooltip lets clicks through", gauge.mouse == false)
settings.FEELSLIKE_TOOLTIP.callback(nil, true)
check("the tooltip setting turns the mouse back on", gauge.mouse == true)
FeelsLikeDB.locked, FeelsLikeDB.label = false, "hover"
ns.Gauge:SetLocked(false)
ns.Gauge:SetLabelMode("hover")
check("mouse back on", gauge.mouse == true)

-- A plain drag saves nothing.
world.shift = false
Press()
Release(40)
check("plain drag saves nothing", FeelsLikeDB.x == nil and gauge.point[2] == _G.Minimap)

-- The tooltip says the word, the reasons and how to move the gauge.
local function TooltipText()
	return table.concat(GameTooltip.lines, " | ")
end
local before = { world.mapID, world.zoneText, world.hour, world.weather }
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 5
world.weather = { type = 2, intensity = 1 }
Tick(2)
gauge.scripts.OnEnter()
check("tooltip shown on hover", GameTooltip.shown == true and GameTooltip.owner == gauge)
check("tooltip names the word and the reasons",
	TooltipText() == "Freezing | Why: |cff8fd9f0a cold place, snow, the night|r | Shift-drag to move", TooltipText())
GameTooltip.lines = {}
Tick(1)
check("an open tooltip with nothing new is left alone", #GameTooltip.lines == 0, #GameTooltip.lines)
world.weather = { type = 0, intensity = 0 }
Tick(1)
check("tooltip follows the reading while it is open",
	TooltipText() == "Freezing | Why: |cff8fd9f0a cold place, the night|r | Shift-drag to move", TooltipText())
Slash("test 50")
check("tooltip says a test runs at once", TooltipText():find("Hot | A test value", 1, true), TooltipText())
Tick(1)
check("tooltip says a test runs", TooltipText():find("Hot | A test value", 1, true), TooltipText())
Slash("test off")
-- The tooltip can be turned off in the settings. The word next to the gauge stays.
settings.FEELSLIKE_TOOLTIP.callback(nil, false)
check("tooltip off hides an open tooltip", GameTooltip.shown == false and FeelsLikeDB.tooltip == false)
gauge.scripts.OnLeave()
GameTooltip.lines = {}
gauge.scripts.OnEnter()
Tick(1)
check("no tooltip on hover while it is off", #GameTooltip.lines == 0 and GameTooltip.shown == false, #GameTooltip.lines)
check("the word still shows on hover", fontStrings.GameFontHighlightSmall.shown == true)
settings.FEELSLIKE_TOOLTIP.callback(nil, true)
check("tooltip on shows it again at once", GameTooltip.shown == true and #GameTooltip.lines > 1, #GameTooltip.lines)
gauge.scripts.OnLeave()
check("tooltip hidden off the gauge", GameTooltip.shown == false)
GameTooltip.lines = {}
Tick(1)
check("no tooltip work while the mouse is away", #GameTooltip.lines == 0)
world.mapID, world.zoneText, world.hour, world.weather = before[1], before[2], before[3], before[4]

-- Hover state does not stick when the mouse is off.
gauge.scripts.OnEnter()
FeelsLikeDB.locked, FeelsLikeDB.label = true, "never"
settings.FEELSLIKE_TOOLTIP.callback(nil, false)
ns.Gauge:SetLocked(true)
ns.Gauge:SetLabelMode("never")
FeelsLikeDB.locked, FeelsLikeDB.label = false, "hover"
settings.FEELSLIKE_TOOLTIP.callback(nil, true)
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
check("dried in the heat", math.abs(Gauge.target - 95) < 0.01, Gauge.target)

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
check("molten core", Gauge.target == 95, Gauge.target)
world.instance = { "Deadmines", "party", 1, "", 5, 0, false, 36 }
Tick(1)
check("unknown instance neutral", Gauge.target == 0, Gauge.target)
world.instance = { "Dun Morogh", "none", 0, "", 0, 0, false, 0 }
world.indoors = false

-- Subzone overrides the zone.
world.mapID, world.zoneText, world.subzoneText, world.hour = 1449, "Un'Goro Crater", "Fire Plume Ridge", 15
Tick(1)
check("subzone override", Gauge.target == 90, Gauge.target)
-- A swim in a hot spring chills nothing. The wet clothes chill on the shore.
world.mapID, world.zoneText, world.subzoneText = 1452, "Winterspring", "Frostfire Hot Springs"
Tick(1)
check("hot spring shore", math.abs(Gauge.target - 18) < 0.01, Gauge.target)
world.swimming = true
Tick(3)
check("a swim in a hot spring chills nothing", math.abs(Gauge.target - 18) < 0.01, Gauge.target)
check("debug shows hot water", Slash("debug"):find("swimming in hot water, wetness 1.00: +0.0", 1, true))
world.swimming = false
Tick(1)
check("out of the hot spring the wet clothes chill", Gauge.target < -30, Gauge.target)
Tick(200)
world.subzoneText = ""
-- A roof keeps no volcanic heat out.
world.mapID, world.zoneText, world.indoors = 1427, "Searing Gorge", true
Tick(4)
check("a searing gorge cave is as hot as outside", Gauge.target == 85, Gauge.target)
check("debug says no shelter from ground heat", Slash("debug"):find("indoors, no shelter from the heat of the ground: +85.0", 1, true))
world.indoors = false
Tick(4)

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
check("debug shows the beat of the fire", Slash("debug"):find("(fire hits 2.0 s apart)", 1, true))
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
-- Lava in a fight, on hot ground: the second hit on its beat tells it from a spell, and the swim soaks nothing.
world.mapID, world.zoneText = 1427, "Searing Gorge"
Tick(1)
local hotReading = Gauge.target
check("searing gorge reading", hotReading == 85, hotReading)
world.combat, world.swimming = true, true
FireHit()
Tick(2)
check("one fire hit in the water in a fight is a spell", Gauge.target == hotReading, Gauge.target)
check("debug says it may be lava", Slash("debug"):find("a fire hit in the water, lava if the next comes soon", 1, true))
FireHit()
check("lava in a fight burns", Gauge.target == 100, Gauge.target)
Tick(2)
FireHit()
check("lava in a fight keeps burning", Gauge.target == 100, Gauge.target)
world.combat, world.swimming = false, false
Tick(40) -- the warmth of the fight is gone by then
check("lava in a fight leaves you dry", math.abs(Gauge.target - hotReading) < 0.01, Gauge.target)
-- Two fire hits in the same moment in the water are one spell, not the lava beat.
world.combat, world.swimming = true, true
FireHit()
FireHit()
check("two fire hits at once in the water are no lava", Gauge.target == hotReading, Gauge.target)
world.combat, world.swimming = false, false
Tick(200)
-- A fire hit long after the last one has no beat to show.
FireHit()
check("debug shows no gap between unrelated fire hits", not Slash("debug"):find("fire hits", 1, true))
Tick(20)
-- A fight that starts while you swim in lava changes nothing.
world.swimming = true
FireHit()
Tick(2)
world.combat = true
FireHit()
Tick(2)
check("a fight that starts in lava keeps burning", Gauge.target == 100, Gauge.target)
world.combat, world.swimming = false, false
Tick(10)
-- Seasons and holidays follow the server's calendar.
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
world.date = { month = 4, monthDay = 10 }
Tick(1)
check("spring has no season step", Gauge.target == 15 and Slash("debug"):find("season none (month 4, day 10): +0.0", 1, true), Gauge.target)
world.date = { month = 12, monthDay = 24 }
Tick(1)
check("winter veil is colder", Gauge.target == 7, Gauge.target)
check("debug names the holiday", Slash("debug"):find("season Winter Veil (month 12, day 24): -8.0", 1, true))
world.date = { month = 7, monthDay = 20 }
Tick(1)
check("summer is warmer", Gauge.target == 20, Gauge.target)
world.date = nil
Tick(1)
check("no calendar, no season", Gauge.target == 15 and Slash("debug"):find("season none (no calendar): +0.0", 1, true), Gauge.target)
world.hour = 3
-- The Great Forge has lava, though Ironforge is not volcanic.
world.mapID, world.zoneText, world.subzoneText = 1455, "Ironforge", "The Great Forge"
Tick(1)
check("the great forge reading", Gauge.target == 45, Gauge.target)
world.combat, world.swimming = true, true
FireHit()
Tick(2)
FireHit()
check("lava in the great forge burns in a fight", Gauge.target == 100, Gauge.target)
world.combat, world.swimming = false, false
world.subzoneText = ""
Tick(10)
-- Away from hot ground a fire DoT in a lake is a spell at any beat, and the lake soaks.
world.mapID, world.zoneText = 1426, "Dun Morogh"
Tick(1)
check("back in the cold", math.abs(Gauge.target - coldReading) < 0.01, Gauge.target)
world.combat, world.swimming = true, true
Tick(10) -- soaked, and as warm as the fight makes you
local lakeReading = Gauge.target
for _ = 1, 3 do
	FireHit()
	Tick(2)
end
check("a fast fire DoT in a lake is no lava", math.abs(Gauge.target - lakeReading) < 0.01 and lakeReading < 0, Gauge.target)
check("a fire DoT in a lake leaves you soaked", Slash("debug"):find("wetness 1.00", 1, true))
check("no lava guess in a lake", not Slash("debug"):find("lava if the next comes soon", 1, true))
world.combat, world.swimming = false, false
Tick(200)
CoreEvent("UNIT_COMBAT", "player", "HEAL", "", 120, 4)
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 0, 4)
NextFrame()
check("heal and zero ignored", Gauge.target == coldReading, Gauge.target)
-- A frost spell chills for a moment, in a fight or out of it.
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
Tick(1)
local mildReading = Gauge.target
check("elwynn afternoon", mildReading == 15, mildReading)
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 120, 16)
check("a frost spell chills at once", Gauge.target == -85, Gauge.target)
check("debug shows the frost spell", Slash("debug"):find("frost spell 1.00: -100.0", 1, true))
Tick(1)
check("a frost spell holds a moment", Gauge.target == -85, Gauge.target)
Tick(2)
check("a frost spell fades", Gauge.target > -85 and Gauge.target < mildReading, Gauge.target)
Tick(2)
check("a frost spell faded", Gauge.target == mildReading, Gauge.target)
world.combat = true
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 120, 16)
check("a frost spell chills in a fight too", Gauge.target == -85, Gauge.target)
world.combat = false
Tick(10)
CoreEvent("UNIT_COMBAT", "player", "HEAL", "", 120, 16)
CoreEvent("UNIT_COMBAT", "player", "WOUND", "", 0, 16)
check("a frost heal or a miss chills nothing", Gauge.target == mildReading, Gauge.target)
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 3
Tick(1)
check("back in dun morogh", math.abs(Gauge.target - coldReading) < 0.01, Gauge.target)
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
check("old default scale moves to the new one", FeelsLikeDB.scale == 0.53 and FeelsLikeDB.version == 3, FeelsLikeDB.scale)
check("other saved settings stay", FeelsLikeDB.unit == "F")
ns = LoadAddon(true, { scale = 0.6 })
check("a chosen scale stays", FeelsLikeDB.scale == 0.6, FeelsLikeDB.scale)
ns = LoadAddon(true, { scale = 0.45, version = 2 })
check("0.45 chosen after the move stays", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
ns = LoadAddon(false, { scale = 0.45 })
check("retail keeps 0.45", FeelsLikeDB.scale == 0.45, FeelsLikeDB.scale)
check("old save gets the race setting", FeelsLikeDB.race == true, FeelsLikeDB.race)
check("old save gets the undead setting", FeelsLikeDB.undead == "numb", FeelsLikeDB.undead)
-- Always cold of 0.2.0 is gone: the saved choice goes back to numb, so the settings show a real choice.
ns = LoadAddon(true, { undead = "cold" })
check("a saved always cold becomes numb", FeelsLikeDB.undead == "numb", FeelsLikeDB.undead)
ns = LoadAddon(true, { undead = "living" })
check("a saved like the living stays", FeelsLikeDB.undead == "living", FeelsLikeDB.undead)

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
Tick(4) -- back from the ghost's Cold, the real word settles first
check("the line after coming back", #chatLines == 1, #chatLines)
Tick(15 * 60) -- long after the line, so only the ghost's cold could bring it back
world.dead = true
Tick(10)
world.dead = false
Tick(10)
check("no new line back in the same cold", #chatLines == 1, #chatLines)
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

-- The undead do not breathe or sweat: their own weather lines, shared fire and Cozy lines.
LoadQuietly()
world.race, world.raceName = "Scourge", "Undead"
FeelsLikeDB.undead = "living" -- feels like a human, still does not breathe
GoMild()
Tick(2)
GoFreezing()
Tick(4)
check("undead freezing line", #chatLines == 1 and LastLine() == "The frost stiffens your dead joints.", LastLine())
world.mapID, world.zoneText, world.hour = 1446, "Tanaris", 15
world.weather = { type = 0, intensity = 0 }
Tick(61)
check("undead scorching line", #chatLines == 2 and LastLine() == "The heat is unbearable, even for the dead.", LastLine())
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
world.indoors, world.resting = true, true
Tick(61)
check("undead share the cozy lines", #chatLines == 3 and LastLine() == "The warmth of the inn wraps around you.", LastLine())
world.indoors, world.resting = false, false
world.race, world.raceName = "Human", "Human"

-- Soaked clothes, rain, a torch and a drink have lines too.
LoadQuietly()
GoMild()
world.hour = 15
Tick(2)
world.swimming = true
Tick(3)
world.swimming = false
Tick(5)
check("soaked line", #chatLines == 1 and LastLine() == "Your wet clothes cling to you.", LastLine())
check("debug names the soaked line", Slash("debug"):find("last: Soaked", 1, true))
Tick(200)
world.weather = { type = 1, intensity = 1 }
Tick(5)
check("rain line on a mild day", #chatLines == 2 and LastLine() == "Rain runs down your neck.", LastLine())
world.weather = { type = 0, intensity = 0 }
world.hour = 5
Tick(200)
world.hands[16] = 6182
Tick(1)
check("a torch lit in the cold has a line", #chatLines == 3 and LastLine() == "The torch warms your hand.", LastLine())
Tick(5)
check("the torch line comes once", #chatLines == 3, #chatLines)
world.hands = {}
Tick(61)
CoreEvent("CHAT_MSG_SYSTEM", "You feel tipsy. Whee!")
check("a drink in the cold has a line", #chatLines == 4 and LastLine() == "The drink warms you from the inside.", LastLine())
Tick(700)
CoreEvent("CHAT_MSG_SYSTEM", "You feel tipsy. Whee!")
check("the same drink level says nothing", #chatLines == 4, #chatLines)
world.hour = 15
Tick(1)
CoreEvent("CHAT_MSG_SYSTEM", "You feel drunk.  Woah!")
check("a drink on a warm day says nothing", #chatLines == 4, #chatLines)
CoreEvent("CHAT_MSG_SYSTEM", "You feel sober again.")
-- Fur has its own lines for the cold and the heat.
LoadQuietly()
world.race, world.raceName = "Tauren", "Tauren"
GoMild()
Tick(2)
GoFreezing()
world.hour = 5
Tick(4)
check("fur line in the cold", #chatLines == 1 and LastLine() == "Your fur bristles in the cold.", LastLine())
world.race, world.raceName = "Human", "Human"

-- A panel addon like Titan Panel brings LibDataBroker: the word goes there too.
ns, settings = LoadAddon(true)
check("no panel feed without a panel addon", Slash("debug"):find("panel feed: off, no panel addon with LibDataBroker-1.1", 1, true))
local dataObjects = {}
_G.LibStub = {
	GetLibrary = function(_, name, silent)
		return name == "LibDataBroker-1.1" and silent and {
			NewDataObject = function(_, objectName, object)
				dataObjects[objectName] = object
				return object
			end,
		} or nil
	end,
}
CoreEvent("PLAYER_ENTERING_WORLD", true, false) -- the panel loaded after this addon
local feed = dataObjects["Feels Like"]
check("panel feed registered", feed ~= nil and feed.type == "data source" and feed.icon == "Interface\\AddOns\\FeelsLike\\Media\\Icon")
check("debug says the panel feed is on", Slash("debug"):find("panel feed: on (LibDataBroker-1.1)", 1, true))
check("panel feed shows the colored word", feed and feed.text == "|cff6e9bffFreezing|r", feed and feed.text)
GoMild()
world.hour = 15
Tick(1)
check("panel feed follows the reading", feed and feed.text == "|cffdcdcdcMild|r", feed and feed.text)
Slash("test -90")
check("panel feed keeps the real reading in a test", feed and feed.text == "|cffdcdcdcMild|r", feed and feed.text)
Slash("test off")
local panelLines = {}
feed.OnTooltipShow({ AddLine = function(_, text) panelLines[#panelLines + 1] = text end })
check("panel tooltip", table.concat(panelLines, " | ") == "Feels Like | Mild | Why: |cfff5a345the sun, a warm place|r | Click to open the settings",
	table.concat(panelLines, " | "))
settings.opened = nil
feed.OnClick()
check("a click on the panel feed opens the settings", settings.opened == 7, settings.opened)
CoreEvent("PLAYER_ENTERING_WORLD", false, false)
check("the feed registers once", dataObjects["Feels Like"] == feed)
_G.LibStub = nil

-- Ukrainian: the word, the tooltip, the lines in chat, the hints and the settings.
ns, settings = LoadAddon(true, { language = "uk", label = "always" })
check("language setting registered", settings.FEELSLIKE_LANGUAGE ~= nil and settings.FEELSLIKE_SEASONS ~= nil)
Tick(10)
check("ukrainian word next to the gauge", fontStrings.GameFontHighlightSmall.text == "Морозно", fontStrings.GameFontHighlightSmall.text)
local ukGauge = _G.FeelsLikeGauge
ukGauge.scripts.OnEnter()
check("ukrainian tooltip", table.concat(GameTooltip.lines, " | ")
	== "Морозно | Чому: |cff8fd9f0холодне місце, сніг, ніч|r | Shift + тягни, щоб пересунути", table.concat(GameTooltip.lines, " | "))
ukGauge.scripts.OnLeave()
GoMild()
Tick(2)
GoFreezing()
Tick(4)
check("ukrainian line in chat", #chatLines == 1 and LastLine() == "Ти тремтиш від холоду. (/shiver)", LastLine())
printed = {}
ukGauge.scripts.OnDragStart(ukGauge)
check("ukrainian hint about Shift", printed[1] and printed[1]:find("затисни Shift і тягни", 1, true), printed[1])
world.combat = true
check("ukrainian combat note", Slash(""):find("налаштування відкриються після бою", 1, true))
world.combat = false
check("debug stays english", Slash("debug"):find("felt -88.0, target -88.0: Freezing", 1, true))
local apiValue, apiWord = FeelsLike.GetTemperature()
check("the api word stays english", apiWord == "Freezing", apiWord)
-- Back to English at once, from the settings.
printed = {}
settings.FEELSLIKE_LANGUAGE.callback(nil, "en")
check("english word at once", fontStrings.GameFontHighlightSmall.text == "Freezing", fontStrings.GameFontHighlightSmall.text)
-- The settings page was built in Ukrainian, so a window offers a reload, in the new language.
local popup = StaticPopupDialogs.FEELSLIKE_RELOAD
check("a window offers a reload", world.popup == "FEELSLIKE_RELOAD" and popup ~= nil and popup.button1 == "Reload"
	and popup.text:find("Reload now?", 1, true) ~= nil, world.popup)
check("nothing in chat about it", printed[1] == nil, printed[1])
world.reloaded = nil
popup.OnAccept()
check("its button reloads the interface", world.reloaded == true)
settings.FEELSLIKE_LANGUAGE.callback(nil, "uk")
check("ukrainian word at once", fontStrings.GameFontHighlightSmall.text == "Морозно", fontStrings.GameFontHighlightSmall.text)
check("back to the language of the page: no window", world.popup == nil, world.popup)
-- From an English page to Ukrainian the window speaks Ukrainian.
ns, settings = LoadAddon(true, { label = "always" })
settings.FEELSLIKE_LANGUAGE.callback(nil, "uk")
popup = StaticPopupDialogs.FEELSLIKE_RELOAD
check("the window speaks the new language", world.popup == "FEELSLIKE_RELOAD" and popup.button1 == "Перезавантажити"
	and popup.button2 == "Пізніше" and popup.text:find("мову змінено", 1, true) ~= nil, popup and popup.text)
world.popup = nil
-- Without the game's windows the hint goes to chat.
local showPopup = StaticPopup_Show
_G.StaticPopup_Show = nil
printed = {}
settings.FEELSLIKE_LANGUAGE.callback(nil, "en")
check("no window: the hint goes to chat", printed[1] and printed[1]:find("type /reload to change the settings page too", 1, true), printed[1])
_G.StaticPopup_Show = showPopup
ns, settings = LoadAddon(true, { language = "uk", label = "always" })
Tick(10)
-- The panel feed speaks Ukrainian too.
local ukObjects = {}
_G.LibStub = { GetLibrary = function() return { NewDataObject = function(_, name, object) ukObjects[name] = object return object end } end }
CoreEvent("PLAYER_ENTERING_WORLD", false, true)
local ukLines = {}
ukObjects["Feels Like"].OnTooltipShow({ AddLine = function(_, text) ukLines[#ukLines + 1] = text end })
check("ukrainian panel feed", ukObjects["Feels Like"].text == "|cff6e9bffМорозно|r"
	and table.concat(ukLines, " | ") == "Feels Like | Морозно | Чому: |cff8fd9f0холодне місце, сніг, ніч|r | Клацни, щоб відкрити налаштування",
	table.concat(ukLines, " | "))
_G.LibStub = nil
local missing = {}
for text in pairs(ns.Locale.missing) do
	missing[#missing + 1] = text
end
check("every text shown has a ukrainian one", #missing == 0, table.concat(missing, " / "))
ns = LoadAddon(true, { language = "klingon" })
check("an unknown saved language is english", FeelsLikeDB.language == "en", FeelsLikeDB.language)

-- A German game: German with no choice saved, and a choice stays.
clientLocale = "deDE"
ns = LoadAddon(true, { label = "always" })
check("a german game starts in german", FeelsLikeDB.language == "de", FeelsLikeDB.language)
Tick(10)
check("german word next to the gauge", fontStrings.GameFontHighlightSmall.text == "Eisig", fontStrings.GameFontHighlightSmall.text)
_G.FeelsLikeGauge.scripts.OnEnter()
check("german tooltip", table.concat(GameTooltip.lines, " | ")
	== "Eisig | Warum: |cff8fd9f0ein kalter Ort, Schnee, die Nacht|r | Umschalt + Ziehen zum Verschieben", table.concat(GameTooltip.lines, " | "))
_G.FeelsLikeGauge.scripts.OnLeave()
ns = LoadAddon(true, { language = "en", version = 2 })
check("english saved before there was a choice of german follows the game", FeelsLikeDB.language == "de", FeelsLikeDB.language)
ns = LoadAddon(true, { language = "en", version = 3 })
check("english chosen in a german game stays", FeelsLikeDB.language == "en", FeelsLikeDB.language)
ns = LoadAddon(true, { language = "uk", version = 2 })
check("ukrainian chosen in a german game stays", FeelsLikeDB.language == "uk", FeelsLikeDB.language)
ns = LoadAddon(true, { language = "klingon" })
check("an unknown saved language follows the game", FeelsLikeDB.language == "de", FeelsLikeDB.language)
-- A French game. French puts a space before the colon.
clientLocale = "frFR"
ns = LoadAddon(true, { label = "always" })
check("a french game starts in french", FeelsLikeDB.language == "fr", FeelsLikeDB.language)
Tick(10)
_G.FeelsLikeGauge.scripts.OnEnter()
check("french tooltip", table.concat(GameTooltip.lines, " | ")
	== "Glacial | Pourquoi : |cff8fd9f0un lieu froid, la neige, la nuit|r | Maj + glisser pour déplacer", table.concat(GameTooltip.lines, " | "))
_G.FeelsLikeGauge.scripts.OnLeave()
-- Spain and Latin America share the Spanish text.
clientLocale = "esMX"
ns = LoadAddon(true, { label = "always" })
check("a latin american game starts in spanish", FeelsLikeDB.language == "es", FeelsLikeDB.language)
Tick(10)
_G.FeelsLikeGauge.scripts.OnEnter()
check("spanish tooltip", table.concat(GameTooltip.lines, " | ")
	== "Gélido | Motivo: |cff8fd9f0un lugar frío, la nieve, la noche|r | Mayús + arrastrar para mover", table.concat(GameTooltip.lines, " | "))
_G.FeelsLikeGauge.scripts.OnLeave()
clientLocale = "ptBR"
ns = LoadAddon(true, { label = "always" })
check("a brazilian game starts in portuguese", FeelsLikeDB.language == "pt", FeelsLikeDB.language)
Tick(10)
_G.FeelsLikeGauge.scripts.OnEnter()
check("portuguese tooltip", table.concat(GameTooltip.lines, " | ")
	== "Congelante | Motivo: |cff8fd9f0um lugar frio, a neve, a noite|r | Shift + arrastar para mover", table.concat(GameTooltip.lines, " | "))
_G.FeelsLikeGauge.scripts.OnLeave()
clientLocale = "enUS"
ns = LoadAddon(true, { language = "en", version = 2 })
check("english stays english in an english game", FeelsLikeDB.language == "en", FeelsLikeDB.language)

-- An undead in Tirisfal Glades, a cool place: by day it is Mild whatever the race settings say, and the
-- reasons of a Mild reading start with the side that wins.
ns, settings = LoadAddon(true)
world.race, world.raceName = "Scourge", "Undead"
world.mapID, world.zoneText, world.hour = 1420, "Tirisfal Glades", 13
world.weather = { type = 0, intensity = 0 }
local function Reading()
	Tick(1)
	return ns.Gauge.target, ns.Model.Band(ns.Gauge.target, ns.Gauge.cozy).word
end
local numbDay, numbDayWord = Reading()
FeelsLikeDB.undead = "living"
local livingDay, livingDayWord = Reading()
FeelsLikeDB.race = false
local plainDay = Reading()
check("tirisfal by day is mild for every undead setting", numbDayWord == "Mild" and livingDayWord == "Mild"
	and livingDay == plainDay and math.abs(numbDay - livingDay) < 5, numbDay .. " " .. livingDay .. " " .. plainDay)
local tirisfalGauge = _G.FeelsLikeGauge
tirisfalGauge.scripts.OnEnter()
check("a mild reading on the cold half names the cold first", table.concat(GameTooltip.lines, " | ")
	== "Mild | Why: |cff8fd9f0a cool place|r, |cfff5a345the sun|r | Shift-drag to move", table.concat(GameTooltip.lines, " | "))
world.indoors = true
Tick(3)
Tick(1)
check("under a roof it is on the warm half and names the roof first", ns.Gauge.target > 0 and table.concat(GameTooltip.lines, " | ")
	== "Mild | Why: |cfff5a345a roof|r, |cff8fd9f0a cool place|r | Shift-drag to move", table.concat(GameTooltip.lines, " | "))
tirisfalGauge.scripts.OnLeave()
world.indoors = false
-- The settings show at night: Cold like the living, Mild for numb flesh.
world.hour = 5
Tick(3)
FeelsLikeDB.race, FeelsLikeDB.undead = true, "living"
local _, livingNightWord = Reading()
FeelsLikeDB.undead = "numb"
local _, numbNightWord = Reading()
check("tirisfal before dawn: cold like the living, mild when numb", livingNightWord == "Cold" and numbNightWord == "Mild",
	livingNightWord .. " " .. numbNightWord)
world.race, world.raceName = "Human", "Human"

-- The game's own outlined font is used for the word when the game has one: it knows every alphabet.
_G.GameFontHighlightSmallOutline = {}
fontStrings.GameFontHighlightSmallOutline = nil
LoadAddon(true)
check("the word uses the game's outlined font", fontStrings.GameFontHighlightSmallOutline ~= nil
	and rawget(fontStrings.GameFontHighlightSmallOutline, "font") == nil)
_G.GameFontHighlightSmallOutline = nil

-- A fight warms you up, and you cool down after it.
ns, settings = LoadAddon(true)
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
world.weather = { type = 0, intensity = 0 }
Tick(2)
local calm = ns.Gauge.target
check("no fight, no warmth", Slash("debug"):find("fight 0.00: +0.0", 1, true), calm)
world.combat = true
Tick(4)
check("a fight warms you bit by bit", math.abs(ns.Gauge.target - (calm + 6)) < 0.01, ns.Gauge.target)
Tick(10)
check("a fight warms you by 12 at most", math.abs(ns.Gauge.target - (calm + 12)) < 0.01, ns.Gauge.target)
check("debug shows the fight", Slash("debug"):find("fight 1.00: +12.0", 1, true))
local fightGauge = _G.FeelsLikeGauge
fightGauge.scripts.OnEnter()
check("the tooltip names the fight", table.concat(GameTooltip.lines, " | "):find("a fight", 1, true), table.concat(GameTooltip.lines, " | "))
fightGauge.scripts.OnLeave()
world.combat = false
Tick(15)
check("you cool down after the fight", math.abs(ns.Gauge.target - (calm + 6)) < 0.01, ns.Gauge.target)
Tick(20)
check("the warmth of the fight is gone after 30 s", ns.Gauge.target == calm, ns.Gauge.target)

-- The reasons are worked out only while a tooltip is open, and once per reading.
local reasonCalls, realReasons = 0, ns.Model.Reasons
ns.Model.Reasons = function(...)
	reasonCalls = reasonCalls + 1
	return realReasons(...)
end
Tick(5)
check("no reasons worked out with no tooltip open", reasonCalls == 0, reasonCalls)
fightGauge.scripts.OnEnter()
check("an open tooltip works them out once", reasonCalls == 1, reasonCalls)
fightGauge.scripts.OnLeave()
fightGauge.scripts.OnEnter()
check("the same reading is not worked out twice", reasonCalls == 1, reasonCalls)
Tick(1)
check("a new reading is worked out again while the tooltip is open", reasonCalls == 2, reasonCalls)
fightGauge.scripts.OnLeave()
ns.Model.Reasons = realReasons

-- The tooltip opens toward the middle of the screen.
-- x and y are on the screen, 1000 by 600 here. The gauge reports its place in its own scale.
local function AnchorAt(x, y)
	local scale = fightGauge:GetScale()
	fightGauge.GetCenter = function() return x / scale, y / scale end
	fightGauge.scripts.OnEnter()
	local anchor = GameTooltip.anchor
	fightGauge.scripts.OnLeave()
	return anchor
end
check("top right: the tooltip opens down and left", AnchorAt(900, 500) == "ANCHOR_BOTTOMLEFT", GameTooltip.anchor)
check("top left: down and right", AnchorAt(100, 500) == "ANCHOR_BOTTOMRIGHT", GameTooltip.anchor)
check("bottom right: up and left", AnchorAt(900, 100) == "ANCHOR_LEFT", GameTooltip.anchor)
check("bottom left: up and right", AnchorAt(100, 100) == "ANCHOR_RIGHT", GameTooltip.anchor)

-- Seasons and holidays can be turned off.
ns = LoadAddon(true)
check("seasons on by default", FeelsLikeDB.seasons == true)
world.mapID, world.zoneText, world.hour = 1429, "Elwynn Forest", 15
world.weather = { type = 0, intensity = 0 }
world.date = { month = 12, monthDay = 24 }
Tick(1)
check("winter veil counts by default", ns.Gauge.target == 7, ns.Gauge.target)
FeelsLikeDB.seasons = false
Tick(1)
check("no season with the setting off", ns.Gauge.target == 15, ns.Gauge.target)
check("debug says seasons are off", Slash("debug"):find("season none (off in settings): +0.0", 1, true))
FeelsLikeDB.seasons = true
world.date = nil

-- Dead: the same cold everywhere until you are back.
ns = LoadAddon(true)
world.dead = true
Tick(1)
check("a ghost feels cold", ns.Gauge.target == -65 and ns.Gauge.cozy == false, ns.Gauge.target)
local ghostValue, ghostWord = FeelsLike.GetTemperature()
check("api gives the ghost's cold", ghostValue == -65 and ghostWord == "Cold", tostring(ghostValue) .. " " .. tostring(ghostWord))
check("debug says dead", Slash("debug"):find("dead: the reading stays at -65.0 until you are back", 1, true))
world.mapID, world.zoneText, world.hour = 1446, "Tanaris", 15
world.weather = { type = 0, intensity = 0 }
Tick(1)
check("a ghost in the desert feels the same", ns.Gauge.target == -65, ns.Gauge.target)
world.indoors, world.resting = true, true
Tick(3)
check("a ghost in an inn is not cozy", ns.Gauge.target == -65 and ns.Gauge.cozy == false, ns.Gauge.target)
world.indoors, world.resting = false, false
world.swimming = true
Tick(3)
world.swimming = false
world.dead = false
Tick(1)
check("a ghost's swim leaves the body dry", Slash("debug"):find("wetness 0.00", 1, true))
check("back alive, the desert again", ns.Gauge.target > 90, ns.Gauge.target)
check("debug no longer says dead", not Slash("debug"):find("dead:", 1, true))
world.dead, world.feign = true, true
Tick(1)
check("feign death is alive", ns.Gauge.target > 90 and not Slash("debug"):find("dead:", 1, true), ns.Gauge.target)
local feignIsSecret = _G.issecretvalue
world.feign = "secret"
_G.issecretvalue = function(value) return value == "secret" end
Tick(1)
check("a secret feign death counts as dead", ns.Gauge.target == -65, ns.Gauge.target)
_G.issecretvalue = feignIsSecret
world.dead, world.feign = false, false

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
FeelsLikeDB.undead = "living"
check("undead like the living", math.abs(RaceTarget("Scourge", "Undead") - (-88)) < 0.01, ns.Gauge.target)
check("debug says like the living", Slash("debug"):find("race Scourge (Undead), like the living, cold x1.00, heat x1.00: +0.0", 1, true))
FeelsLikeDB.undead = "zombie"
check("a bad undead value is numb", math.abs(RaceTarget("Scourge", "Undead") - (-44)) < 0.01, ns.Gauge.target)
-- Always cold of 0.2.0 is gone: a saved choice reads as numb.
FeelsLikeDB.undead = "cold"
check("always cold of 0.2.0 is numb now", math.abs(RaceTarget("Scourge", "Undead") - (-44)) < 0.01, ns.Gauge.target)
check("debug says numb for the old choice", Slash("debug"):find("race Scourge (Undead), numb, cold x0.50, heat x0.60", 1, true))
FeelsLikeDB.undead = "living"
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
for _, form in ipairs({ 3, 4, 5, 8, 31 }) do
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
-- Fire spells in a fight scorch the undead.
check("numb undead before the fight", math.abs(RaceTarget("Scourge", "Undead") - (-44)) < 0.01, ns.Gauge.target)
world.combat = true
FireHit()
check("a fireball scorches the undead", ns.Gauge.target == 100, ns.Gauge.target)
debugText = Slash("debug")
check("debug shows fire spells", debugText:find("fire underfoot 0.00, fire spells 1.00 (undead): +144.0", 1, true), debugText)
Tick(1)
check("a fireball holds a moment", ns.Gauge.target == 100, ns.Gauge.target)
Tick(2)
check("a fireball fades", ns.Gauge.target > -44 and ns.Gauge.target < 100, ns.Gauge.target)
Tick(2)
-- The fight itself warms a little: 7.5 after 5 s, then 9, 10.5 and 12 in the checks below.
check("a fireball faded", math.abs(ns.Gauge.target - (-44 + 7.5)) < 0.01, ns.Gauge.target)
FeelsLikeDB.undead = "living"
Tick(1)
FireHit()
check("a fireball does not burn undead like the living", math.abs(ns.Gauge.target - (-88 + 9)) < 0.01, ns.Gauge.target)
check("debug has no fire spells for undead like the living", not Slash("debug"):find("fire spells", 1, true))
FeelsLikeDB.undead = "numb"
FeelsLikeDB.race = false
Tick(1)
FireHit()
check("a fireball does not burn with race off", math.abs(ns.Gauge.target - (-88 + 10.5)) < 0.01, ns.Gauge.target)
FeelsLikeDB.race = true
check("a fireball does not burn a human", math.abs(RaceTarget("Human") - (-88 + 12)) < 0.01 and FireHit()
	and math.abs(ns.Gauge.target - (-88 + 12)) < 0.01, ns.Gauge.target)
check("debug has no fire spells for a human", not Slash("debug"):find("fire spells", 1, true))
Tick(5)
-- Just after the fight, fire is still a spell.
RaceTarget("Scourge", "Undead")
world.combat = false
CoreEvent("PLAYER_REGEN_ENABLED")
Tick(5)
FireHit()
check("a fire DoT after the fight scorches the undead", ns.Gauge.target == 100, ns.Gauge.target)
check("debug shows a fire spell after the fight", Slash("debug"):find("fire underfoot 0.00, fire spells 1.00", 1, true))
Tick(11)
FireHit()
check("fire underfoot after the grace", Slash("debug"):find("fire underfoot 1.00, fire spells 0.00", 1, true))
Tick(10)
-- A fire spell does not dry wet clothes at once.
world.swimming = true
Tick(1)
world.swimming = false
world.combat = true
FireHit()
Tick(1)
world.combat = false
check("a fireball leaves clothes wet", not Slash("debug"):find("wetness 0.00", 1, true))
Tick(300)
-- Fire spells do not dry clothes faster either.
local function WetnessAfterFight(fireballs)
	world.swimming = true
	Tick(1)
	world.swimming = false
	world.combat = true
	for _ = 1, 20 do
		if fireballs then
			FireHit()
		end
		Tick(1)
	end
	world.combat = false
	local wet = Slash("debug"):match("wetness (%d%.%d%d)")
	Tick(300)
	return wet
end
local wetWithout = WetnessAfterFight(false)
check("fireballs dry clothes no faster", wetWithout ~= nil and WetnessAfterFight(true) == wetWithout, wetWithout)
-- Only a body that feels fire spells reads again at a hit in a fight.
local realRead, reads = ns.Sensors.Read, 0
ns.Sensors.Read = function()
	reads = reads + 1
	return realRead()
end
world.combat = true
FireHit()
check("a fireball reads again for the undead", reads == 1, reads)
RaceTarget("Human")
reads = 0
FireHit()
check("a fireball waits for the tick for a human", reads == 0, reads)
world.combat = false
ns.Sensors.Read = realRead
Tick(20)
world.race, world.raceName = "Human", "Human"
Tick(1)
-- Retail reads the race too.
ns = LoadAddon(false)
world.mapID, world.zoneText, world.hour = 27, "Dun Morogh", 5
check("retail dwarf", math.abs(RaceTarget("Dwarf") - (-51)) < 0.01, ns.Gauge.target)
world.race, world.raceName = "Human", "Human"

-- A client without C_EventUtils still gets the drunk lines and the forms, but not the weather.
ns = LoadAddon(true)
_G.C_EventUtils = nil
createdFrames = {}
loadedCallback()
local registered = {}
for _, frame in ipairs(createdFrames) do
	for event in pairs(frame.events or {}) do
		registered[event] = true
	end
end
check("standard events without C_EventUtils", registered.CHAT_MSG_SYSTEM and registered.UPDATE_SHAPESHIFT_FORM
	and not registered.WEATHER_CHANGED)

-- A drink warms you, in Dun Morogh before dawn in snow (-88).
ns = LoadAddon(true)
Tick(1)
local function Say(text)
	CoreEvent("CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, 1)
	return ns.Gauge.target
end
local function Near(value, expected)
	return math.abs(value - expected) < 0.01
end
local drinkEventRegistered = false
for _, frame in ipairs(createdFrames) do
	drinkEventRegistered = drinkEventRegistered or frame.events.CHAT_MSG_SYSTEM == true
end
check("system lines registered", drinkEventRegistered)
check("sober at first", Near(ns.Gauge.target, -88) and Slash("debug"):find("drink sober: +0.0", 1, true), ns.Gauge.target)
check("tipsy", Near(Say("You feel tipsy. Whee!"), -78), ns.Gauge.target)
debugText = Slash("debug")
check("debug shows the drink", debugText:find("drink tipsy (0 min): +10.0", 1, true), debugText)
check("drunk", Near(Say("You feel drunk.  Woah!"), -68), ns.Gauge.target)
check("completely smashed", Near(Say("You feel completely smashed."), -58), ns.Gauge.target)
check("sober again", Near(Say("You feel sober again."), -88), ns.Gauge.target)
check("sober clears the save", FeelsLikeDB.drink == nil)
check("tipsy from a drink", Near(Say("You feel a little tipsy from the Rhapsody Malt."), -78), ns.Gauge.target)
check("drunk from a drink", Near(Say("You're feeling drunk off of Thunder Ale."), -68), ns.Gauge.target)
check("smashed from a drink", Near(Say("You feel completely smashed after that Dwarven Mild."), -58), ns.Gauge.target)
check("sober after a drink", Near(Say("You feel sober after the Morning Coffee."), -88), ns.Gauge.target)
check("a drink's link", Near(Say("You feel a little tipsy from the |cffffffff|Hitem:2894::::::::|h[Rhapsody Malt]|h|r."), -78), ns.Gauge.target)
check("a drink's name with pattern characters", Near(Say("You're feeling drunk off of 100% (Proof) Rum."), -68), ns.Gauge.target)
-- Other lines change nothing.
check("another system line", Near(Say("You are now Away: AFK"), -68), ns.Gauge.target)
check("someone else is tipsy", Near(Say("Bob looks tipsy."), -68), ns.Gauge.target)
check("someone else is tipsy from a drink", Near(Say("Bob seems a little tipsy from the Rhapsody Malt."), -68), ns.Gauge.target)
check("half a line", Near(Say("You feel tipsy."), -68), ns.Gauge.target)
check("a line that only looks like one", Near(Say("You feel sober after the Morning Coffee!"), -68), ns.Gauge.target)
check("a line around a drunk line", Near(Say("Bob: You feel sober after the Morning Coffee. Really."), -68), ns.Gauge.target)
check("no text", Near(Say(nil), -68), ns.Gauge.target)
local drinkIsSecret = _G.issecretvalue
_G.issecretvalue = function(value) return value == "You feel sober again." end
check("a secret line keeps the drink", Near(Say("You feel sober again."), -68), ns.Gauge.target)
_G.issecretvalue = drinkIsSecret
-- The heat stays the same.
world.mapID, world.zoneText, world.hour = 1446, "Tanaris", 15
world.weather = { type = 0, intensity = 0 }
Tick(1)
local tanarisDrunk = ns.Gauge.target
Say("You feel sober again.")
check("a drink does not heat the desert", Near(ns.Gauge.target, tanarisDrunk), ns.Gauge.target)
world.mapID, world.zoneText, world.hour = 1426, "Dun Morogh", 5
world.weather = { type = 2, intensity = 1 }
Tick(1)
-- Two hours without a drunk line count as sober.
Say("You feel tipsy. Whee!")
Tick(120)
check("debug counts the minutes", Slash("debug"):find("drink tipsy (2 min): +10.0", 1, true))
Tick(2 * 60 * 60 - 120)
check("tipsy for two hours", Near(ns.Gauge.target, -78), ns.Gauge.target)
Tick(1)
check("sober after two hours", Near(ns.Gauge.target, -88), ns.Gauge.target)
-- A /reload keeps the drink, a login does not.
Say("You feel drunk.  Woah!")
local beforeReload = world.time
ns = LoadAddon(true, FeelsLikeDB)
world.time = beforeReload + 5
Tick(1)
check("sober until the game says it was a reload", Near(ns.Gauge.target, -88), ns.Gauge.target)
CoreEvent("PLAYER_ENTERING_WORLD", false, true)
check("a reload keeps the drink", Near(ns.Gauge.target, -68), ns.Gauge.target)
CoreEvent("PLAYER_ENTERING_WORLD", false, false)
check("a loading screen keeps the drink", Near(ns.Gauge.target, -68), ns.Gauge.target)
beforeReload = world.time
ns = LoadAddon(true, FeelsLikeDB)
world.time = beforeReload + 5
CoreEvent("PLAYER_ENTERING_WORLD", true, false)
check("a login starts sober", Near(ns.Gauge.target, -88) and FeelsLikeDB.drink == nil, ns.Gauge.target)
CoreEvent("PLAYER_ENTERING_WORLD", false, false)
check("a loading screen after the login stays sober", Near(ns.Gauge.target, -88), ns.Gauge.target)
-- A line between the load and the reload's PLAYER_ENTERING_WORLD wins.
Say("You feel completely smashed.")
beforeReload = world.time
ns = LoadAddon(true, FeelsLikeDB)
world.time = beforeReload + 5
Say("You feel sober again.")
CoreEvent("PLAYER_ENTERING_WORLD", false, true)
check("a new line wins over the saved drink", Near(ns.Gauge.target, -88) and FeelsLikeDB.drink == nil, ns.Gauge.target)
-- A client without one of the lines. They are read at the first system line.
ns = LoadAddon(true)
_G.DRUNK_MESSAGE_ITEM_SELF2 = nil
Tick(1)
check("a missing line is skipped", Near(Say("You feel a little tipsy from the Rhapsody Malt."), -88), ns.Gauge.target)
check("the other lines still work", Near(Say("You feel tipsy. Whee!"), -78), ns.Gauge.target)
Say("You feel sober again.")

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
