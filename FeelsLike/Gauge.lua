-- The gauge frame with its size, place, dragging, needle movement and label.

local _, ns = ...
local Model = ns.Model
local T = ns.T

local Gauge = {}
ns.Gauge = Gauge

local SIZE = 72 -- unscaled
local LABEL_GAP = 1
-- Near the minimap the label goes on the far side.
local LABEL_NEAR_MINIMAP = 2.5

-- Default place in minimap radii, so it fits any minimap size.
local MINIMAP_ANGLE = ns.Sensors.isForever and 360 - math.deg(math.atan2(55, 86)) or 158
local MINIMAP_DISTANCE = ns.Sensors.isForever and math.sqrt(55 * 55 + 86 * 86) / 99 or 1.66
-- Default place for a classic minimap, under it by the clock.
local CLASSIC_MINIMAP_WIDTH = 170 -- narrower than this counts as classic
local CLASSIC_ANGLE = 180 + math.deg(math.atan2(55, 90))
local CLASSIC_DISTANCE = math.sqrt(55 * 55 + 90 * 90) / 70
-- Fallback place when there is no minimap.
local FALLBACK_X = -110
local FALLBACK_Y = 140

-- The needle rests once it is this near its place and this slow, in units of the scale and units per second.
local NEEDLE_REST = 0.05
local NEEDLE_REST_SPEED = 0.5

local frame, dial, label
local velocity = 0 -- of the needle
-- The ring and the face show this reading. It never swings past the real one like the needle does.
local glow, glowFrom = 0, 0
local db
local hovered = false
local moving = false
-- Where the gauge was when the move started, to tell a move from a click.
local moveStartX, moveStartY
local MOVED = 1 -- pixels that count as a real move
-- The hint about Shift is said once per session.
local hintShown = false

-- The tooltip says why the reading is what it is.
local function NoReasons()
	return {}, {}
end
-- source gives the reasons of the last reading when the tooltip needs them. test is true while a test value shows.
local reasons = { source = NoReasons, test = false }
local COLDER_COLOR = { 0.56, 0.85, 0.94 }
local WARMER_COLOR = { 0.96, 0.64, 0.27 }
local TITLE_COLOR = { 0.9, 0.9, 0.9 }
local HINT_COLOR = { 0.6, 0.6, 0.6 }
Gauge.TITLE_COLOR, Gauge.HINT_COLOR = TITLE_COLOR, HINT_COLOR -- the panel feed uses them too
-- What the open tooltip shows, so it is only built again when that changes and does not flicker.
local tooltipShown

Gauge.target = 0 -- the reading
Gauge.display = 0 -- where the needle is: on its way, or at rest as near the reading as the dial can show
Gauge.cozy = false

-- Offset of a frame from the minimap center in screen pixels.
local function OffsetFromMinimap(target)
	if not Minimap then
		return nil
	end
	local x, y = target:GetCenter()
	local mx, my = Minimap:GetCenter()
	if not (x and mx) then
		return nil
	end
	local scale, minimapScale = target:GetEffectiveScale(), Minimap:GetEffectiveScale()
	return x * scale - mx * minimapScale, y * scale - my * minimapScale, Minimap:GetWidth() / 2 * minimapScale
end

-- True for a classic minimap in Forever.
local function IsClassicMinimap()
	return ns.Sensors.isForever and Minimap ~= nil and Minimap:GetWidth() < CLASSIC_MINIMAP_WIDTH
end

-- The label goes on the side away from the minimap.
local function PlaceLabel()
	label:ClearAllPoints()
	local dx, dy, radius = OffsetFromMinimap(frame)
	local distance = dx and math.sqrt(dx * dx + dy * dy)
	if distance and distance > 0 and distance <= LABEL_NEAR_MINIMAP * radius then
		if math.abs(dx) >= distance / 2 then
			if dx < 0 then
				label:SetPoint("RIGHT", frame, "LEFT", -LABEL_GAP, 0)
			else
				label:SetPoint("LEFT", frame, "RIGHT", LABEL_GAP, 0)
			end
			return
		elseif dy > 0 then
			label:SetPoint("BOTTOM", frame, "TOP", 0, LABEL_GAP)
			return
		end
	end
	label:SetPoint("TOP", frame, "BOTTOM", 0, -LABEL_GAP)
