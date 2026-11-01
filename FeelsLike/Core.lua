-- Startup, settings, update loop and slash commands.

local addonName, ns = ...

ns.DEFAULTS = {
	unit = "C",
	label = "hover",
	locked = false,
	race = true,
	undead = "numb",
	flavor = true,
	-- Default gauge size for Forever and Retail.
	scale = ns.Sensors.isForever and 0.53 or 0.45,
}

local PREFIX = "|cffF2C94CFeels Like|r: "

-- Seconds between updates.
local TICK = 1

local UPDATE_EVENTS = {
	"PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"PLAYER_UPDATE_RESTING",
}

-- Steps for /feels test sweep.
local SWEEP_STEPS = { -100, -80, -50, -20, 0, 20, 40, 60, 80, 100 }
local SWEEP_DELAY = 1.5
-- A test value ends by itself after this many seconds.
local TEST_TIMEOUT = 30

local MAX_AURAS = 255

-- No drunk line for this long counts as sober, in case the game's line was missed. Long, because more
-- drinks at the same level bring no new line.
local DRINK_FORGET = 2 * 60 * 60
local DRUNK_NAMES = { "tipsy", "drunk", "completely smashed" }

local wetness = 0
-- The saved drink, until the game says whether this load is a /reload.
local drinkBeforeReload
local lastState, lastResult
local lastUpdate
-- While a test runs, real readings do not move the gauge.
local test
-- Each test run gets a new number, so old timers do nothing.
local testRun = 0

local function Print(message)
	print(PREFIX .. message)
end

-- Version of the saved settings.
local DB_VERSION = 2
-- Default scale of version 0.1.0.
local OLD_DEFAULT_SCALE = 0.45

local function InitDB()
	FeelsLikeDB = FeelsLikeDB or {}
	if (FeelsLikeDB.version or 1) < 2 and FeelsLikeDB.scale == OLD_DEFAULT_SCALE then
		FeelsLikeDB.scale = nil
	end
	FeelsLikeDB.version = DB_VERSION
	for key, value in pairs(ns.DEFAULTS) do
		if FeelsLikeDB[key] == nil then
			FeelsLikeDB[key] = value
		end
	end
	-- A login starts sober. A /reload gets the drink back at PLAYER_ENTERING_WORLD.
	drinkBeforeReload, FeelsLikeDB.drink = FeelsLikeDB.drink, nil
	return FeelsLikeDB
end

-- How drunk you are, from 0 sober to 3 completely smashed.
local function Drunk(now)
	local drink = FeelsLikeDB.drink
	if not drink or now - drink.at > DRINK_FORGET then
		return 0
	end
	return drink.level
end

-- The body that feels the weather: none with the race setting off, then fur, the undead choice or the race.
local function ChooseBody(state)
	state.raceOff = not FeelsLikeDB.race
	if state.raceOff then
		return nil
	elseif state.form and ns.FurForms[state.form] then
		return ns.Fur
	elseif state.race == "Scourge" then
		state.undead = ns.UndeadFeel[FeelsLikeDB.undead] and FeelsLikeDB.undead or ns.DEFAULTS.undead
		return ns.UndeadFeel[state.undead]
	end
	return state.race and ns.Races[state.race]
end

local function Update()
	-- Update how wet the clothes are since the last update.
	local now = GetTime()
	-- A ghost's swim leaves the body dry.
	if lastState and not lastState.dead then
		wetness = ns.Model.UpdateWetness(wetness, now - lastUpdate, lastState, lastResult.drying)
	end
	lastUpdate = now

	local state = ns.Sensors.Read()
	state.body = ChooseBody(state)
	state.drunk = Drunk(now)
	local result = ns.Model.Compute(state, wetness)
	lastState, lastResult = state, result
	if not test then
		ns.Gauge:SetTarget(result.target)
		ns.Gauge:SetCozy(result.cozy)
	end
	-- The character's own reaction, now and then. Combat, a test or a ghost hold it back for later.
	local held = test ~= nil or InCombatLockdown() or state.dead
	ns.Flavor.OnReading(result, now, held, not FeelsLikeDB.flavor)
end

-- For other addons. Read only.
FeelsLike = { API_VERSION = 1 }

-- Returns the felt temperature from -100 to 100, the word and whether it is Cozy. Nil before the first reading.
function FeelsLike.GetTemperature()
	if not lastResult then
		return nil
	end
	return lastResult.target, ns.Model.Band(lastResult.target, lastResult.cozy).word, lastResult.cozy
