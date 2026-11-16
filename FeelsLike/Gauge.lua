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
-- The gauge has its own tooltip. Addon code that shows or hides the game's GameTooltip runs the game's tooltip
-- code tainted, breaks the tooltips of the world and of other addons and gets the blame for their errors.
local tooltip
local velocity = 0 -- of the needle
-- The ring and the face show this reading. It never swings past the real one like the needle does.
local glow, glowFrom = 0, 0
local db
local hovered = false
local hoveredFrame -- the gauge or the word, whichever the mouse is on
local moving = false
local movingWord = false -- the player holds the word, not the gauge
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
Gauge.needle = 0 -- where the needle is: on its way, or at rest as near the reading as the dial can show
Gauge.cozy = false

-- What shows on screen. gauge: the dial is drawn. word: the status word shows on hover, always or never next to
-- the gauge, or alone in its place.
-- name is the English text of the choice in the settings.
Gauge.DISPLAY = {
	gaugeHover = { gauge = true, word = "hover", name = "Gauge, status on hover" },
	gaugeStatus = { gauge = true, word = "always", name = "Gauge and status" },
	gauge = { gauge = true, word = "never", name = "Gauge only" },
	status = { gauge = false, word = "alone", name = "Status only" },
	none = { gauge = false, word = "never", name = "Nothing" },
}
Gauge.DISPLAY_ORDER = { "gaugeHover", "gaugeStatus", "gauge", "status", "none" }
-- The word alone never gets smaller than this, so it stays readable.
local MIN_WORD_SCALE = 0.75

-- The frame that holds the word, and the frame that takes the mouse for the word alone.
local labelFrame, status

local function Mode()
	return Gauge.DISPLAY[db.display] or Gauge.DISPLAY.gaugeHover
end

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

-- The label goes on the side away from the minimap. The word alone far from the minimap takes the gauge's place.
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
	elseif Mode().word == "alone" then
		label:SetPoint("CENTER", frame, "CENTER", 0, 0)
		return
	end
	label:SetPoint("TOP", frame, "BOTTOM", 0, -LABEL_GAP)
end

