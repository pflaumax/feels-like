-- A data source for panels like Titan Panel, ChocolateBar or Bazooka (LibDataBroker). The panel addon brings
-- the library, so nothing is bundled here: without a panel addon there is no feed.

local addonName, ns = ...
local T = ns.T

local Broker = {}
ns.Broker = Broker

local LIBRARY = "LibDataBroker-1.1"
local ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icon"

local object
-- The last reading, kept so a feed that starts late shows it at once.
local function NoReasons()
	return {}, {}
end
local last = { target = 0, cozy = false, reasons = NoReasons }

local function Refresh()
	if not object then
		return
	end
	local band = ns.Model.Band(last.target, last.cozy)
	object.text = ns.Gauge.Colored(T(band.word), band.color)
end

local function ShowTooltip(tooltip)
	local band = ns.Model.Band(last.target, last.cozy)
	local TITLE_COLOR, HINT_COLOR = ns.Gauge.TITLE_COLOR, ns.Gauge.HINT_COLOR
	tooltip:AddLine("Feels Like")
	tooltip:AddLine(T(band.word), band.color[1], band.color[2], band.color[3])
	local colder, warmer = last.reasons()
	local line = ns.Gauge.ReasonLine(colder, warmer, last.target >= 0)
	if line then
		tooltip:AddLine(line, TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], true)
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

-- The real reading, after every update. reasons is a function that returns its colder and warmer words; it
-- is called only when the panel shows the tooltip.
function Broker.Update(target, cozy, reasons)
	last.target, last.cozy, last.reasons = target, cozy, reasons
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