end

local function UpdateLabel()
	local visible = db.label == "always" or (db.label == "hover" and hovered)
	if not visible then
		label:Hide()
		return
	end
	local band = Model.Band(Gauge.target, Gauge.cozy)
	label:SetText(T(band.word))
	label:SetTextColor(band.color[1], band.color[2], band.color[3])
	PlaceLabel() -- the minimap may have moved
	label:Show()
end

-- Text in a color, for a tooltip line or a panel. Also for the panel feed.
function Gauge.Colored(text, color)
	return string.format("|cff%02x%02x%02x%s|r", color[1] * 255 + 0.5, color[2] * 255 + 0.5, color[3] * 255 + 0.5, text)
end

local function Colored(words, color)
	local translated = {}
	for index, word in ipairs(words) do
		translated[index] = T(word)
	end
	return Gauge.Colored(table.concat(translated, ", "), color)
end

-- The one tooltip line that says why, in the chosen language, like "Why: a cold place, snow". What makes it
-- colder is blue and what makes it warmer is orange. With both, the side that wins comes first: warmFirst
-- is true for a reading on the warm half. nil with no reasons. Also for the panel feed.
function Gauge.ReasonLine(colder, warmer, warmFirst)
	local parts = {}
	if #colder > 0 then
		parts[#parts + 1] = Colored(colder, COLDER_COLOR)
	end
	if #warmer > 0 then
		table.insert(parts, warmFirst and 1 or #parts + 1, Colored(warmer, WARMER_COLOR))
	end
	if #parts == 0 then
		return nil
	end
	-- The colon is in the text: French puts a space before it.
	return T("Why:") .. " " .. table.concat(parts, ", ")
end

-- The tooltip opens toward the middle of the screen, away from the edge the gauge sits by.
local function TooltipAnchor()
	local x, y = frame:GetCenter()
	local middleX, middleY = UIParent:GetCenter()
	if not (x and middleX) then
		return "ANCHOR_BOTTOMLEFT"
	end
	local scale = frame:GetScale()
	local right, top = x * scale >= middleX, y * scale >= middleY
	if top then
		return right and "ANCHOR_BOTTOMLEFT" or "ANCHOR_BOTTOMRIGHT"
	end
	return right and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
end

-- Fills the tooltip while the mouse is on the gauge: the word, the reasons and how to move it.
-- fresh is true when the mouse has just come.
local function UpdateTooltip(fresh)
	if not hovered or not db.tooltip then
		return
	end
	local band = Model.Band(Gauge.target, Gauge.cozy)
	local anchor = TooltipAnchor()
	local colder, warmer = reasons.source()
	local shown = table.concat({ band.word, tostring(Gauge.target >= 0), table.concat(colder, ","), table.concat(warmer, ","),
		tostring(reasons.test), tostring(db.locked), ns.Locale.language, anchor }, "|")
	if not fresh and shown == tooltipShown then
		return
	end
	tooltipShown = shown
	GameTooltip:SetOwner(frame, anchor)
	GameTooltip:SetText(T(band.word), band.color[1], band.color[2], band.color[3])
	if reasons.test then
		GameTooltip:AddLine(T("A test value. /feels test off ends it."), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3], true)
	else
		local line = Gauge.ReasonLine(colder, warmer, Gauge.target >= 0)
		if line then
			GameTooltip:AddLine(line, TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], true)
		end
	end
	if not db.locked then
		GameTooltip:AddLine(T("Shift-drag to move"), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
	end
	GameTooltip:Show()
end

-- A locked gauge only needs the mouse for the hover label and the tooltip. With neither it lets clicks through.
local function UpdateMouse()
	local enabled = not db.locked or db.label == "hover" or db.tooltip
	frame:EnableMouse(enabled)
	if not enabled and hovered then
		hovered = false
		GameTooltip:Hide()
	end
end

local function OnUpdate(self, elapsed)
	-- The dial knows where its needle can rest for this reading.
	local aim = dial:Rest(Gauge.target)
	Gauge.display, velocity = Model.NeedleStep(Gauge.display, velocity, aim, elapsed)
	-- The glow follows the needle on its way but stops at the reading: a needle that swings past Hot must not
	-- light the ring like Scorching.
	glow = math.max(math.min(glowFrom, Gauge.target), math.min(Gauge.display, math.max(glowFrom, Gauge.target)))
	if math.abs(aim - Gauge.display) < NEEDLE_REST and math.abs(velocity) < NEEDLE_REST_SPEED then
		Gauge.display, velocity, glow = aim, 0, Gauge.target
		self:SetScript("OnUpdate", nil)
	end
	dial:Render(Gauge.display, glow)
end

local function SavePosition()
	local scale = frame:GetScale()
	local x, y = frame:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	db.x = x * scale - parentX
	db.y = y * scale - parentY
	Gauge:ApplyPosition()
end

function Gauge:Create(savedVariables)
	db = savedVariables

	frame = CreateFrame("Frame", "FeelsLikeGauge", UIParent)
	frame:SetSize(SIZE, SIZE)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	if frame.SetDontSavePosition then
		frame:SetDontSavePosition(true)
	end

	dial = ns.DialVector.Create(frame) or ns.DialLines.Create(frame)
	Gauge.renderer = dial.name

	-- The label has its own frame so it stays readable at small sizes.
	local labelFrame = CreateFrame("Frame", nil, UIParent)
	labelFrame:SetFrameStrata(frame:GetFrameStrata())
	-- A dark outline keeps the word readable on snow, sand and other bright ground. The game's own outlined
	-- font keeps the letters of every alphabet. Without it, the outline goes on the plain font.
	if GameFontHighlightSmallOutline then
		label = labelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
	else
		label = labelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		local font, fontSize = label:GetFont()
		if font then
			label:SetFont(font, fontSize, "OUTLINE")
		end
	end

	-- Shift is needed to move the gauge. The move starts at the press, so it follows the mouse at once:
	-- a drag only starts after the mouse has moved some way.
	frame:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or db.locked or not IsShiftKeyDown() then
			return
		end
		moving = true
		moveStartX, moveStartY = self:GetCenter()
		self:StartMoving()
	end)
	-- Only save a real move. A press without a move keeps the old place.
	frame:SetScript("OnMouseUp", function(self)
		if not moving then
			return
		end
		moving = false
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		if x and moveStartX and (math.abs(x - moveStartX) >= MOVED or math.abs(y - moveStartY) >= MOVED) then
			SavePosition()
		else
			Gauge:ApplyPosition()
		end
	end)
	-- A drag without Shift moves nothing, so say why, once.
	frame:SetScript("OnDragStart", function()
		if moving or hintShown then
			return
		end
		hintShown = true
		ns.Print(T(db.locked and "the gauge is locked. Unlock it in the settings: /feels"
			or "hold Shift and drag to move the gauge."))
	end)
	frame:SetScript("OnEnter", function()
		hovered = true
		UpdateLabel()
		UpdateTooltip(true)
	end)
	frame:SetScript("OnLeave", function()
		hovered = false
		UpdateLabel()
		GameTooltip:Hide()
	end)

	-- The minimap can change size or place after login.
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	if C_EventUtils and C_EventUtils.IsEventValid("EDIT_MODE_LAYOUTS_UPDATED") then
		frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	end
	frame:SetScript("OnEvent", function()
		Gauge:ApplyPosition()
	end)
	if Minimap then
		Minimap:HookScript("OnSizeChanged", function()
			Gauge:ApplyPosition()
		end)
	end

	self:SetUnit(db.unit)
	self:SetScale(db.scale)
	self:SetLabelMode(db.label)
	self:SetLocked(db.locked)
	dial:Render(self.display)