local function UpdateLabel()
	local word = Mode().word
	local visible = word == "always" or word == "alone" or (word == "hover" and hovered)
	if not visible then
		label:Hide()
		return
	end
	local band = Model.Band(Gauge.target, Gauge.cozy)
	label:SetText(T(band.word))
	label:SetTextColor(band.color[1], band.color[2], band.color[3])
	-- The minimap may have moved. During a move the word keeps its side, so it stays under the mouse.
	if not moving then
		PlaceLabel()
	end
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
	tooltip:SetOwner(hoveredFrame or frame, anchor)
	tooltip:SetText(T(band.word), band.color[1], band.color[2], band.color[3])
	if reasons.test then
		tooltip:AddLine(T("A test value. /feels test off ends it."), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3], true)
	else
		local line = Gauge.ReasonLine(colder, warmer, Gauge.target >= 0)
		if line then
			tooltip:AddLine(line, TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], true)
		end
	end
	if not db.locked then
		tooltip:AddLine(T("Shift-drag to move"), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
	end
	tooltip:Show()
end

-- A locked gauge only needs the mouse for the hover label and the tooltip. With neither it lets clicks through.
-- A word that always shows takes the mouse like the gauge, and a gauge that is not drawn never takes it.
local function UpdateMouse()
	local mode = Mode()
	local onGauge = mode.gauge and (not db.locked or mode.word == "hover" or db.tooltip)
	local onWord = (mode.word == "alone" or mode.word == "always") and (not db.locked or db.tooltip)
	frame:EnableMouse(onGauge)
	status:EnableMouse(onWord)
	if not (onGauge or onWord) and hovered then
		hovered, hoveredFrame = false, nil
		tooltip:Hide()
	end
end

-- The gauge is shown at all but in Nothing. Without the dial it is an empty frame that only gives the word its
-- place and moves it: a shown frame always has a place. It then keeps the default size, so the word sits where
-- it shows next to the gauge today, and Scale sizes the word.
local function ApplyLook()
	local mode = Mode()
	local defaultScale = ns.DEFAULTS.scale
	frame:SetShown(mode.gauge or mode.word == "alone")
	frame:SetAlpha(mode.gauge and 1 or 0)
	if not mode.gauge then
		frame:SetScript("OnUpdate", nil) -- no needle to move
	end
	if mode.word == "alone" then
		frame:SetScale(defaultScale)
		labelFrame:SetScale(math.max(MIN_WORD_SCALE, db.scale / defaultScale))
	else
		frame:SetScale(db.scale)
		labelFrame:SetScale(1)
	end
end

local function OnUpdate(self, elapsed)
	-- The dial knows where its needle can rest for this reading.
	local aim = dial:Rest(Gauge.target)
	Gauge.needle, velocity = Model.NeedleStep(Gauge.needle, velocity, aim, elapsed)
	-- The glow follows the needle on its way but stops at the reading: a needle that swings past Hot must not
	-- light the ring like Scorching.
	glow = math.max(math.min(glowFrom, Gauge.target), math.min(Gauge.needle, math.max(glowFrom, Gauge.target)))
	if math.abs(aim - Gauge.needle) < NEEDLE_REST and math.abs(velocity) < NEEDLE_REST_SPEED then
		Gauge.needle, velocity, glow = aim, 0, Gauge.target
		self:SetScript("OnUpdate", nil)
	end
	dial:Render(Gauge.needle, glow)
end

local function SavePosition()
	local scale = frame:GetScale()
	local x, y = frame:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	db.x = x * scale - parentX
	db.y = y * scale - parentY
	Gauge:ApplyPosition()
end

-- Where the word is, in the units of the screen's UI.
local function WordCenter()
	local x, y = label:GetCenter()
	if not x then
		return nil
	end
	local scale = label:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale, y * scale
end

-- After a move the word picks its side of the place again. The player moved the word itself, so it goes back to
-- where it was let go, on the side it has now: a second choice could put it somewhere else again.
local function KeepWordAt(x, y)
	local newX, newY = WordCenter()
	if not (x and newX) then
		return
	end
	db.x, db.y = db.x + x - newX, db.y + y - newY
	Gauge:ApplyPosition(true)
end

-- Shift is needed to move. The move starts at the press, so it follows the mouse at once: a drag only starts
-- after the mouse has moved some way. The gauge frame moves, also when the player holds the word, and the word
-- with it.
local function OnPress(self, button)
	if button ~= "LeftButton" or db.locked or not IsShiftKeyDown() then
		return
	end
	moving, movingWord = true, self == status
	moveStartX, moveStartY = frame:GetCenter()
	frame:StartMoving()
end

-- Only save a real move. A press without a move keeps the old place.
local function OnRelease()
	if not moving then
		return
	end
	moving = false
	frame:StopMovingOrSizing()
	local x, y = frame:GetCenter()
	if x and moveStartX and (math.abs(x - moveStartX) >= MOVED or math.abs(y - moveStartY) >= MOVED) then
		local wordX, wordY = WordCenter()
		SavePosition()
		if movingWord then
			KeepWordAt(wordX, wordY)
		end
	else
		Gauge:ApplyPosition()
	end
end

local function OnEnter(self)
	hovered, hoveredFrame = true, self
	UpdateLabel()
	UpdateTooltip(true)
end

local function OnLeave()
	hovered, hoveredFrame = false, nil
	UpdateLabel()
	tooltip:Hide()
end

-- The needle stands still while the dial is not drawn. Back on screen it shows the reading at once, with no swing
-- across the dial.
local function SnapNeedle()
	Gauge.needle, velocity = dial:Rest(Gauge.target), 0
	glow, glowFrom = Gauge.target, Gauge.target
	frame:SetScript("OnUpdate", nil)
	dial:Render(Gauge.needle, glow)
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

	-- The plain tooltip template looks like the game's tooltip. GameTooltipTemplate would also hide the game's
	-- pet tooltip each time ours hides.
	tooltip = CreateFrame("GameTooltip", "FeelsLikeTooltip", UIParent, "SharedTooltipTemplate")

	-- The label has its own frame so it stays readable at small sizes.
	labelFrame = CreateFrame("Frame", nil, UIParent)
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

	-- The word alone takes the mouse in a frame of its own, the size of the word.
	status = CreateFrame("Frame", "FeelsLikeStatus", UIParent)
	status:SetFrameStrata(frame:GetFrameStrata())
	status:SetAllPoints(label)
	for _, target in ipairs({ frame, status }) do
		target:SetScript("OnMouseDown", OnPress)
		target:SetScript("OnMouseUp", OnRelease)
		target:SetScript("OnEnter", OnEnter)
		target:SetScript("OnLeave", OnLeave)
	end
	-- A drag of the gauge without Shift moves nothing, so say why, once.
	frame:SetScript("OnDragStart", function()
		if moving or hintShown then
			return
		end
		hintShown = true
		ns.Print(T(db.locked and "the gauge is locked. Unlock it in the settings: /feels"
			or "hold Shift and drag to move the gauge."))
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
	self:SetLocked(db.locked)
	self:SetDisplay(db.display)
	dial:Render(self.needle)
end

function Gauge:SetTarget(t)
	t = Model.Clamp(t)
	if t == self.target then
		return
	end
	self.target = t
	glowFrom = glow -- the glow moves on from where it is
	if Mode().gauge then
		frame:SetScript("OnUpdate", OnUpdate)
	end
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

-- The tooltip on hover can be turned off. The word has its own place in On screen.
function Gauge:SetTooltip(on)
	db.tooltip = on
	UpdateMouse()
	if not hovered then
		return
	elseif on then
		UpdateTooltip(true)
	else
		tooltip:Hide()
	end
end

-- What shows on screen, a key of Gauge.DISPLAY. The readings, the lines in chat and the panel feed go on in all.
function Gauge:SetDisplay(key)
	local wasDrawn = frame:IsShown() and Mode().gauge
	db.display = key
	-- The game may not say the mouse left a frame that hides or stops taking the mouse, and the tooltip is
	-- filled again each update.
	hovered, hoveredFrame = false, nil
	tooltip:Hide()
	ApplyLook()
	self:ApplyPosition() -- after the scale of the frame, which the offsets depend on
	if Mode().gauge and not wasDrawn then
		SnapNeedle()
	end
	UpdateMouse()
	UpdateLabel()
end

function Gauge:SetLocked(locked)
	db.locked = locked
	UpdateMouse()
end

-- The size of the gauge, or of the word alone.
function Gauge:SetScale(scale)
	db.scale = scale
	ApplyLook()
	self:ApplyPosition()
end

-- Offsets are in the frame's own scale. keepSide leaves the word on the side of the place it has now.
function Gauge:ApplyPosition(keepSide)
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
	if not keepSide then
		PlaceLabel()
	end
end

-- Where a frame sits by the minimap, for /feels measure.
function Gauge:Describe(target)
	-- The game can hide where a frame is. A hidden value is an error in a sum.
	local IsSecret = ns.Sensors.IsSecret
	local x, y = target:GetCenter()
	if IsSecret(x) or IsSecret(y) or IsSecret(target:GetWidth()) or IsSecret(target:GetEffectiveScale()) then
		return "place hidden by the game"
	end
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
	-- The game may not place a frame that was never shown.
	local off = Mode() == Gauge.DISPLAY.none and ", off in settings" or ""
	return (db.x and "moved" or "default") .. layout .. off .. "; " .. self:Describe(frame)
end

local function FrameName(target)
	if ns.Sensors.IsForbidden(target) then
		return "a frame closed to addons"
	end
	return target and (target:GetName() or "a frame with no name") or "the screen"
end

-- What the game says about a frame or a text: seen or not, where it is and what it hangs on.
local function DescribeRegion(region)
	local parts = {}
	if not region:IsShown() then
		parts[1] = "hidden"
	elseif not region:IsVisible() then
		parts[1] = "shown, but its parent is hidden"
	else
		parts[1] = "shown"
	end
	local x, y = region:GetCenter()
	if not x then
		parts[#parts + 1] = "no place on the screen"
	elseif issecretvalue and issecretvalue(x) then
		parts[#parts + 1] = "place hidden by the game"
	else
		local scale = region:GetEffectiveScale()
		parts[#parts + 1] = string.format("at %.0f, %.0f", x * scale, y * scale)
	end
	local count = region:GetNumPoints()
	if count == 0 then
		parts[#parts + 1] = "no anchor"
	else
		local point, relativeTo, relativePoint, offsetX, offsetY = region:GetPoint(1)
		parts[#parts + 1] = string.format("%s on %s of %s, %.0f, %.0f%s", point, relativePoint, FrameName(relativeTo),
			offsetX, offsetY, count > 1 and ", and " .. (count - 1) .. " more" or "")
	end
	return table.concat(parts, ", ")
end

-- The state of the gauge frame, the label and the minimap, for /feels debug. Another addon can hide or move
-- a frame, and these lines show it. The place is in screen pixels from the bottom left.
function Gauge:DescribeFrames()
	local parent = frame:GetParent()
	local held = (moving and ", moving with the mouse" or "") .. (frame:IsDragging() and ", dragged" or "")
	local lines = {
		"on screen: " .. tostring(db.display),
		string.format("frame: %s, alpha %.2f, scale %.2f, parent %s, %s level %d, mouse %s%s", DescribeRegion(frame),
			frame:GetEffectiveAlpha(), frame:GetScale(), parent and FrameName(parent) or "none",
			frame:GetFrameStrata(), frame:GetFrameLevel(), frame:IsMouseEnabled() and "on" or "off", held),
		string.format("label: %s, alpha %.2f, scale %.2f, mouse %s", DescribeRegion(label), label:GetAlpha(),
			labelFrame:GetScale(), status:IsMouseEnabled() and "on" or "off"),
	}
	if Minimap then
		lines[#lines + 1] = string.format("minimap: %s, %.0f wide, scale %.2f", DescribeRegion(Minimap),
			Minimap:GetWidth(), Minimap:GetEffectiveScale())
	end
	return lines
end

function Gauge:ResetPosition()
	db.x = nil
	db.y = nil
	self:ApplyPosition()
end
