-- The gauge frame: size, place, dragging, the needle's smooth movement and the word next to it.
-- Drawing is done by a dial: DialVector (SVG, sharp at any scale) or, on older clients, DialLines.

local _, ns = ...
local Model = ns.Model

local Gauge = {}
ns.Gauge = Gauge

local SIZE = 72 -- unscaled; the default scale is 0.45
local LABEL_GAP = 1
-- Within this many minimap radii the word goes on the side away from the minimap (see PlaceLabel).
local LABEL_NEAR_MINIMAP = 2.5

-- Default place, in minimap radii so it stays in place whatever size the minimap has.
-- Forever: on the minimap ring, mirroring the day/night button (from Forever screenshots, 2026-10-21;
-- to be confirmed in game with /feels measure). Retail with the classic-style UI: just below the
-- minimap, by the clock (picked in game, 2026-10-04, /feels debug).
local MINIMAP_ANGLE = ns.Sensors.isForever and 327 or 158
local MINIMAP_DISTANCE = ns.Sensors.isForever and 1.03 or 1.66
-- Fallback when there is no minimap: bottom right, above the bag bar. Screen (UIParent) units.
local FALLBACK_X = -110
local FALLBACK_Y = 140

-- Share of the remaining distance the needle covers per second.
local FOLLOW_SPEED = 4

local frame, dial, label
local db
local hovered = false
local moving = false

Gauge.target = 0
Gauge.display = 0
Gauge.cozy = false

-- Where a frame's center is from the minimap's center, in screen pixels (each frame's coordinates are in
-- its own scale). Returns dx, dy and the minimap radius, or nil while either is not placed.
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

-- The word goes on the side of the gauge away from the minimap, so it never covers the map: left or
-- right of a gauge beside the minimap, above or below one over or under it. Far from the minimap, below.
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
	label:SetText(band.word)
	label:SetTextColor(band.color[1], band.color[2], band.color[3])
	PlaceLabel() -- the minimap may have moved since the gauge was placed
	label:Show()
end

-- A locked gauge needs the mouse only to show the word on hover; otherwise clicks reach the minimap
-- below it. Without the mouse no OnLeave arrives, so drop the hover state here.
local function UpdateMouse()
	local enabled = not db.locked or db.label == "hover"
	frame:EnableMouse(enabled)
	if not enabled then
		hovered = false
	end
end

local function OnUpdate(self, elapsed)
	local diff = Gauge.target - Gauge.display
	if math.abs(diff) < 0.05 then
		Gauge.display = Gauge.target
		self:SetScript("OnUpdate", nil)
	else
		Gauge.display = Gauge.display + diff * math.min(1, elapsed * FOLLOW_SPEED)
	end
	dial:Render(Gauge.display)
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

	-- The word lives in its own unscaled frame, so it stays readable when the gauge is small.
	local labelFrame = CreateFrame("Frame", nil, UIParent)
	labelFrame:SetFrameStrata(frame:GetFrameStrata())
	label = labelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

	-- Shift is required, so a click on the gauge never moves it by accident.
	frame:SetScript("OnDragStart", function(self)
		if not db.locked and IsShiftKeyDown() then
			moving = true
			self:StartMoving()
		end
	end)
	-- Only a real move is saved: a plain drag must not detach the gauge from the minimap.
	frame:SetScript("OnDragStop", function(self)
		if not moving then
			return
		end
		moving = false
		self:StopMovingOrSizing()
		SavePosition()
	end)
	frame:SetScript("OnEnter", function()
		hovered = true
		UpdateLabel()
	end)
	frame:SetScript("OnLeave", function()
		hovered = false
		UpdateLabel()
	end)

	-- The minimap can change size or place after login (Edit Mode).
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

function Gauge:SetUnit(unit)
	dial:SetUnit(unit)
end

-- mode: "hover", "always" or "never".
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

-- Point offsets are in the frame's own scale, so divide screen offsets by it.
function Gauge:ApplyPosition()
	local scale = frame:GetScale()
	frame:ClearAllPoints()
	if db.x and db.y then
		frame:SetPoint("CENTER", UIParent, "CENTER", db.x / scale, db.y / scale)
	elseif Minimap then
		local toScreen = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local radius = Minimap:GetWidth() / 2 * MINIMAP_DISTANCE * toScreen
		local x, y = Model.Polar(MINIMAP_ANGLE, radius)
		frame:SetPoint("CENTER", Minimap, "CENTER", x / scale, y / scale)
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", FALLBACK_X / scale, FALLBACK_Y / scale)
	end
	PlaceLabel()
end

-- Where a frame sits by the minimap, and the gauge scale that would make the gauge as wide: to pick a
-- default place and size next to a minimap button (/feels measure <frame name>, /feels debug).
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

-- For /feels debug: where the gauge is, relative to the minimap, so a good spot can become the default.
function Gauge:DescribePosition()
	return (db.x and "moved" or "default") .. "; " .. self:Describe(frame)
end

function Gauge:ResetPosition()
	db.x = nil
	db.y = nil
	self:ApplyPosition()
end