end

local function StartTest(value, cozy)
	test = { value = value, cozy = cozy }
	ns.Gauge:SetTarget(value)
	ns.Gauge:SetCozy(cozy)
end

local function StopTest()
	test = nil
	testRun = testRun + 1
	Update()
end

-- Holds a test value for TEST_TIMEOUT seconds.
local function HoldTest(value, cozy)
	testRun = testRun + 1
	local run = testRun
	StartTest(value, cozy)
	C_Timer.After(TEST_TIMEOUT, function()
		if run == testRun then
			StopTest()
			Print("test ended, back to real readings.")
		end
	end)
end

local function Sweep(run, step)
	if run ~= testRun then
		return
	end
	local value = SWEEP_STEPS[step]
	if not value then
		StopTest()
		return
	end
	StartTest(value, false)
	C_Timer.After(SWEEP_DELAY, function()
		Sweep(run, step + 1)
	end)
end

local function Signed(value)
	return string.format("%+.1f", value)
end

local function DescribeResistances(resist)
	if not resist then
		return "not in this client"
	end
	local function One(name, value)
		if not value then
			return name .. " hidden"
		end
		return string.format("%s base %s, real %s, effective %s, bonus %s", name, tostring(value.base),
			tostring(value.real), tostring(value.effective), tostring(value.bonus))
	end
	return One("frost", resist.frost) .. "; " .. One("fire", resist.fire)
end

