-- Settings panel in Options, AddOns, Feels Like.

local _, ns = ...
local T = ns.T

local Options = {}
ns.Options = Options

local SCALE_MIN = 0.3
local SCALE_MAX = 2
local SCALE_STEP = 0.01
-- The window that offers a reload after the language changed, sized like the game's own windows.
local WINDOW_WIDTH = 320
local WINDOW_PADDING = 16
local BUTTON_WIDTH, BUTTON_HEIGHT = 128, 21
local BUTTON_TEXT_PADDING = 24 -- a longer word makes the button wider
local BUTTON_GAP = 12
local window

local function UnitOptions()
	local container = Settings.CreateControlTextContainer()
	container:Add("C", T("Celsius"))
	container:Add("F", T("Fahrenheit"))
	return container:GetData()
end

local function LabelOptions()
	local container = Settings.CreateControlTextContainer()
	container:Add("hover", T("On hover"))
	container:Add("always", T("Always"))
	container:Add("never", T("Never"))
	return container:GetData()
end

local function UndeadOptions()
	local container = Settings.CreateControlTextContainer()
	for _, key in ipairs(ns.UndeadFeelOrder) do
		container:Add(key, T(ns.UndeadFeelNames[key]))
	end
	return container:GetData()
end

-- Each language under its own name.
local function LanguageOptions()
	local container = Settings.CreateControlTextContainer()
	for _, key in ipairs(ns.Locale.order) do
		container:Add(key, ns.Locale.names[key])
	end
	return container:GetData()
end

local function FormatScale(value)
	return string.format("%.2f", value)
end

function Options:Register(db)
	local defaults = ns.DEFAULTS
	local category, layout = Settings.RegisterVerticalLayoutCategory("Feels Like")

	local unit = Settings.RegisterAddOnSetting(category, "FEELSLIKE_UNIT", "unit", db,
		Settings.VarType.String, T("Units"), defaults.unit)
	unit:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetUnit(value)
	end)
	Settings.CreateDropdown(category, unit, UnitOptions, T("Unit symbol inside the gauge."))

	local label = Settings.RegisterAddOnSetting(category, "FEELSLIKE_LABEL", "label", db,
		Settings.VarType.String, T("Show status"), defaults.label)
	label:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetLabelMode(value)
	end)
	Settings.CreateDropdown(category, label, LabelOptions,
		T("The status is one word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."))

	local tooltip = Settings.RegisterAddOnSetting(category, "FEELSLIKE_TOOLTIP", "tooltip", db,
		Settings.VarType.Boolean, T("Tooltip on hover"), defaults.tooltip)
	tooltip:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetTooltip(value)
	end)
	Settings.CreateCheckbox(category, tooltip,
		T("On: hover the gauge for a tooltip with the status and why it is so. Off: no tooltip, only the status word as set above."))

	local race = Settings.RegisterAddOnSetting(category, "FEELSLIKE_RACE", "race", db,
		Settings.VarType.Boolean, T("Feel by race"), defaults.race)
	Settings.CreateCheckbox(category, race,
		T("Your race changes how strongly you feel the cold and the heat. Dwarves handle the cold better. Tauren handle the cold but feel the heat more, and trolls the other way round. The undead feel little of either. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren. It shows in cold and hot places: a mild place feels almost the same to everyone."))

	local undead = Settings.RegisterAddOnSetting(category, "FEELSLIKE_UNDEAD", "undead", db,
		Settings.VarType.String, T("Undead feel"), defaults.undead)
	Settings.CreateDropdown(category, undead, UndeadOptions,
		T("Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."))

	local seasons = Settings.RegisterAddOnSetting(category, "FEELSLIKE_SEASONS", "seasons", db,
		Settings.VarType.Boolean, T("Seasons and holidays"), defaults.seasons)
	Settings.CreateCheckbox(category, seasons,
		T("On: winter (December to February) feels a little colder and summer (June to August) a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar. Off: the date changes nothing, and every day feels like spring or autumn."))

	local flavor = Settings.RegisterAddOnSetting(category, "FEELSLIKE_FLAVOR", "flavor", db,
		Settings.VarType.Boolean, T("Flavor lines in chat"), defaults.flavor)
	Settings.CreateCheckbox(category, flavor,
		T("Now and then a short line in chat, only for you, when your character starts to feel the cold, the heat or Cozy."))

	local language = Settings.RegisterAddOnSetting(category, "FEELSLIKE_LANGUAGE", "language", db,
		Settings.VarType.String, T("Language"), defaults.language)
	language:SetValueChangedCallback(function(_, value)
		ns.SetLanguage(value)
	end)
	Settings.CreateDropdown(category, language, LanguageOptions,
		T("The language of the status, the tooltip and the lines in chat. They change at once. This page changes after a reload of the interface, and the addon offers one."))

	local locked = Settings.RegisterAddOnSetting(category, "FEELSLIKE_LOCKED", "locked", db,
		Settings.VarType.Boolean, T("Lock position"), defaults.locked)
	locked:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetLocked(value)
	end)
	Settings.CreateCheckbox(category, locked, T("When unlocked, hold Shift and drag the gauge to move it."))

	local scale = Settings.RegisterAddOnSetting(category, "FEELSLIKE_SCALE", "scale", db,
		Settings.VarType.Number, T("Scale"), defaults.scale)
	scale:SetValueChangedCallback(function(_, value)
		ns.Gauge:SetScale(value)
	end)
	local sliderOptions = Settings.CreateSliderOptions(SCALE_MIN, SCALE_MAX, SCALE_STEP)
	sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatScale)
	Settings.CreateSlider(category, scale, sliderOptions)

	layout:AddInitializer(CreateSettingsButtonInitializer(T("Position"), T("Reset"), function()
		ns.Gauge:ResetPosition()
	end, T("Move the gauge back to its default place by the minimap."), true))

	Settings.RegisterAddOnCategory(category)
	self.category = category
	-- The page keeps the language it was built in until a reload.
	self.language = ns.Locale.language
