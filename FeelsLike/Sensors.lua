-- Reads the game state the model needs. All WoW API calls for the model live here.

local _, ns = ...

local Sensors = {}
ns.Sensors = Sensors

-- In the Forever client Blizzard calls the project Camelot.
Sensors.isForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

local zones = Sensors.isForever and ns.Zones.forever or ns.Zones.retail
local UNKNOWN_ZONE = { base = 0, climate = "temperate" }
local UNKNOWN_INSTANCE = { base = 0, climate = "none" }
local MAX_PARENT_STEPS = 10

-- Every Cozy Fire aura in the game data (wago.tools SpellName, SpellEffect). A fire applies them to
-- players around it for 60 s and renews them while they stay. 7353 is the Basic Campfire one.
-- 458740 is also named Cozy Fire, but it is a dummy spell with no aura, so it is left out.
local COZY_FIRE_SPELLS = { 7353, 7358, 223298, 432573 }

-- For /feels auras.
Sensors.campfireSpells = {}
for _, spellID in ipairs(COZY_FIRE_SPELLS) do
	Sensors.campfireSpells[spellID] = true
end

local weatherKinds = {}
if Enum and Enum.WeatherType then
	weatherKinds[Enum.WeatherType.Rain] = "rain"
	weatherKinds[Enum.WeatherType.Snow] = "snow"
	weatherKinds[Enum.WeatherType.Sandstorm] = "sandstorm"
end

local FIRE_MASK = Enum and Enum.Damageclass and Enum.Damageclass.MaskFire or 4

local subzonesByName
-- Campfire. Two signs that you are still by the fire, and both must hold:
-- 1. Freshness: the fire renews the 60 s aura while you stand near, so an aging aura means you left.
--    Remember when the freshest aura was last renewed and the shortest gap seen between two renewals:
--    a fire renews on a fixed beat, longer gaps mean you stepped away and came back. After more than
--    any beat without renewal, you left: start over for the next fire.
-- 2. Distance: some clients give addons no timer for this aura (seen on Retail, 2026-10-04), and the
--    aura then stays up to a minute after you leave. So also remember where you stood by the fire and
--    count you as gone once you are farther than the aura reaches.
local campfireRenewedAt
local campfireRenewalGap
local RENEWAL_EPSILON = 0.25 -- seconds; smaller moves of the renewal time are rounding
local MAX_RENEWAL_GAP = 15 -- seconds; no fire's beat is longer than this
local JUST_RENEWED = 2 -- seconds; a first-seen timed aura this fresh was renewed by a fire right now

local CAMPFIRE_RADIUS = 10 -- yards the aura reaches around the fire (SpellRadius 13 in the game data)
local AWAY_DISTANCE = CAMPFIRE_RADIUS + 2
local campfireAnchor -- { x, y, map }: where you were last seen by the fire
local campfireAnchorSettled -- the anchor moved to where you first stood still; only once per aura
local campfireAuraID -- auraInstanceID of the aura the anchor belongs to
local campfireLeftAt -- when you got farther than AWAY_DISTANCE from the anchor
-- UNIT_AURA reported an update of the campfire aura: a fire renewed it, so you are within its reach.
-- The only renewal sign for an aura without a timer (moving from one fire to another).
local campfireAuraUpdated = false

-- Fire underfoot. Fire damage taken outside combat; ignored for a while after combat, when fire DoTs
-- from the fight still tick.
local COMBAT_GRACE = 15 -- seconds
local lastCombatEnd
local lastFireHit
local shelterMemory = {}

-- Map IDs inside a zone (caves, start areas) are children of it, so walk up to a known zone.
local function FindZone(mapID)
	for _ = 1, MAX_PARENT_STEPS do
		if not mapID or mapID == 0 then
			return nil
		end
		if zones[mapID] then
			return zones[mapID], mapID
		end
		local info = C_Map.GetMapInfo(mapID)
		mapID = info and info.parentMapID
	end
end

-- GetSubZoneText() is localized, so match it against localized area names.
local function FindSubzone()
	if not subzonesByName then
		subzonesByName = {}
		for areaID, entry in pairs(ns.Zones.subzones) do
			local name = C_Map.GetAreaInfo(areaID)
			if name and name ~= "" then
				subzonesByName[name] = entry
			end
		end
	end
	local name = GetSubZoneText()
	if name and name ~= "" and subzonesByName[name] then
		return subzonesByName[name], name
	end
end

