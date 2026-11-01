-- Reads the game state for the model.

local _, ns = ...

local Sensors = {}
ns.Sensors = Sensors

-- Blizzard calls the Forever client Camelot.
Sensors.isForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

local zones = Sensors.isForever and ns.Zones.forever or ns.Zones.retail
local UNKNOWN_ZONE = { base = 0, climate = "temperate" }
local UNKNOWN_INSTANCE = { base = 0, climate = "none" }
local MAX_PARENT_STEPS = 10

-- All Cozy Fire aura IDs. 1232234 is the Forever camp fire.
local COZY_FIRE_SPELLS = { 7353, 7358, 223298, 432573, 1232234 }

-- Forever camp fire auras. Sitting by a camp fire gives Welcoming Campfire for 60 s.
local WELCOMING_CAMPFIRE_SPELLS = { 1229739, 1289723 }
local CAMP_BENEFITS = 1229741
-- Campfire Nearby, within 100 yd of a camp fire.
local CAMPFIRE_NEARBY = 1283391
local CAMPFIRE_HIDDEN = 1229736 -- hidden aura near a camp fire
-- Warmth stays near your seat for up to 15 min, as long as a camp fire burns.
local CAMP_FIRE_LIFETIME = 15 * 60

-- Night Watchman's Torch, a toy that puts a lit torch in your hand.
local TORCH_SPELLS = { 1309410, 1321139 }
-- Lit torches you can hold.
local TORCH_ITEMS = {
	[1172] = true, -- Grayson's Torch
	[2410] = true, -- Smoky Torch
	[2808] = true, -- Torch of Flame
	[6182] = true, -- Dim Torch
	[6654] = true, -- Torch of the Eternal Flame
	[7344] = true, -- Torch of Holy Flame
	[10515] = true, -- Torch of Retribution
}
local HAND_SLOTS = { 16, 17 } -- main hand and off hand

