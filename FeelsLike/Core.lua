-- Startup, saved variables, the update loop and slash commands.

local addonName, ns = ...

ns.DEFAULTS = {
	unit = "C",
	label = "hover",
	locked = false,
	-- Forever: as big as the day/night button by the minimap, its band and outline on the button's
	-- (measured on Forever screenshots, 2026-10-21). Retail: picked in game with the classic-style UI
	-- (2026-10-04).
	scale = ns.Sensors.isForever and 0.53 or 0.45,
}

local PREFIX = "|cffF2C94CFeels Like|r: "

-- Seconds between updates. Swimming, time of day and drying have no events, so they need a timer.
local TICK = 1

local UPDATE_EVENTS = {
	"PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"PLAYER_UPDATE_RESTING",
}

-- /feels test sweep steps.
local SWEEP_STEPS = { -100, -80, -50, -20, 0, 20, 40, 60, 80, 100 }
local SWEEP_DELAY = 1.5
-- A test value gives the gauge back to real readings by itself, so it never stays stuck.
local TEST_TIMEOUT = 30

local MAX_AURAS = 255 -- /feels auras lists at most this many buffs

local wetness = 0
local lastState, lastResult
local lastUpdate -- GetTime() of the last Update
-- While a test is active, real readings do not move the gauge.
local test
-- Bumped by every test command and by StopTest; pending sweeps and timeouts of older runs do nothing.
local testRun = 0

local function Print(message)
	print(PREFIX .. message)
end

-- The saved settings' version. 0.1.0 saved none, and it saved its defaults as if they were choices.
local DB_VERSION = 2
-- 0.1.0's default scale. A gauge still at it was likely never resized, so it takes this version's
-- default (Forever's now matches the day/night button; Retail's is the same 0.45).
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
	return FeelsLikeDB
end

local function Update()
	-- Clothes dried or soaked over the real time since the last update, in the conditions of that time.
	-- A loading screen delays updates, and that time counts where you were, not where you arrive.
	local now = GetTime()
	if lastState then
		wetness = ns.Model.UpdateWetness(wetness, now - lastUpdate, lastState, lastResult.dry + lastResult.burn)
	end
	lastUpdate = now

	local state = ns.Sensors.Read()
	local result = ns.Model.Compute(state, wetness)
	lastState, lastResult = state, result
	if not test then
		ns.Gauge:SetTarget(result.target)
		ns.Gauge:SetCozy(result.cozy)
	end
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

-- Starts a held test value that ends by itself after TEST_TIMEOUT seconds.
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
	print(string.format("  fire underfoot %.2f: %s", s.burning, Signed(r.burn)))
	print(string.format("  felt %s, target %s: %s%s", Signed(r.felt), Signed(r.target), band.word,
		test and " (test active, /feels test off)" or ""))
	print("  renderer: " .. ns.Gauge.renderer)
	print("  position: " .. ns.Gauge:DescribePosition())
end

-- Lists the player's buffs, to find which aura a campfire gives.
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
	-- Modern clients allow more than 40 buffs; the cap only guards against a list that never ends.
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
	-- Some fire auras are kept off the buff list by the game; asked by ID, the client may still give them.
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
	if value and value == value then -- value == value rules out NaN ("nan")
		HoldTest(value, test and test.cozy or false)
	elseif arg == "sweep" then
		testRun = testRun + 1
		Sweep(testRun, 1)
	elseif arg == "cozy" then
		local cozy = not (test and test.cozy)
		-- Keep the needle where it is: the running test value, or else the real reading.
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
-- A frame by its global name, or by a path of keys from a global frame ("MinimapCluster.DielFrame"):
-- /fstack shows frames without a name of their own by an address that cannot be looked up.
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

-- Prints where a frame (by its global name or path, as /fstack shows it) sits by the minimap.
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
	-- Frame names are case-sensitive, so only the command is lowercased here.
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
	-- Registering an event the client does not know raises an error.
	if C_EventUtils and C_EventUtils.IsEventValid("WEATHER_CHANGED") then
		events:RegisterEvent("WEATHER_CHANGED")
	end
	-- Fire or lava damage taken outside combat (see Sensors.IsFireHit), the end of combat, and
	-- updates of the campfire aura.
	events:RegisterUnitEvent("UNIT_COMBAT", "player")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_COMBAT" then
			local _, action, _, amount, schoolMask = ...
			if ns.Sensors.IsFireHit(action, amount, schoolMask) then
				-- A fire mob's first hit can arrive before the combat flag; look again next frame.
				C_Timer.After(0, function()
					if ns.Sensors.AcceptFireHit() then
						Update()
					end
				end)
			end
			return
		elseif event == "UNIT_AURA" then
			local _, updateInfo = ...
			ns.Sensors.OnUnitAura(updateInfo)
			return
		elseif event == "PLAYER_REGEN_ENABLED" then
			ns.Sensors.OnCombatEnded()
			return
		elseif event == "PLAYER_ENTERING_WORLD" then
			local isInitialLogin, isReloadingUi = ...
			ns.Sensors.OnLoadingScreen(not (isInitialLogin or isReloadingUi))
		end
		Update()
	end)

	C_Timer.NewTicker(TICK, function()
		Update()
	end)
	Update()
end)
