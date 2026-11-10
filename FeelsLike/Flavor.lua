-- Short lines in chat, only for you, when your character starts to feel the cold, the heat or Cozy.

local _, ns = ...

local Flavor = {}
ns.Flavor = Flavor

local SETTLE = 3 -- seconds a word must hold before it speaks
local WORD_COOLDOWN = 10 * 60 -- the same lines speak at most this often
local LINE_COOLDOWN = 60 -- any line at most this often
-- After login or a /reload the game needs a moment to report where you are. A word found then is no change.
local LOGIN_QUIET = 10

-- The emote color, if the client has none.
local FALLBACK_COLOR = { r = 1, g = 0.5, b = 0.25 }

local LINES = {
	Freezing = {
		"You shiver from the cold. (/shiver)",
		"Your teeth chatter. You need a fire.",
		"The cold bites through your clothes.",
	},
	Cold = {
		"A chill runs down your back.",
		"Your breath steams in the cold air.",
		"You rub your hands to keep them warm.",
	},
	Hot = {
		"Sweat runs down your face.",
		"The heat makes you sluggish.",
		"You look for a bit of shade.",
	},
	Scorching = {
		"The heat is unbearable.",
		"The air burns in your lungs.",
		"You feel like you are in an oven.",
	},
	burning = {
		"Ouch! That burns!",
		"You jump out of the flames.",
		"Hot, hot, hot!",
	},
	cozyFire = {
		"You warm your hands by the fire.",
		"The fire's warmth seeps into your bones.",
		"You relax by the crackling fire.",
	},
	cozyInn = {
		"The warmth of the inn wraps around you.",
		"You feel warm and cozy.",
		"It is good to be inside.",
	},
	soaked = {
		"Your wet clothes cling to you.",
		"Water drips from your clothes.",
		"You are soaked to the skin.",
	},
	rain = {
		"Rain runs down your neck.",
		"The rain drums on your shoulders.",
		"You pull your collar up against the rain.",
	},
	snow = {
		"Snowflakes melt on your face.",
		"Snow settles on your shoulders.",
		"The snow crunches under your feet.",
	},
	-- Said once when it happens, not while it lasts.
	drink = {
		"The drink warms you from the inside.",
		"A pleasant warmth spreads through you.",
		"The cold seems a little further away.",
	},
	torch = {
		"The torch warms your hand.",
		"The flame pushes the cold back a little.",
		"You hold the torch a bit closer.",
	},
}
-- The undead do not breathe, sweat or shiver, so the lines for the cold and the heat are their own. The rest are shared.
local UNDEAD_LINES = {
	Freezing = {
		"The frost stiffens your dead joints.",
		"Ice creeps over your cold flesh.",
		"Even the dead feel this cold.",
	},
	Cold = {
		"A chill settles in your bones.",
		"No breath steams from your lips, but the cold is there.",
		"Your stiff fingers ache from the cold.",
	},
	Hot = {
		"The heat dries your dead skin.",
		"No sweat comes, only the heat.",
		"You look for a bit of shade.",
	},
	Scorching = {
		"The heat is unbearable, even for the dead.",
		"Your dry flesh cracks in the heat.",
		"You feel like you are in an oven.",
	},
}
-- A body with fur has its own weather lines too.
local FUR_LINES = {
	Freezing = {
		"The cold gets even through your fur.",
		"Frost gathers in your fur.",
		"You shake the ice from your coat.",
	},
	Cold = {
		"Your fur bristles in the cold.",
		"Your thick coat keeps the worst of the chill out.",
		"A chill runs under your fur.",
	},
	Hot = {
		"Your fur is far too warm for this.",
		"You pant in the heat.",
		"You look for a bit of shade.",
	},
	Scorching = {
		"Your thick fur is unbearable in this heat.",
		"The heat is unbearable.",
		"You feel like you are in an oven.",
	},
}
local KIND_LINES = { undead = UNDEAD_LINES, fur = FUR_LINES }
local NAMES = {
	burning = "Scorching from fire underfoot",
	cozyFire = "Cozy by a fire",
	cozyInn = "Cozy in an inn",
	soaked = "Soaked",
	rain = "Rain",
	snow = "Snow",
	drink = "A drink",
	torch = "A torch",
}
-- Weather that has lines of its own, when the word has none.
local WEATHER_LINES = { rain = true, snow = true }

