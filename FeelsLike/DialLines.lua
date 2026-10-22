-- Fallback dial for clients without SVG support: built-in gold ring, segments and needle drawn as lines.
-- Looks rough below scale 1; DialVector is used whenever the client can draw SVG.

local _, ns = ...
local Model = ns.Model

local DialLines = {}
ns.DialLines = DialLines

-- Unscaled pixels for a 72 px gauge. Interface\COMMON\GoldRing (64x64) has its outer edge at 0.461
-- and its inner edge at 0.34 of the texture size, so a 78 px ring fits a 72 px gauge.
local RING_SIZE = 78
local FACE_SIZE = 54
local SEGMENT_INNER = 17
local SEGMENT_OUTER = 24
local SEGMENT_WIDTH = 6
local NEEDLE_LENGTH = 15
local NEEDLE_WIDTH = 3
local PIVOT_SIZE = 6
local UNIT_OFFSET_Y = -16

local FACE_COLOR = { 0.055, 0.086, 0.125 }
local FACE_COLD = { 0.086, 0.227, 0.333 }
local FACE_HOT = { 0.29, 0.1, 0.055 }
local FACE_ALPHA = 1 -- opaque, like the SVG face: the minimap must not show through the gauge
local RING_COLD = { 0.65, 0.88, 1 }
local RING_HOT = { 1, 0.5, 0.3 }
local NEEDLE_COLOR = { 0.91, 0.96, 1 }

local GOLD_RING = "Interface\\COMMON\\GoldRing"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DEGREE = "\194\176"

local function Lerp(a, b, k)
	return a + (b - a) * k
end

local Polar = Model.Polar

local function CreateCircle(frame, layer, sublevel, size)
	local texture = frame:CreateTexture(nil, layer, nil, sublevel)
	texture:SetSize(size, size)
	texture:SetPoint("CENTER")
	local mask = frame:CreateMaskTexture()
	mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
	return texture
end

-- Returns a dial: { name, Render(self, t), SetUnit(self, unit) }.
function DialLines.Create(frame)
	local face = CreateCircle(frame, "BACKGROUND", 0, FACE_SIZE)

	for i = 1, Model.SEGMENT_COUNT do
		local angle = Model.SWEEP * ((i - 0.5) / Model.SEGMENT_COUNT - 0.5)
		local color = Model.SEGMENT_COLORS[i]
		local segment = frame:CreateLine(nil, "ARTWORK", nil, 0)
		segment:SetThickness(SEGMENT_WIDTH)
		segment:SetColorTexture(color[1], color[2], color[3], 1)
		segment:SetStartPoint("CENTER", frame, Polar(angle, SEGMENT_INNER))
		segment:SetEndPoint("CENTER", frame, Polar(angle, SEGMENT_OUTER))
	end

	local needle = frame:CreateLine(nil, "ARTWORK", nil, 1)
	needle:SetThickness(NEEDLE_WIDTH)
	needle:SetColorTexture(NEEDLE_COLOR[1], NEEDLE_COLOR[2], NEEDLE_COLOR[3], 1)
	needle:SetStartPoint("CENTER", frame, 0, 0)

	local pivot = CreateCircle(frame, "ARTWORK", 2, PIVOT_SIZE)
	pivot:SetColorTexture(NEEDLE_COLOR[1], NEEDLE_COLOR[2], NEEDLE_COLOR[3], 1)

	local ring = frame:CreateTexture(nil, "OVERLAY", nil, 0)
	ring:SetTexture(GOLD_RING)
	ring:SetSize(RING_SIZE, RING_SIZE)
	ring:SetPoint("CENTER")

	local unitText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	unitText:SetPoint("CENTER", 0, UNIT_OFFSET_Y)

	local dial = { name = "lines" }

	function dial:Render(t)
		needle:SetEndPoint("CENTER", frame, Polar(Model.Angle(t), NEEDLE_LENGTH))

		local cold, hot = Model.Extremes(t)
		local tint = cold > 0 and RING_COLD or RING_HOT
		local k = math.max(cold, hot)
		-- Gold multiplied by blue gives olive, so the ring loses its gold before it turns icy.
		ring:SetDesaturation(cold)
		ring:SetVertexColor(Lerp(1, tint[1], k), Lerp(1, tint[2], k), Lerp(1, tint[3], k))

		local faceTint = cold > 0 and FACE_COLD or FACE_HOT
		face:SetColorTexture(
			Lerp(FACE_COLOR[1], faceTint[1], k),
			Lerp(FACE_COLOR[2], faceTint[2], k),
			Lerp(FACE_COLOR[3], faceTint[3], k),
			FACE_ALPHA
		)
	end

	function dial:SetUnit(unit)
		unitText:SetText(DEGREE .. (unit == "F" and "F" or "C"))
	end

	-- The built-in gold ring suits a classic-style minimap as well.
	function dial:SetClassic() end

	return dial
end
