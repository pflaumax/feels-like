-- Dial drawn from SVG layers, sharp at any size. The needle has 91 rotated files switched by alpha, so it does not blink.

local addonName, ns = ...
local Model = ns.Model

local DialVector = {}
ns.DialVector = DialVector

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local NEEDLE_STEPS = 90

-- Sets alpha, or shows and hides if SetAlpha is missing.
local function SetLayerAlpha(layer, alpha)
	if layer.SetAlpha then
		layer:SetAlpha(alpha)
		layer:Show()
	else
		layer:SetShown(alpha >= 0.5)
	end
end

-- Returns a dial, or nil if SVG is not available.
function DialVector.Create(frame)
	if not frame.CreateVectorGraphics then
		return nil
	end

	-- If one file fails to load, stop and use the line dial.
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
	-- Art added in an update may be missing until the game restarts, so skip that layer.
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

	-- Layers from bottom to top are ring, face, scale, unit and needle.
	Layer("face.svg", "BORDER", 0)
	local faceCold = Layer("face_cold.svg", "BORDER", 1)
	local faceHot = Layer("face_hot.svg", "BORDER", 2)
	Layer("scale.svg", "ARTWORK", 0)
	local unitGlyph = Layer("unit_c.svg", "ARTWORK", 1)
	local needles = {}
	for step = 0, NEEDLE_STEPS do
		needles[step] = Layer(string.format("Needle\\%02d.svg", step), "ARTWORK", 2)
	end
	-- Bronze ring in Forever, gold on Retail, classic ring for a classic minimap.
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

	-- Cold and hot layers start hidden.
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
			-- Show the new needle before hiding the old one.
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

	-- classic is true for a classic minimap.
	function dial:SetClassic(classic)
		if ringClassic then
			SetLayerAlpha(ring, classic and 0 or 1)
			SetLayerAlpha(ringClassic, classic and 1 or 0)
		end
	end

	return dial
end