end

-- The window is the addon's own. The game's StaticPopup windows also ask the game's own questions, like deleting
-- an item or a group invite, and one shown by addon code can make the game block the answer to the next one.
-- Escape does not close it: an addon frame in UISpecialFrames or in the game's Escape handlers taints the game
-- menu. It sits over the settings page, in the middle of the screen and one strata under the game's own
-- windows, which start at the top of the screen: a question of the game shows over it.
local function ReloadWindow()
	if window then
		return window
	end
	window = CreateFrame("Frame", "FeelsLikeReloadWindow", UIParent)
	window:SetSize(WINDOW_WIDTH, 2 * WINDOW_PADDING + BUTTON_HEIGHT)
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	window:SetFrameStrata("HIGH") -- the strata of the settings page
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true) -- a click on the window does not go through to the world
	local border = CreateFrame("Frame", nil, window, "DialogBorderTemplate")
	border:SetAllPoints()
	window.text = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	window.text:SetPoint("TOP", 0, -WINDOW_PADDING)
	window.text:SetWidth(WINDOW_WIDTH - 2 * WINDOW_PADDING)
	window.reload = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	window.reload:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	window.reload.fitTextWidthPadding = BUTTON_TEXT_PADDING
	window.reload:SetPoint("BOTTOMRIGHT", window, "BOTTOM", -BUTTON_GAP / 2, WINDOW_PADDING)
	window.reload:SetScript("OnClick", function()
		ReloadUI()
	end)
	window.later = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	window.later:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	window.later.fitTextWidthPadding = BUTTON_TEXT_PADDING
	window.later:SetPoint("BOTTOMLEFT", window, "BOTTOM", BUTTON_GAP / 2, WINDOW_PADDING)
	window.later:SetScript("OnClick", function()
		window:Hide()
	end)
	window:Hide()
	return window
end

-- After the language changed: the settings page still shows the old one, so offer a reload in a window.
-- Back to the language of the page, the window goes away.
function Options:OfferReload()
	if ns.Locale.language == self.language then
		if window then
			window:Hide()
		end
		return
	end
	local offer = ReloadWindow()
	-- Filled each time, so it speaks the new language.
	offer.text:SetText(T("Feels Like: the language changed. The status, the tooltip and the lines in chat have changed already. The settings page changes after a reload of the interface. Reload now?"))
	-- A button grows to fit its word, and the window grows with the buttons.
	offer.reload:SetWidth(BUTTON_WIDTH)
	offer.reload:SetTextToFit(T("Reload"))
	offer.later:SetWidth(BUTTON_WIDTH)
	offer.later:SetTextToFit(T("Later"))
	offer:SetWidth(math.max(WINDOW_WIDTH, offer.reload:GetWidth() + offer.later:GetWidth() + BUTTON_GAP
		+ 2 * WINDOW_PADDING))
	offer:SetHeight(offer.text:GetStringHeight() + 3 * WINDOW_PADDING + BUTTON_HEIGHT)
	offer:Show()
	offer:Raise() -- over the settings page, which has the same strata
end

function Options:Open()
	Settings.OpenToCategory(self.category:GetID())
end
