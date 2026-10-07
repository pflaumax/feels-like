-- Dial drawn from SVG layers (Media/*.svg, made by tools/make_svg.py) with VectorGraphics objects.
-- The client renders SVG at the size it is shown, so the gauge stays sharp at any scale.
-- The game's SVG renderer draws only simple shapes (see tools/make_svg.py), so the ring is a stack of
-- full circles drawn under the face, and the face covers its middle.
-- VectorGraphics cannot rotate, so the needle is 91 pre-rotated SVG files, 3 degrees apart. All 91 are
-- loaded once and switched by alpha: loading a new file into one layer leaves it empty for a moment,
-- which made the needle blink on every step (seen in game, 2026-10-04).
-- Needs WoW 12.1.0 or Forever 1.60.1; returns nil on older clients, and Gauge falls back to DialLines.

local addonName, ns = ...
local Model = ns.Model

local DialVector = {}
ns.DialVector = DialVector

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local NEEDLE_STEPS = 90 -- Media\Needle\00.svg … 90.svg span Model.MIN … Model.MAX

-- Applies alpha, or plain show/hide if a VectorGraphics object has no SetAlpha.
local function SetLayerAlpha(layer, alpha)
	if layer.SetAlpha then
		layer:SetAlpha(alpha)
		layer:Show()
	else
		layer:SetShown(alpha >= 0.5)
	end
end

-- Returns a dial: { name, Render(self, t), SetUnit(self, unit) }, or nil if SVG is not available.
function DialVector.Create(frame)
	if not frame.CreateVectorGraphics then
		return nil
	end

	local layers = {}
	local function Layer(file, drawLayer, subLevel)
		local layer = frame:CreateVectorGraphics(nil, drawLayer, nil, subLevel)
		layer:SetAllPoints(frame)
		layers[#layers + 1] = layer
		if not layer:SetSVG(MEDIA .. file) then
			return nil
		end
		return layer
	end

	-- Bottom to top: ring (full circles), face over the ring's middle, scale, unit, needle.
	local face = Layer("face.svg", "BORDER", 0)
	local faceCold = Layer("face_cold.svg", "BORDER", 1)
	local faceHot = Layer("face_hot.svg", "BORDER", 2)
	local scale = Layer("scale.svg", "ARTWORK", 0)
	local unitGlyph = Layer("unit_c.svg", "ARTWORK", 1)
	local needles = {}
	local needlesLoaded = true
	for step = 0, NEEDLE_STEPS do
		needles[step] = Layer(string.format("Needle\\%02d.svg", step), "ARTWORK", 2)
		needlesLoaded = needlesLoaded and needles[step] ~= nil
	end
	local ringGold = Layer("ring_gold.svg", "BACKGROUND", 0)
	local ringIcy = Layer("ring_icy.svg", "BACKGROUND", 1)
	local ringHot = Layer("ring_hot.svg", "BACKGROUND", 2)

	if not (face and faceCold and faceHot and scale and unitGlyph and needlesLoaded
		and ringGold and ringIcy and ringHot) then
		for _, layer in ipairs(layers) do
			layer:Hide()
		end
		return nil
	end

	local needleStep = math.floor(NEEDLE_STEPS / 2 + 0.5)
	for step = 0, NEEDLE_STEPS do
		SetLayerAlpha(needles[step], step == needleStep and 1 or 0)
	end
	local dial = { name = "vector" }

	-- The cold and hot layers start hidden; Render changes them only when their value changes.
	local shownCold, shownHot = 0, 0
	for _, layer in ipairs({ faceCold, ringIcy, faceHot, ringHot }) do
		SetLayerAlpha(layer, 0)
	end

	function dial:Render(t)
		local step = math.floor(Model.Fraction(t) * NEEDLE_STEPS + 0.5)
		if step ~= needleStep then
			-- Show the new one before hiding the old, so no frame is left without a needle.
			SetLayerAlpha(needles[step], 1)
			SetLayerAlpha(needles[needleStep], 0)
			needleStep = step
		end

		local cold, hot = Model.Extremes(t)
		if cold ~= shownCold then
			SetLayerAlpha(faceCold, cold)
			SetLayerAlpha(ringIcy, cold)
			shownCold = cold
		end
		if hot ~= shownHot then
			SetLayerAlpha(faceHot, hot)
			SetLayerAlpha(ringHot, hot)
			shownHot = hot
		end
	end

	function dial:SetUnit(unit)
		unitGlyph:SetSVG(MEDIA .. (unit == "F" and "unit_f.svg" or "unit_c.svg"))
	end

	return dial
end