local function ReadPlace(state)
	local instanceName, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
	if instanceType ~= "none" then
		state.inInstance = true
		local entry = ns.Instances[instanceID]
		state.place = entry or UNKNOWN_INSTANCE
		state.placeName = string.format("%s (instance %d%s)", instanceName, instanceID, entry and "" or ", not in table")
		return
	end

	local subzone, subzoneName = FindSubzone()
	if subzone then
		state.place = subzone
		state.placeName = subzoneName .. " (subzone)"
		return
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	local zone, zoneMapID = FindZone(mapID)
	if zone then
		state.place = zone
		state.placeName = string.format("%s (map %d)", GetZoneText(), zoneMapID)
	else
		state.place = UNKNOWN_ZONE
		state.placeName = string.format("%s (map %s, not in table)", GetZoneText(), tostring(mapID))
	end
end

-- Returns kind ("rain", "snow", "sandstorm" or nil), intensity 0..1, and the raw info for debug.
local function ReadWeather()
	if not (C_Weather and C_Weather.GetCurrentWeather) then
		return nil, 0, nil
	end
	local info = C_Weather.GetCurrentWeather()
	local kind = info and weatherKinds[info.type]
	if not kind then
		return nil, 0, info
	end
	local intensity = math.max(0, math.min(1, info.intensity or 1))
	return kind, intensity, info
end

local function HasTimer(aura)
	return aura.duration and aura.duration > 0 and aura.expirationTime and aura.expirationTime > 0
end

local function ForgetCampfire()
	campfireRenewedAt, campfireRenewalGap = nil, nil
	campfireAnchor, campfireAnchorSettled, campfireAuraID, campfireLeftAt = nil, nil, nil, nil
end

-- x, y, map in yards, or nil where the game hides the position (instances).
local function PlayerPosition()
	local y, x, _, map = UnitPosition("player")
	if not y or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
		return nil
	end
	return x, y, map
end

-- Distance sign. renewed: the fire just renewed a timed aura, so you are within its reach right now.
-- Returns nearness 0..1 and the distance to the anchor in yards (nil when the position is unknown).
local function DistanceNearness(now, auraID, renewed)
	renewed = renewed or campfireAuraUpdated
	campfireAuraUpdated = false
	local x, y, map = PlayerPosition()
	if not x then
		return 1, nil
	end

	-- Move the anchor to you when: there is none yet; a new aura appeared (a new fire); the fire just
	-- renewed a timed aura (you are within reach); or you stand still for the first time with this aura
	-- while near (the aura may start at the edge of its reach, but you stop by the fire itself).
	local newAura = auraID ~= campfireAuraID
	local standingStill = GetUnitSpeed("player") == 0
	local firstStop = standingStill and not campfireAnchorSettled and not campfireLeftAt
	local noAnchor = not campfireAnchor
	if noAnchor or newAura or renewed or firstStop then
		campfireAnchor = { x = x, y = y, map = map }
		if noAnchor or newAura then
			campfireAnchorSettled = standingStill
		elseif firstStop then
			campfireAnchorSettled = true
		end
		campfireAuraID = auraID
		campfireLeftAt = nil
	end

	local distance = math.huge
	if map == campfireAnchor.map then
		distance = math.sqrt((x - campfireAnchor.x) ^ 2 + (y - campfireAnchor.y) ^ 2)
	end
	if distance > AWAY_DISTANCE then
		campfireLeftAt = campfireLeftAt or now
	else
		campfireLeftAt = nil
	end
	return ns.Model.CampfireDistanceNearness(campfireLeftAt and now - campfireLeftAt), distance
end