local CAMPFIRE_SPELLS = {}
local sittingSpells = {}
for _, spellID in ipairs(COZY_FIRE_SPELLS) do
	CAMPFIRE_SPELLS[#CAMPFIRE_SPELLS + 1] = spellID
end
for _, spellID in ipairs(WELCOMING_CAMPFIRE_SPELLS) do
	CAMPFIRE_SPELLS[#CAMPFIRE_SPELLS + 1] = spellID
	sittingSpells[spellID] = true
end

-- Fire auras the addon knows, for /feels auras.
Sensors.fireAuraNotes = {}
for _, spellID in ipairs(CAMPFIRE_SPELLS) do
	Sensors.fireAuraNotes[spellID] = "counts as campfire"
end
for _, spellID in ipairs(TORCH_SPELLS) do
	Sensors.fireAuraNotes[spellID] = "counts as a torch"
end
Sensors.fireAuraNotes[CAMP_BENEFITS] = "camp buffs, not counted"
Sensors.fireAuraNotes[CAMPFIRE_NEARBY] = "camp fire nearby: its end ends the warmth where you sat"
Sensors.fireAuraNotes[CAMPFIRE_HIDDEN] = "camp fire, not counted"

local weatherKinds = {}
if Enum and Enum.WeatherType then
	weatherKinds[Enum.WeatherType.Rain] = "rain"
	weatherKinds[Enum.WeatherType.Snow] = "snow"
	weatherKinds[Enum.WeatherType.Sandstorm] = "sandstorm"
end

local FIRE_MASK = Enum and Enum.Damageclass and Enum.Damageclass.MaskFire or 4

local subzonesByName
-- Campfire state. You count as near while the aura keeps renewing and you stay close to where you stood.
local campfireRenewedAt
local campfireRenewalGap
local campfireLastGap -- latest gap
local campfireSameGaps = 0 -- matching gaps in a row
local RENEWAL_EPSILON = 0.25 -- smaller changes are rounding
local SAME_BEAT = 0.5 -- gaps this close are the same beat
local MAX_RENEWAL_GAP = 15 -- no fire renews slower than this
local JUST_RENEWED = 2 -- an aura this fresh was just renewed

local CAMPFIRE_RADIUS = 10 -- yards the aura reaches
local AWAY_DISTANCE = CAMPFIRE_RADIUS + 2
local campfireAnchor -- where you last stood by the fire
local campfireAnchorSettled -- anchor moved once per aura
local campfireAuraID -- aura the anchor belongs to
local campfireLeftAt -- when you walked too far
-- When UNIT_AURA last reported a renewal.
local campfireAuraUpdatedAt
-- When the last loading screen that moved you ended.
local campfireLoadedAt
local LOADING_SETTLE = 5 -- the client is still loading auras
local campSeat -- the Welcoming Campfire you sat with

-- Fire damage outside combat.
local COMBAT_GRACE = 15 -- seconds
local lastCombatEnd
local lastFireHit
local shelterMemory = {}

-- Walk up the map parents to a known zone.
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

-- Subzone names are localized.
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

-- Returns weather kind, intensity and raw info.
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

-- In combat values may be secret.
local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end
Sensors.IsSecret = IsSecret

local function IsSecretAura(aura)
	return IsSecret(aura) or (aura ~= nil and (IsSecret(aura.duration) or IsSecret(aura.expirationTime)
		or IsSecret(aura.auraInstanceID)))
end

local function HasTimer(aura)
	return aura.duration and aura.duration > 0 and aura.expirationTime and aura.expirationTime > 0
end

-- True when gap is a whole multiple of beat.
local function IsMultipleOf(gap, beat)
	if beat <= 2 * SAME_BEAT then
		return false
	end
	local times = math.floor(gap / beat + 0.5)
	return times >= 2 and math.abs(gap - times * beat) <= SAME_BEAT
end

local function ForgetBeat()
	campfireRenewedAt, campfireRenewalGap, campfireLastGap, campfireSameGaps = nil, nil, nil, 0
end

-- Forgets the fire you stood by.
local function LeaveFire()
	ForgetBeat()
	campfireAnchor, campfireAnchorSettled, campfireLeftAt = nil, nil, nil
	campfireAuraUpdatedAt = nil
	campSeat = nil
end

local function ForgetCampfire(now)
	LeaveFire()
	campfireAuraID = nil
	if campfireLoadedAt and now - campfireLoadedAt > LOADING_SETTLE then
		campfireLoadedAt = nil
	end
end

-- Player position in yards, or nil when hidden.
local function PlayerPosition()
	local y, x, _, map = UnitPosition("player")
	if not y or IsSecret(x) or IsSecret(y) then
		return nil
	end
	return x, y, map
end

-- Distance check. Returns nearness and distance to the anchor.
local function DistanceNearness(now, auraID, renewed, timed)
	-- Right after loading, an aura update is not a renewal.
	local updatedAt = not timed and campfireAuraUpdatedAt
	local refresh = updatedAt and campfireLoadedAt and updatedAt - campfireLoadedAt <= LOADING_SETTLE
	renewed = renewed or (updatedAt and not refresh) or false
	campfireAuraUpdatedAt = nil
	if campfireLoadedAt then
		-- Follow the aura's current ID.
		campfireAuraID = auraID
		if not renewed then
			return 0, nil
		end
		-- A fire renewed the aura after loading.
		campfireLoadedAt = nil
	end
	local x, y, map = PlayerPosition()
	if not x then
		-- Without a position only the aura tells.
		if auraID ~= campfireAuraID or renewed then
			campfireAuraID, campfireLeftAt, campfireAnchor = auraID, nil, nil
		end
		return ns.Model.CampfireDistanceNearness(campfireLeftAt and now - campfireLeftAt), nil
	end

	-- Move the anchor to where you are when needed.
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

-- Sitting by a camp fire.
local function SittingNearness(now, aura)
	if not campSeat or campSeat.auraID ~= aura.auraInstanceID then
		campSeat = { auraID = aura.auraInstanceID, satAt = now }
	end
	local nearby = C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY)
	if not IsSecretAura(nearby) and nearby then
		campSeat.fireSeen = true
	end
	-- Sat down after the last loading screen.
	local satHere = HasTimer(aura) and campfireLoadedAt ~= nil and aura.expirationTime - aura.duration > campfireLoadedAt
	return DistanceNearness(now, aura.auraInstanceID, satHere, false)
end

-- Welcoming Campfire is gone, but you still count as near while you stay close to your seat.
local function StayedNearness(now)
	if not campSeat then
		return nil
	end
	local nearby = C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY)
	local fireOut = campSeat.fireSeen and not IsSecretAura(nearby) and not nearby
	if fireOut or now - campSeat.satAt > CAMP_FIRE_LIFETIME or not PlayerPosition() then
		campSeat = nil
		return nil
	end
	local nearness, distance = DistanceNearness(now, campfireAuraID, false, false)
	if nearness == 0 then
		campSeat = nil -- walked away
	end
	return nearness, distance
end

