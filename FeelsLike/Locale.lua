-- Languages. The English text is the key, so a text with no translation stays English.
-- The game has no Ukrainian client, so the language is a setting and does not follow the game's own.

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
local current

-- Adds a language. texts maps each English text to its translation.
function Locale.Add(language, name, texts)
	tables[language] = texts
	Locale.names[language] = name
	Locale.order[#Locale.order + 1] = language
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