-- Returns nearness 0..1, seconds since renewal (nil without a timer), measured gap (or nil),
-- distance from where you stood by the fire (nil when unknown).
-- While aura data is secret (combat), assume no renewal since the last one seen, so warmth still fades.
local function CampfireNearness()
	local now = GetTime()
	local timed, renewedAt, untimed
	for _, spellID in ipairs(COZY_FIRE_SPELLS) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if issecretvalue and issecretvalue(aura) then
			if not campfireAnchor and not campfireRenewedAt then
				return 0
			end
			local distanceNearness, distance = DistanceNearness(now, campfireAuraID, false)
			local fresh, since = 1, nil
			if campfireRenewedAt then
				since = now - campfireRenewedAt
				fresh = ns.Model.CampfireNearness(since, campfireRenewalGap)
			end
			return math.min(fresh, distanceNearness), since, campfireRenewalGap, distance
		end
		if aura then
			if HasTimer(aura) then
				local at = aura.expirationTime - aura.duration
				if not renewedAt or at > renewedAt then
					timed, renewedAt = aura, at
				end
			else
				untimed = aura
			end
		end
	end

	if not timed and not untimed then
		ForgetCampfire()
		return 0
	end

	-- Freshness (timed auras only; without a timer there is nothing to measure).
	local fresh, since, gap, renewed = 1, nil, nil, false
	if timed then
		since = math.max(0, now - renewedAt)
		if campfireRenewedAt and renewedAt > campfireRenewedAt + RENEWAL_EPSILON then
			renewed = true
			local newGap = renewedAt - campfireRenewedAt
			if newGap <= MAX_RENEWAL_GAP and (not campfireRenewalGap or newGap < campfireRenewalGap) then
				campfireRenewalGap = newGap
			end
		elseif not campfireRenewedAt and since <= JUST_RENEWED then
			renewed = true -- back at a fire after the measurement was reset
		end
		gap = campfireRenewalGap
		fresh = ns.Model.CampfireNearness(since, gap)
		-- Start over only once the warmth has fully faded, so a long measured beat still fades smoothly.
		if since > MAX_RENEWAL_GAP and fresh == 0 then
			campfireRenewedAt, campfireRenewalGap = nil, nil
		else
			campfireRenewedAt = renewedAt
		end
	end

	local aura = timed or untimed
	local distanceNearness, distance = DistanceNearness(now, aura.auraInstanceID, renewed)
	return math.min(fresh, distanceNearness), since, gap, distance
end

-- UNIT_AURA for the player: notes when the game renews the campfire aura.
function Sensors.OnUnitAura(updateInfo)
	if not updateInfo or (issecretvalue and issecretvalue(updateInfo)) or not campfireAuraID then
		return
	end
	for _, auraID in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
		if auraID == campfireAuraID then
			campfireAuraUpdated = true
			return
		end
	end
end

function Sensors.OnCombatEnded()
	lastCombatEnd = GetTime()
end

-- UNIT_COMBAT for the player: true for fire damage. Fire damage outside combat is almost always
-- a campfire or lava underfoot; Core confirms it with AcceptFireHit one frame later.
function Sensors.IsFireHit(action, amount, schoolMask)
	if issecretvalue and (issecretvalue(action) or issecretvalue(amount) or issecretvalue(schoolMask)) then
		return false
	end
	return action == "WOUND" and amount ~= nil and amount > 0 and bit.band(schoolMask or 0, FIRE_MASK) ~= 0
end

-- Called a frame after the hit, when the combat flag of a fight that this hit started is set.
-- Returns true when the hit counts as fire underfoot.
function Sensors.AcceptFireHit()
	local now = GetTime()
	if InCombatLockdown() or (lastCombatEnd and now - lastCombatEnd < COMBAT_GRACE) then
		return false
	end
	lastFireHit = now
	return true
end

-- After a loading screen (hearth, portal) the new place counts at once, without the door delay.
function Sensors.ResetShelter()
	shelterMemory = {}
end

function Sensors.Read()
	local state = {}
	ReadPlace(state)
	state.base = state.place.base
	state.climate = state.place.climate

	local hour, minute = GetGameTime()
	state.hour = hour + minute / 60
	-- Forever has its own day/night indicator; debug prints it next to our clock to compare.
	if C_DateAndTime and C_DateAndTime.IsDayTime then
		state.gameSaysDay = C_DateAndTime.IsDayTime()
	end

	state.weather, state.weatherIntensity, state.weatherInfo = ReadWeather()
	state.weatherAvailable = C_Weather ~= nil

	-- IsResting() alone is not enough: whole capital cities are rest areas.
	local rawShelter = "outdoors"
	if IsIndoors() then
		rawShelter = IsResting() and "inn" or "indoors"
	end
	state.rawShelter = rawShelter
	state.shelter = ns.Model.SettleShelter(shelterMemory, rawShelter, GetTime())
	state.indoors = state.shelter ~= "outdoors"
	state.inn = state.shelter == "inn"
	state.campfire, state.campfireSince, state.campfireGap, state.campfireDistance = CampfireNearness()
	state.swimming = IsSwimming()
	state.burning = ns.Model.Burning(lastFireHit and GetTime() - lastFireHit, state.swimming)
	return state
end