local current, since -- the lines that fit the reading, and since when
local done -- this time has spoken, or stays quiet
local quietUntil
local spokenAt = {}
local lastKey, lastLineAt
local turn = {}

-- Which lines fit the reading, or nil. Fire and Cozy first, then soaked clothes, then the word, then the weather.
local function LinesFor(result, scene)
	local word = ns.Model.Band(result.target, result.cozy).word
	if word == "Scorching" and result.burning > 0 then
		return "burning"
	elseif word == "Cozy" then
		return result.inn and "cozyInn" or "cozyFire"
	elseif scene.soaked then
		return "soaked"
	elseif LINES[word] then
		return word
	end
	return WEATHER_LINES[scene.weather] and scene.weather or nil
end

local function Say(text)
	local color = ChatTypeInfo and ChatTypeInfo.EMOTE or FALLBACK_COLOR
	DEFAULT_CHAT_FRAME:AddMessage(text, color.r, color.g, color.b)
end

-- Says the next line of a set. kind picks the lines of a body, where it has its own.
local function Speak(key, now, kind)
	spokenAt[key], lastKey, lastLineAt = now, key, now
	local lines = KIND_LINES[kind] and KIND_LINES[kind][key] or LINES[key]
	local index = (turn[key] or 0) % #lines + 1
	turn[key] = index
	Say(ns.T(lines[index]))
end

-- Starts the quiet moment after login or a /reload.
function Flavor.OnLogin(now)
	quietUntil = now + LOGIN_QUIET
end

local NO_SCENE = {}

-- Called after every reading. held keeps the line for later (combat, a test, a ghost); off drops it.
-- scene: kind is "undead" or "fur" for a body with its own lines, soaked is true in wet clothes out of the
-- water, weather is the weather that falls on you.
function Flavor.OnReading(result, now, held, off, scene)
	scene = scene or NO_SCENE
	local key = LinesFor(result, scene)
	quietUntil = quietUntil or now + LOGIN_QUIET
	if key ~= current then
		current, since, done = key, now, false
	end
	-- What you feel at login, or while the lines are off, is no news later.
	if now < quietUntil or off then
		done = true
	end
	if not key or done or now - since < SETTLE then
		return
	end
	if spokenAt[key] and now - spokenAt[key] < WORD_COOLDOWN then
		done = true -- spoke not long ago, so this time stays quiet
		return
	end
	if held or (lastLineAt and now - lastLineAt < LINE_COOLDOWN) then
		return -- speaks later, if the word still holds
	end
	done = true
	Speak(key, now, scene.kind)
end

-- Something that happens once, like a drink or a torch you light. It speaks now or not at all.
function Flavor.OnEvent(key, now, held, off, kind)
	quietUntil = quietUntil or now + LOGIN_QUIET
	if off or held or now < quietUntil then
		return
	elseif spokenAt[key] and now - spokenAt[key] < WORD_COOLDOWN then
		return
	elseif lastLineAt and now - lastLineAt < LINE_COOLDOWN then
		return
	end
	Speak(key, now, kind)
end

-- Every line, for the language tests.
Flavor.SETS = { LINES, UNDEAD_LINES, FUR_LINES }

-- For /feels debug.
function Flavor.Describe(now, on)
	local text = on and "on" or "off"
	if lastKey then
		text = text .. string.format(", last: %s %d s ago", NAMES[lastKey] or lastKey, math.floor(now - lastLineAt))
	end
	return text
end
