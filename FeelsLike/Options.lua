-- Options → AddOns → Feels Like. Built on the vertical-list Settings API (11.0+).

local _, ns = ...

local Options = {}
ns.Options = Options

local SCALE_MIN = 0.3
local SCALE_MAX = 2
local SCALE_STEP = 0.05

local function UnitOptions()
	local container = Settings.CreateControlTextContainer()
	container:Add("C", "Celsius")
	container:Add("F", "Fahrenheit")
	return container:GetData()
end

local function LabelOptions()
	local container = Settings.CreateControlTextContainer()
	container:Add("hover", "On hover")
	container:Add("always", "Always")
	container:Add("never", "Never")
	return container:GetData()
end

local function FormatScale(value)
	return string.format("%.2f", value)
end

function Options:Register(db)
	local defaults = ns.DEFAULTS
	local category, layout = Settings.RegisterVerticalLayoutCategory("Feels Like")

	local unit = Settings.RegisterAddOnSetting(category, "FEELSLIKE_UNIT", "unit", db,
		Settings.VarType.String, "Units", defaults.unit)
	unit:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetUnit(value)
	end)
	Settings.CreateDropdown(category, unit, UnitOptions, "Unit symbol inside the gauge.")

	local label = Settings.RegisterAddOnSetting(category, "FEELSLIKE_LABEL", "label", db,
		Settings.VarType.String, "Show word", defaults.label)
	label:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetLabelMode(value)
	end)
	Settings.CreateDropdown(category, label, LabelOptions,
		"One word under the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy.")

	local locked = Settings.RegisterAddOnSetting(category, "FEELSLIKE_LOCKED", "locked", db,
		Settings.VarType.Boolean, "Lock position", defaults.locked)
	locked:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetLocked(value)
	end)
	Settings.CreateCheckbox(category, locked, "When unlocked, hold Shift and drag the gauge to move it.")

	local scale = Settings.RegisterAddOnSetting(category, "FEELSLIKE_SCALE", "scale", db,
		Settings.VarType.Number, "Scale", defaults.scale)
	scale:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetScale(value)
	end)
	local sliderOptions = Settings.CreateSliderOptions(SCALE_MIN, SCALE_MAX, SCALE_STEP)
	sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatScale)
	Settings.CreateSlider(category, scale, sliderOptions)

	layout:AddInitializer(CreateSettingsButtonInitializer("Position", "Reset", function()
		ns.Gauge:ResetPosition()
	end, "Move the gauge back to its default place below the minimap.", true))

	Settings.RegisterAddOnCategory(category)
	self.category = category
end

function Options:Open()
	Settings.OpenToCategory(self.category:GetID())
end
