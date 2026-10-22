-- Dial drawn from SVG layers (Media/*.svg, made by tools/make_svg.py) with VectorGraphics objects.
-- The client renders SVG at the size it is shown, so the gauge stays sharp at any scale.
-- The game's SVG renderer draws only simple shapes (see tools/make_svg.py), so the ring is a stack of
-- full circles drawn under the face, and the face covers its middle.
-- VectorGraphics cannot rotate, so the needle is 91 pre-rotated SVG files, 3 degrees apart. All 91 are
-- loaded once and switched by alpha: loading a new file into one layer leaves it empty for a moment,
-- which made the needle blink on every step (seen in game, 2026-10-04). Unused layers stay shown at
-- alpha 0 rather than hidden: alpha switching is what was seen to work without a blink.
-- Needs WoW 12.1.0 or Forever 1.60.1; returns nil on older clients, and Gauge falls back to DialLines.

local addonName, ns = ...
local Model = ns.Model

local DialVector = {}
ns.DialVector = DialVector

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local NEEDLE_STEPS = 90 -- Media\Needle\00.svg … 90.svg span Model.MIN … Model.MAX; make_svg.py reads it

-- Applies alpha, or plain show/hide if a VectorGraphics object has no SetAlpha.
local function SetLayerAlpha(layer, alpha)
	if layer.SetAlpha then
		layer:SetAlpha(alpha)
		layer:Show()
	else
		layer:SetShown(alpha >= 0.5)
	end
end

-- Returns a dial: { name, Render(self, t), SetUnit(self, unit), SetClassic(self, classic) }, or nil if SVG is
-- not available.
function DialVector.Create(frame)
	if not frame.CreateVectorGraphics then
		return nil
	end

	-- After the first file that fails to load, the rest are not loaded: the line dial takes over anyway.
	local layers = {}
	local failed = false
	local function Layer(file, drawLayer, subLevel)
		if failed then
			return nil
		end
		local layer = frame:CreateVectorGraphics(nil, drawLayer, nil, subLevel)
		layer:SetAllPoints(frame)
		layers[#layers + 1] = layer
		if not layer:SetSVG(MEDIA .. file) then
			failed = true
			return nil
		end
		return layer
	end
	-- The game sees only the files that were there when it started, so after an update a /reload may miss
	-- art added since 0.1.0 until the game restarts. Such a layer is left out instead of the whole dial.
	local function OptionalLayer(file, drawLayer, subLevel)
		if failed then
			return nil
		end
		local layer = frame:CreateVectorGraphics(nil, drawLayer, nil, subLevel)
		layer:SetAllPoints(frame)
		if not layer:SetSVG(MEDIA .. file) then
			layer:Hide()
			return nil
		end
		layers[#layers + 1] = layer
		return layer
	end

	-- Bottom to top: ring (full circles), face over the ring's middle, scale, unit, needle.
	local face = Layer("face.svg", "BORDER", 0)
	local faceCold = Layer("face_cold.svg", "BORDER", 1)
	local faceHot = Layer("face_hot.svg", "BORDER", 2)
	local scale = Layer("scale.svg", "ARTWORK", 0)
	local unitGlyph = Layer("unit_c.svg", "ARTWORK", 1)
	local needles = {}
	for step = 0, NEEDLE_STEPS do
		needles[step] = Layer(string.format("Needle\\%02d.svg", step), "ARTWORK", 2)
	end
	-- The ring matches the minimap around it: bronze in Forever, gold like the Retail minimap buttons. A
	-- classic-style minimap in Forever has classic buttons: both Forever rings are loaded, SetClassic shows one.
	-- Both are newer than 0.1.0: without them gold stands in and the ring stays the same everywhere.
	local ring = ns.Sensors.isForever and OptionalLayer("ring_bronze.svg", "BACKGROUND", 0)
		or Layer("ring_gold.svg", "BACKGROUND", 0)
	local ringClassic = ns.Sensors.isForever and OptionalLayer("ring_classic.svg", "BACKGROUND", 0) or nil
	local ringIcy = Layer("ring_icy.svg", "BACKGROUND", 1)
	local ringHot = Layer("ring_hot.svg", "BACKGROUND", 2)

	if failed then
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
	if ringClassic then
		SetLayerAlpha(ringClassic, 0)
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

	-- classic: the minimap is classic-style (Forever only; see Gauge).
	function dial:SetClassic(classic)
		if ringClassic then
			SetLayerAlpha(ring, classic and 0 or 1)
			SetLayerAlpha(ringClassic, classic and 1 or 0)
		end
	end

	return dial
end