end

function Gauge:SetTarget(t)
	t = Model.Clamp(t)
	if t == self.target then
		return
	end
	self.target = t
	glowFrom = glow -- the glow moves on from where it is
	frame:SetScript("OnUpdate", OnUpdate)
	UpdateLabel()
end

function Gauge:SetCozy(cozy)
	if cozy == self.cozy then
		return
	end
	self.cozy = cozy
	UpdateLabel()
end

-- Shows the word and the tooltip again, after the language changed.
function Gauge:Refresh()
	UpdateLabel()
	UpdateTooltip()
end

-- source is a function that returns the colder and the warmer words of Model.Reasons. It is called only
-- while the tooltip is open. test is true while a test value shows.
function Gauge:SetReasons(source, test)
	reasons.source, reasons.test = source or NoReasons, test or false
	UpdateTooltip()
end

function Gauge:SetUnit(unit)
	dial:SetUnit(unit)
end

-- The tooltip on hover can be turned off. The word next to the gauge has its own setting.
function Gauge:SetTooltip(on)
	db.tooltip = on
	UpdateMouse()
	if not hovered then
		return
	elseif on then
		UpdateTooltip(true)
	else
		GameTooltip:Hide()
	end
end

-- mode is hover, always or never.
function Gauge:SetLabelMode(mode)
	db.label = mode
	UpdateLabel()
	UpdateMouse()
