-- Languages. The English text is the key, so a text with no translation stays English.
-- The language is a setting. Its default follows the game's own language when there is a translation for it.
-- The game has no Ukrainian client, so Ukrainian is always picked by hand.

local _, ns = ...

local Locale = {}
ns.Locale = Locale

Locale.DEFAULT = "en"
Locale.order = { "en" } -- as the settings list them
Locale.names = { en = "English" }
Locale.language = Locale.DEFAULT
-- Texts asked for in a language that has no translation for them, for the tests.
Locale.missing = {}

local tables = {}
local byClient = {} -- the game's language, like "deDE", to ours
local current

-- Adds a language. texts maps each English text to its translation. clients lists the game languages it is
-- the default for, like { "esES", "esMX" }.
function Locale.Add(language, name, texts, clients)
	tables[language] = texts
	Locale.names[language] = name
	Locale.order[#Locale.order + 1] = language
	for _, client in ipairs(clients or {}) do
		byClient[client] = language
	end
end

-- The language for a game client, like "de" for "deDE". English without a translation.
function Locale.ForClient(client)
	return byClient[client] or Locale.DEFAULT
end

function Locale.Has(language)
	return language == Locale.DEFAULT or tables[language] ~= nil
end

-- An unknown language is English.
function Locale.Set(language)
	current = tables[language]
	Locale.language = current and language or Locale.DEFAULT
end

-- The text in the chosen language.
function ns.T(text)
	if not current then
		return text
	end
	local translated = current[text]
	if translated == nil then
		Locale.missing[text] = true
		return text
	end
	return translated
end