-- Returns campfire nearness and details for /feels debug.
local function CampfireNearness()
	local now = GetTime()
	local timed, renewedAt, untimed, sitting
	for _, spellID in ipairs(CAMPFIRE_SPELLS) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if IsSecretAura(aura) then
			if not campfireAnchor and not campfireRenewedAt then
				return 0
			end
			local distanceNearness, distance = DistanceNearness(now, campfireAuraID, false, campfireRenewedAt ~= nil)
			local fresh, since = 1, nil
			if campfireRenewedAt then
				since = now - campfireRenewedAt
				fresh = ns.Model.CampfireNearness(since, campfireRenewalGap)
			end
			return math.min(fresh, distanceNearness), since, campfireRenewalGap, distance
		end
		if aura then
			if sittingSpells[spellID] then
				sitting = aura
			elseif HasTimer(aura) then
				local at = aura.expirationTime - aura.duration
				if not renewedAt or at > renewedAt then
					timed, renewedAt = aura, at
				end
			else
				untimed = aura
			end
		end
	end

	if sitting then
		local nearness, distance = SittingNearness(now, sitting)
		return nearness, nil, nil, distance, "sitting"
	end
	if not timed and not untimed then
		local nearness, distance = StayedNearness(now)
		if nearness then
			return nearness, nil, nil, distance, "stayed"
		end
		ForgetCampfire(now)
		return 0
	end
	-- A fire's own aura is better than an old seat.
	campSeat = nil

	-- Freshness, only for timed auras.
	local fresh, since, gap, renewed = 1, nil, nil, false
	if timed then
		since = math.max(0, now - renewedAt)
		-- Renewed before loading, nothing to measure.
		local beforeLoading = campfireLoadedAt and renewedAt <= campfireLoadedAt
		if beforeLoading then
			renewed = false
		elseif campfireRenewedAt and renewedAt > campfireRenewedAt + RENEWAL_EPSILON then
			renewed = true
			local newGap = renewedAt - campfireRenewedAt
			if campfireLastGap and math.abs(newGap - campfireLastGap) <= SAME_BEAT then
				campfireSameGaps = campfireSameGaps + 1
			else
				campfireSameGaps = 1
			end
			local beat = campfireRenewalGap
			local needed = beat and IsMultipleOf(newGap, beat) and 3 or 2
			local slowerFire = beat and newGap > beat + SAME_BEAT and campfireSameGaps >= needed
			if newGap <= MAX_RENEWAL_GAP and (not beat or newGap < beat or slowerFire) then
				campfireRenewalGap = newGap
			end
			campfireLastGap = newGap
		elseif not campfireRenewedAt and (since <= JUST_RENEWED or campfireLoadedAt) then
			renewed = true -- first renewal after a reset
		end
		gap = campfireRenewalGap
		fresh = ns.Model.CampfireNearness(since, gap)
		-- Start over only after the warmth has faded.
		if since > MAX_RENEWAL_GAP and fresh == 0 then
			ForgetBeat()
		elseif not beforeLoading then
			campfireRenewedAt = renewedAt
		end
	end

	local aura = timed or untimed
	local distanceNearness, distance = DistanceNearness(now, aura.auraInstanceID, renewed, timed ~= nil)
	return math.min(fresh, distanceNearness), since, gap, distance
end

-- Where the torch light comes from, for /feels debug.
local function TorchLight()
	for _, slot in ipairs(HAND_SLOTS) do
		if TORCH_ITEMS[GetInventoryItemID("player", slot)] then
			return "in hand"
		end
	end
	for _, spellID in ipairs(TORCH_SPELLS) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if not IsSecretAura(aura) and aura then
			return spellID == TORCH_SPELLS[1] and "in hand" or "from an ally's torch"
		end
	end
	return nil
end

-- Notes when the game renews the campfire aura.
function Sensors.OnUnitAura(updateInfo)
	if not campfireAuraID or not updateInfo or IsSecret(updateInfo) then
		return
	end
	local updated = updateInfo.updatedAuraInstanceIDs
	if not updated or IsSecret(updated) then
		return
	end
	for _, auraID in ipairs(updated) do
		if not IsSecret(auraID) and auraID == campfireAuraID then
			campfireAuraUpdatedAt = GetTime()
			return
		end
	end
end

function Sensors.OnCombatEnded()
	lastCombatEnd = GetTime()
end

-- True for fire damage to the player.
function Sensors.IsFireHit(action, amount, schoolMask)
	if IsSecret(action) or IsSecret(amount) or IsSecret(schoolMask) then
		return false
	end
	return action == "WOUND" and amount ~= nil and amount > 0 and bit.band(schoolMask or 0, FIRE_MASK) ~= 0