end

function Gauge:SetLocked(locked)
	db.locked = locked
	UpdateMouse()
end

function Gauge:SetScale(scale)
	frame:SetScale(scale)
	self:ApplyPosition()
end

-- Offsets are in the frame's own scale.
function Gauge:ApplyPosition()
	local classic = IsClassicMinimap()
	dial:SetClassic(classic) -- the ring follows the minimap buttons
	local scale = frame:GetScale()
	frame:ClearAllPoints()
	if db.x and db.y then
		frame:SetPoint("CENTER", UIParent, "CENTER", db.x / scale, db.y / scale)
	elseif Minimap then
		local toScreen = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local radius = Minimap:GetWidth() / 2 * (classic and CLASSIC_DISTANCE or MINIMAP_DISTANCE) * toScreen
		local x, y = Model.Polar(classic and CLASSIC_ANGLE or MINIMAP_ANGLE, radius)
		frame:SetPoint("CENTER", Minimap, "CENTER", x / scale, y / scale)
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", FALLBACK_X / scale, FALLBACK_Y / scale)
	end
	PlaceLabel()
end

-- Where a frame sits by the minimap, for /feels measure.
function Gauge:Describe(target)
	local dx, dy, radius = OffsetFromMinimap(target)
	if not dx then
		return "not placed by a minimap"
	end
	local angle = math.deg(math.atan2(dx, dy)) % 360
	local distance = math.sqrt(dx * dx + dy * dy)
	local matchingScale = target:GetWidth() * target:GetEffectiveScale() / (SIZE * UIParent:GetEffectiveScale())
	return string.format("%.0f degrees from 12 o'clock, %.2f of the minimap radius from its center, as wide as the gauge at scale %.2f",
		angle, radius > 0 and distance / radius or 0, matchingScale)
end

-- Where the gauge is, for /feels debug.
function Gauge:DescribePosition()
	local layout = IsClassicMinimap() and ", classic-style minimap" or ""
	return (db.x and "moved" or "default") .. layout .. "; " .. self:Describe(frame)
end

function Gauge:ResetPosition()
	db.x = nil
	db.y = nil
	self:ApplyPosition()
end