local function PrintDebug()
	if not lastState then
		Update()
	end
	local s, r = lastState, lastResult
	local band = ns.Model.Band(r.target, r.cozy)

	Print("debug (" .. (ns.Sensors.isForever and "Forever" or "Retail") .. " client)")
	print(string.format("  place: %s, base %s, %s", s.placeName, Signed(s.base), s.climate))
	local gameSays = ""
	if s.gameSaysDay ~= nil then
		gameSays = s.gameSaysDay and " (game: day)" or " (game: night)"
	end
	print(string.format("  time %02d:%02d%s, day/night %s", math.floor(s.hour), math.floor(s.hour % 1 * 60 + 0.5), gameSays, Signed(r.dayNight)))
	if not s.weatherAvailable then
		print("  weather: no C_Weather in this client")
	else
		local info = s.weatherInfo
		print(string.format("  weather: %s, intensity %.2f, %s (raw type %s, intensity %s)",
			s.weather or "clear", s.weatherIntensity, Signed(r.weather),
			tostring(info and info.type), tostring(info and info.intensity)))
	end
	print(string.format("  humid air: %s", Signed(r.humid)))
	local ownShelter = ns.Model.HasOwnShelter(s)
	local shelter = ownShelter and (s.inInstance and "instance" or "inside as a whole") .. ", no shelter"
		or s.shelter
	if not ownShelter and s.rawShelter ~= s.shelter then
		shelter = shelter .. " (" .. s.rawShelter .. " in a moment)"
	end
	print(string.format("  env %s, %s: %s", Signed(r.env), shelter, Signed(r.sheltered)))
	local details = {}
	if s.campfireCamp == "sitting" then
		details[#details + 1] = "sitting by a camp fire"
	elseif s.campfireCamp == "stayed" then
		details[#details + 1] = "near where you sat by a camp fire"
	end
	if s.campfireSince then
		details[#details + 1] = string.format("renewed %.1f s ago, %s", s.campfireSince,
			s.campfireGap and string.format("every %.1f s", s.campfireGap) or "gap not measured yet")
	end
	if s.campfireDistance then
		details[#details + 1] = s.campfireDistance == math.huge and "far from the fire"
			or string.format("%.1f yd from where you stood by it", s.campfireDistance)
	end
	local campfireDetails = #details > 0 and " (" .. table.concat(details, "; ") .. ")" or ""
	print(string.format("  campfire %.2f%s: %s", s.campfire, campfireDetails, Signed(r.campfire)))
	print(string.format("  torch %s: %s", s.torch or "none", Signed(r.torch)))
	print(string.format("  swimming %s, wetness %.2f: %s", s.swimming and "yes" or "no", wetness, Signed(r.wet)))
	local race = s.race or "unknown"
	if s.race and s.raceName and s.raceName ~= s.race then
		race = string.format("%s (%s)", race, s.raceName)
	end
	if s.form then
		local fur = ns.FurForms[s.form]
		race = race .. (fur and string.format(", in %s (fur)", fur) or string.format(", in form %d", s.form))
	end
	if s.raceOff then
		race = race .. ", off in settings"
	elseif s.body then
		if s.undead then
			race = race .. ", " .. ns.UndeadFeelNames[s.undead]:lower()
		end
		race = string.format("%s, cold x%.2f, heat x%.2f", race, s.body.cold, s.body.heat)
		if s.body.shift then
			race = race .. string.format(", shift %+d", s.body.shift)
		end
	elseif s.race then
		race = race .. ", not in the table, feels like a human"
	end
	print(string.format("  race %s: %s", race, Signed(r.race)))
	local drink = "sober"
	if s.drunk > 0 and FeelsLikeDB.drink then
		drink = string.format("%s (%d min)", DRUNK_NAMES[s.drunk], math.floor((GetTime() - FeelsLikeDB.drink.at) / 60))
	end
	print(string.format("  drink %s: %s", drink, Signed(r.drink)))
	local fireSpells = ""
	if s.body and s.body.fireSpells then
		fireSpells = string.format(", fire spells %.2f (undead)", s.fireSpell)
	end
	print(string.format("  fire underfoot %.2f%s: %s", s.burning, fireSpells, Signed(r.burn)))
	print("  resistance, not counted yet: " .. DescribeResistances(ns.Sensors.ReadResistances()))
	if s.dead then
		print(string.format("  dead: the reading stays at %s until you are back", Signed(ns.Model.DEAD_FEEL)))
	end
	print(string.format("  felt %s, target %s: %s%s", Signed(r.felt), Signed(r.target), band.word,
		test and " (test active, /feels test off)" or ""))
	print("  flavor lines " .. ns.Flavor.Describe(GetTime(), FeelsLikeDB.flavor))
	print("  renderer: " .. ns.Gauge.renderer)
	print("  position: " .. ns.Gauge:DescribePosition())
end

-- Lists the player's buffs to find the campfire aura.
local function PrintAuras()
	Print("your buffs")
	local IsSecret = ns.Sensors.IsSecret
	local notes = ns.Sensors.fireAuraNotes
	local function IsHidden(aura)
		return IsSecret(aura) or (aura ~= nil and (IsSecret(aura.name) or IsSecret(aura.spellId)))
	end
	local count = 0
	local function Line(aura, extra)
		local note = notes[aura.spellId]
		print(string.format("  %s (%d)%s%s", aura.name, aura.spellId, extra, note and " - " .. note or ""))
		count = count + 1
	end
	local listed = {}
	for index = 1, MAX_AURAS do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
		if IsHidden(aura) then
			print("  hidden while auras are restricted (combat)")
			return
		end
		if not aura then
			break
		end
		listed[aura.spellId] = true
		Line(aura, "")
	end
	-- Some fire auras are hidden from the buff list, so ask for them by ID.
	local fireIDs = {}
	for spellID in pairs(notes) do
		fireIDs[#fireIDs + 1] = spellID
	end
	table.sort(fireIDs)
	for _, spellID in ipairs(fireIDs) do
		local aura = not listed[spellID] and C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if aura and not IsHidden(aura) then
			Line(aura, ", not in the buff list")
		end
	end
	if count == 0 then
		print("  none")
	end
end

local function PrintUsage()
	Print("commands")
	print("  /feels - open settings")
	print("  /feels debug - print every factor of the current reading")
	print("  /feels auras - list your buffs (sit by a fire to find its buff)")
	print("  /feels test <-100..100> - point the needle at a value for 30 s")
	print("  /feels test sweep - move the needle across the whole scale")
	print("  /feels test cozy - toggle the Cozy word for 30 s")
	print("  /feels test off - back to real readings")
	print("  /feels measure <frame> - where a frame (name or path, like MinimapCluster.DielFrame) sits by the minimap, and the gauge scale of its size")
end

local function Test(arg)
	local value = tonumber(arg)
	if value and value == value then -- skip NaN
		HoldTest(value, test and test.cozy or false)
	elseif arg == "sweep" then
		testRun = testRun + 1
		Sweep(testRun, 1)
	elseif arg == "cozy" then
		local cozy = not (test and test.cozy)
		-- Keep the needle where it is.
		HoldTest(test and test.value or (lastResult and lastResult.target) or 0, cozy)
		Print("test cozy " .. (cozy and "on" or "off"))
	elseif arg == "off" then
		StopTest()
	else
		PrintUsage()
	end
end

SLASH_FEELSLIKE1 = "/feels"
SLASH_FEELSLIKE2 = "/feelslike"
-- Finds a frame by global name or by a path like MinimapCluster.DielFrame.
local function FindFrame(path)
	local target = _G
	for key in path:gmatch("[^.]+") do
		if type(target) ~= "table" then
			return nil
		end
		target = target[key]
	end
	return target
end

-- Prints where a frame sits next to the minimap.
local function Measure(name)
	local target = name and FindFrame(name)
	if type(target) ~= "table" or type(target.GetCenter) ~= "function" then
		Print("no frame named " .. tostring(name) .. ". Hover it with /fstack to see its name.")
		return
	end
	Print(name .. ": " .. ns.Gauge:Describe(target))
	Print("gauge: " .. ns.Gauge:DescribePosition())
end

SlashCmdList.FEELSLIKE = function(input)
	-- Frame names are case sensitive, so only the command is lowercased.
	local command, arg = strsplit(" ", strtrim(input or ""), 2)
	command = command:lower()
	arg = arg and strtrim(arg)
	if command == "" then
		if InCombatLockdown() then
			Print("settings open after combat.")
			return
		end
		ns.Options:Open()
	elseif command == "debug" then
		PrintDebug()
	elseif command == "auras" then
		PrintAuras()
	elseif command == "test" then
		Test(arg and arg:lower())
	elseif command == "measure" then
		Measure(arg)
	else
		PrintUsage()
	end
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	local db = InitDB()
	ns.Gauge:Create(db)
	ns.Options:Register(db)

	local events = CreateFrame("Frame")
	for _, event in ipairs(UPDATE_EVENTS) do
		events:RegisterEvent(event)
	end
	-- Only register events the client knows.
	for _, event in ipairs({ "WEATHER_CHANGED", "UPDATE_SHAPESHIFT_FORM" }) do
		if C_EventUtils and C_EventUtils.IsEventValid(event) then
			events:RegisterEvent(event)
		end
	end
	-- The game's drunk lines come as system lines.
	events:RegisterEvent("CHAT_MSG_SYSTEM")
	-- Fire damage, end of combat and campfire aura updates.
	events:RegisterUnitEvent("UNIT_COMBAT", "player")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_COMBAT" then
			local _, action, _, amount, schoolMask = ...
			if ns.Sensors.IsFireHit(action, amount, schoolMask) then
				-- A fire mob can hit before combat starts, so check again next frame.
				C_Timer.After(0, function()
					-- Only a body that feels fire spells needs the reading now. The rest wait for the tick.
					local fireSpell = ns.Sensors.OnFireHit()
					if not fireSpell or (lastState and lastState.body and lastState.body.fireSpells) then
						Update()
					end
				end)
			end
			return
		elseif event == "CHAT_MSG_SYSTEM" then
			local level = ns.Sensors.DrunkLevel((...))
			if not level then
				return
			end
			FeelsLikeDB.drink = level > 0 and { level = level, at = GetTime() } or nil
			drinkBeforeReload = nil -- the new line wins
		elseif event == "UNIT_AURA" then
			local _, updateInfo = ...
			ns.Sensors.OnUnitAura(updateInfo)
			return
		elseif event == "PLAYER_REGEN_ENABLED" then
			ns.Sensors.OnCombatEnded()
			return
		elseif event == "UPDATE_SHAPESHIFT_FORM" then
			-- Fires often, also without a new form.
			if lastState and ns.Sensors.ReadForm() == lastState.form then
				return
			end
		elseif event == "PLAYER_ENTERING_WORLD" then
			local isInitialLogin, isReloadingUi = ...
			ns.Sensors.OnLoadingScreen(not (isInitialLogin or isReloadingUi))
			if isInitialLogin or isReloadingUi then
				ns.Flavor.OnLogin(GetTime())
			end
			if isReloadingUi and drinkBeforeReload then
				FeelsLikeDB.drink = drinkBeforeReload
			end
			drinkBeforeReload = nil
		end
		Update()
	end)

	C_Timer.NewTicker(TICK, function()
		Update()
	end)
	Update()
end)