end

-- Checked one frame after the hit. True when it counts as fire underfoot.
function Sensors.AcceptFireHit()
	local now = GetTime()
	if InCombatLockdown() or (lastCombatEnd and now - lastCombatEnd < COMBAT_GRACE) then
		return false
	end
	lastFireHit = now
	return true
end

-- The game's lines when you get drunk or sober, sober first. Its own translations, so every language works.
local drunkLines

-- Turns a line with a drink's name into a pattern that takes any name.
local function DrinkPattern(format)
	local pattern = format:gsub("%%%d?%$?s", "\1"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", ".+")
	return "^" .. pattern .. "$"
end

local function DrunkLines()
	if not drunkLines then
		drunkLines = {}
		for level = 1, 4 do
			local plain, withDrink = _G["DRUNK_MESSAGE_SELF" .. level], _G["DRUNK_MESSAGE_ITEM_SELF" .. level]
			drunkLines[level] = {
				plain = type(plain) == "string" and plain or nil,
				pattern = type(withDrink) == "string" and DrinkPattern(withDrink) or nil,
			}
		end
	end
	return drunkLines
end

-- How drunk a system line in chat says you are: 0 sober to 3 completely smashed, nil for any other line.
function Sensors.DrunkLevel(text)
	if IsSecret(text) or type(text) ~= "string" then
		return nil
	end
	for level, line in ipairs(DrunkLines()) do
		if text == line.plain or (line.pattern and text:find(line.pattern)) then
			return level - 1
		end
	end
	return nil
end

-- After a loading screen the new place counts at once.
function Sensors.OnLoadingScreen(moved)
	shelterMemory = {}
	if not moved then
		return
	end
	LeaveFire()
	campfireLoadedAt = GetTime()
end

-- Damage classes for UnitResistance.
local FIRE_CLASS = 2
local FROST_CLASS = 4

-- Frost and fire resistance for /feels debug, to learn the values before they count. Nil without the API.
function Sensors.ReadResistances()
	if not UnitResistance then
		return nil
	end
	local function Read(class)
		local base, real, effective, bonus = UnitResistance("player", class)
		if IsSecret(base) or IsSecret(real) or IsSecret(effective) or IsSecret(bonus) then
			return nil
		end
		return { base = base, real = real, effective = effective, bonus = bonus }
	end
	return { frost = Read(FROST_CLASS), fire = Read(FIRE_CLASS) }
end

-- Shapeshift form ID, or nil in normal form.
function Sensors.ReadForm()
	local form = GetShapeshiftFormID and GetShapeshiftFormID()
	if IsSecret(form) or form == 0 then
		return nil
	end
	return form
end

function Sensors.Read()
	local state = {}
	ReadPlace(state)
	state.base = state.place.base
	state.climate = state.place.climate
	state.inside = state.place.inside == true

	local hour, minute = GetGameTime()
	state.hour = hour + minute / 60
	-- Forever's own day and night indicator, for /feels debug.
	if C_DateAndTime and C_DateAndTime.IsDayTime then
		state.gameSaysDay = C_DateAndTime.IsDayTime()
	end

	state.weather, state.weatherIntensity, state.weatherInfo = ReadWeather()
	state.weatherAvailable = C_Weather ~= nil

	-- Whole capital cities are rest areas, so resting alone is not an inn.
	local rawShelter = "outdoors"
	if IsIndoors() then
		rawShelter = IsResting() and not state.inside and "inn" or "indoors"
	end
	state.rawShelter = rawShelter
	state.shelter = ns.Model.SettleShelter(shelterMemory, rawShelter, GetTime())
	state.indoors = state.shelter ~= "outdoors"
	state.inn = state.shelter == "inn"
	state.campfire, state.campfireSince, state.campfireGap, state.campfireDistance, state.campfireCamp =
		CampfireNearness()
	state.swimming = IsSwimming()
	state.torch = TorchLight()
	-- The English race name is the same in every language. The local one is for /feels debug.
	local raceName, race = UnitRace("player")
	if IsSecret(race) then
		race = nil
	end
	state.race = race
	state.raceName = not IsSecret(raceName) and raceName or nil
	state.form = Sensors.ReadForm()
	-- Dead, before or after the release: a ghost or a wisp.
	local dead = UnitIsDeadOrGhost("player")
	state.dead = not IsSecret(dead) and dead or false
	state.burning = ns.Model.Burning(lastFireHit and GetTime() - lastFireHit, state.swimming)
	return state
end
