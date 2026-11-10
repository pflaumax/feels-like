-- A data source for panels like Titan Panel, ChocolateBar or Bazooka (LibDataBroker). The panel addon brings
-- the library, so nothing is bundled here: without a panel addon there is no feed.

local addonName, ns = ...
local T = ns.T

local Broker = {}
ns.Broker = Broker

local LIBRARY = "LibDataBroker-1.1"
local ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icon"
local COLDER_COLOR = { 0.56, 0.85, 0.94 }
local WARMER_COLOR = { 0.96, 0.64, 0.27 }
local HINT_COLOR = { 0.6, 0.6, 0.6 }

local object
-- The last reading, kept so a feed that starts late shows it at once.
local last = { target = 0, cozy = false, colder = {}, warmer = {} }

local function Colored(text, color)
	return string.format("|cff%02x%02x%02x%s|r", color[1] * 255 + 0.5, color[2] * 255 + 0.5, color[3] * 255 + 0.5, text)
end

local function Refresh()
	if not object then
		return
	end
	local band = ns.Model.Band(last.target, last.cozy)
	object.text = Colored(T(band.word), band.color)
end

local function ShowTooltip(tooltip)
	local band = ns.Model.Band(last.target, last.cozy)
	tooltip:AddLine("Feels Like")
	tooltip:AddLine(T(band.word), band.color[1], band.color[2], band.color[3])
	if #last.colder > 0 then
		tooltip:AddLine(ns.Gauge.ReasonLine("Colder", last.colder), COLDER_COLOR[1], COLDER_COLOR[2], COLDER_COLOR[3], true)
	end
	if #last.warmer > 0 then
		tooltip:AddLine(ns.Gauge.ReasonLine("Warmer", last.warmer), WARMER_COLOR[1], WARMER_COLOR[2], WARMER_COLOR[3], true)
	end
	tooltip:AddLine(T("Click to open the settings"), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
end

-- Starts the feed when a panel addon has brought the library. Safe to call again: a panel that loads after
-- this addon brings the library late. Returns true when the feed runs.
function Broker.Register(onClick)
	if object then
		return true
	end
	local library = LibStub and LibStub.GetLibrary and LibStub:GetLibrary(LIBRARY, true)
	if not library then
		return false
	end
	object = library:NewDataObject("Feels Like", {
		type = "data source",
		label = "Feels Like",
		text = "",
		icon = ICON,
		OnClick = onClick,
		OnTooltipShow = ShowTooltip,
	})
	Refresh()
	return object ~= nil
end

-- The real reading and its reasons, after every update.
function Broker.Update(target, cozy, colder, warmer)
	last.target, last.cozy, last.colder, last.warmer = target, cozy, colder, warmer
	Refresh()
end

-- Shows the word again, after the language changed.
function Broker.Refresh()
	Refresh()
end

-- For /feels debug.
function Broker.Describe()
	return object and "on (" .. LIBRARY .. ")" or "off, no panel addon with " .. LIBRARY
end
