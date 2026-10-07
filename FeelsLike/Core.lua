-- Startup, saved variables, the update loop and slash commands.

local addonName, ns = ...

ns.DEFAULTS = {
	unit = "C",
	label = "hover",
	locked = false,
	scale = 0.45, -- picked in game with the classic-style UI (2026-10-04)
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

local wetness = 0
local lastState, lastResult
-- While a test is active, real readings do not move the gauge.
local test
-- Bumped by every test command and by StopTest; pending sweeps and timeouts of older runs do nothing.
local testRun = 0

local function Print(message)
	print(PREFIX .. message)
end

local function InitDB()
	FeelsLikeDB = FeelsLikeDB or {}
	for key, value in pairs(ns.DEFAULTS) do
		if FeelsLikeDB[key] == nil then
			FeelsLikeDB[key] = value
		end
	end
	return FeelsLikeDB
end

local function Update(dt)
	local state = ns.Sensors.Read()
	local result = ns.Model.Compute(state, wetness)
	if dt > 0 then
		wetness = ns.Model.UpdateWetness(wetness, dt, state, result.dry + result.burn)
	end
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
	Update(0)
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
		Update(0)
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
	local shelter = s.inInstance and "instance, no shelter" or s.shelter
	if not s.inInstance and s.rawShelter ~= s.shelter then
		shelter = shelter .. " (" .. s.rawShelter .. " in a moment)"
	end
	print(string.format("  env %s, %s: %s", Signed(r.env), shelter, Signed(r.sheltered)))
	local details = {}
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
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if issecretvalue and issecretvalue(aura) then
			print("  hidden while auras are restricted (combat)")
			return
		end
		if not aura then
			if i == 1 then
				print("  none")
			end
			return
		end
		print(string.format("  %s (%d)%s", aura.name, aura.spellId,
			ns.Sensors.campfireSpells[aura.spellId] and " - counts as campfire" or ""))
	end
end

local function PrintUsage()
	Print("commands")
	print("  /feels - open settings")
	print("  /feels debug - print every factor of the current reading")
	print("  /feels auras - list your buffs (stand by a fire to find its buff)")
	print("  /feels test <-100..100> - point the needle at a value for 30 s")
	print("  /feels test sweep - move the needle across the whole scale")
	print("  /feels test cozy - toggle the Cozy word for 30 s")
	print("  /feels test off - back to real readings")
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
SlashCmdList.FEELSLIKE = function(input)
	local command, arg = strsplit(" ", strtrim(input or ""):lower(), 2)
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
		Test(arg)
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
						Update(0)
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
			ns.Sensors.ResetShelter()
		end
		Update(0)
	end)

	C_Timer.NewTicker(TICK, function()
		Update(TICK)
	end)
	Update(0)
end)
