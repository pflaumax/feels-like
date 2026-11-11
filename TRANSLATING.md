# Translating Feels Like

Translations are welcome: a new language, or a better word for one line. A native speaker hears what a dictionary does not.

| Language | File | State |
| --- | --- | --- |
| English | the keys in the code | the source |
| Ukrainian | `FeelsLike/Locale/uk.lua` | by a native speaker |
| German | `FeelsLike/Locale/de.lua` | new, a native review is welcome |
| French | `FeelsLike/Locale/fr.lua` | new, a native review is welcome |
| Spanish | `FeelsLike/Locale/es.lua` | new, one text for Spain and Latin America, a native review is welcome |

Brazilian Portuguese comes next.

## How to help

- **One line sounds wrong.** Open an [issue](https://github.com/pflaumax/feels-like/issues) with the line, your version and a word on why.
- **A new language or many lines.** Copy `FeelsLike/Locale/uk.lua` or `de.lua`, translate the right side of each line and send a pull request. The left side is the English text and stays as it is.

## Rules

1. **Translate the meaning, not the words.** A line in chat should sound like something the game could say. Use the idiom of your language: German says "ein Dach über dem Kopf" for "a roof".
2. **Use the game's own words.** An inn, a campfire, Winter Veil, the minimap and the names of races and druid forms have official names in your game client. Take them from the game, or look them up on [wago.tools](https://wago.tools/db2/GlobalStrings) with your language chosen.
3. **Speak to the player as the game does.** German: Ihr and Euch. French: vous. Spanish: tú. Portuguese: você. Ukrainian: ти.
4. **No gender.** A character can be a man or a woman, and the addon uses one line for both. Do not use a form that changes with it: say "your clothes are soaked", not "you are soaked", if "soaked" would need an ending.
5. **Reasons are short names of things.** The tooltip puts them in a list: "Why: a cold place, snow, the night". Each has to read well there, with any other reason next to it.
6. **The status is one short word**, 12 letters at most: it sits next to a small gauge.
7. **Keep what a player types**: `/feels`, `/reload`, `/shiver` and the name Feels Like.
8. **End a line as the English one ends**: with a full stop, an exclamation mark or nothing. Inside the line use the punctuation of your language: French puts a space before `:`, `!` and `?` and uses « » for names.

## Check your work

```sh
luajit tests/model_test.lua
```

The tests tell you about a text with no translation, a text that is no longer used, a status word that is too long and a setting whose description uses another name than the setting itself. For a new language, add its file to `FeelsLike/FeelsLike.toc` and a line to `LANGUAGES` in `tests/model_test.lua`.
