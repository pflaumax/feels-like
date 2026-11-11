# Feels Like

**[Download FeelsLike.zip](https://github.com/pflaumax/feels-like/releases/latest/download/FeelsLike.zip)** or see [how to install](#installation).

A tiny thermometer for World of Warcraft. It sits by your minimap, and the needle shows how hot or cold your character feels right now.

I always loved the little thermometer in Breath of the Wild, and I wanted that feeling in WoW too. Freezing in Dun Morogh, warming up by a campfire, carrying a torch through a cold night. It's made for roleplay and atmosphere and never changes gameplay.

## What changes how you feel

**Zone.** Every zone has its own climate. Dun Morogh is cold, Tanaris is scorching and Elwynn is mild. In humid jungles and swamps like Stranglethorn and Un'Goro the heat feels stronger. Some places are special, like the hot springs of Winterspring, the lava of the Cauldron or Molten Core.

**Time of day.** Deserts burn in the afternoon and cool down at night. The coldest moment is just before dawn.

**Seasons.** In winter the world is a little colder and in summer a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar, and you can turn it off in the settings.

**Weather.** Rain and snow cool you down, and sandstorms heat you up.

**Shelter.** A building feels like a warm room. It's cooler than a hot day outside and warmer than a freezing night. An inn feels cozy. In the snow a cave or a cold house only keeps the wind out. Volcanic heat comes from the ground, so a roof doesn't help there.

**Campfire.** Sit by a fire to warm up and feel cozy, including the new camp fires in Forever. Once you sat down, you can get up and walk around the fire and still stay warm. A fire makes you warm but never hot.

**Torch.** Light the Night Watchman's Torch or hold a lit torch, and a cold night gets a bit warmer.

**Fire underfoot.** Step into a campfire or lava and the needle jumps to the very top of the scale. No weather takes it that far. Fire spells from enemies don't count, except for the undead (see Race). In a fight, and for a few seconds after it, the game can't tell a fire underfoot from a fire spell, so only lava in volcanic places counts then.

**Frost spells.** A frost spell that hits you chills you to the bone for a moment.

**Water.** A swim chills you. It's cold in a mild zone, freezing in the snow and just refreshing in a desert. Your clothes dry over time, and faster when it's warm. Hot springs are the exception: a swim there doesn't chill you.

**Race.** Dwarves handle the cold better. Tauren handle the cold too but feel the heat more, and trolls the other way round. The undead hardly feel either, but they fear fire: a fire spell in a fight scorches them for a moment. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren. A fire still warms every race only up to Warm, and fire underfoot burns everyone alike. You can turn this off in the settings.

**Fight.** A fight warms you up a little. The warmth builds over the first seconds and fades when the fight is over. Like a fire, it makes you warm but never hot.

**Drink.** Get tipsy and a cold night feels a little warmer. The more you drink, the warmer, but never past Mild, and the heat stays the same. The addon follows the game's own lines like "You feel tipsy. Whee!", so it works in every language.

**Death.** While you are dead, a ghost or a wisp, you feel Cold, the same everywhere, until you are back.

## Reading the gauge

Blue on the left means cold and red on the right means hot. Near the ends the ring turns icy or glows red. Hover the gauge to see its status, one word next to it like Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy, and a tooltip that says why, like "Why: a cold place, snow".

Now and then your character reacts with a short line in chat that only you see, like "A chill runs down your back." when the cold sets in, or "You warm your hands by the fire." There are lines for wet clothes, rain, snow, a torch and a drink too. The undead have their own lines, because they don't breathe or sweat, and so do bodies with fur. It never repeats itself often and stays quiet in combat.

The gauge sits by the minimap. Hold Shift and drag it to move it anywhere you like.

## Settings

Open Options, then AddOns, then Feels Like. You can

- switch between Celsius and Fahrenheit
- show the status word on hover, always or never
- turn the tooltip on hover on or off
- choose whether your race changes how you feel
- choose how the undead feel: numb or like the living
- turn seasons and holidays on or off
- turn the lines in chat on or off
- pick the language: English, Ukrainian, German, French, Spanish or Portuguese
- lock the gauge in place
- change its size
- put it back by the minimap

## Commands

| Command | What it does |
|---|---|
| `/feels` | Opens the settings |
| `/feels debug` | Shows everything that affects the current reading, and the state of the gauge frame |
| `/feels auras` | Lists your buffs, handy for finding what a fire gives you |
| `/feels test 50` | Points the needle at a value for 30 seconds, from -100 to 100 |
| `/feels test sweep` | Moves the needle across the whole scale |
| `/feels test cozy` | Shows the Cozy word for 30 seconds |
| `/feels test off` | Goes back to the real reading |
| `/feels measure FrameName` | Shows where a frame sits next to the minimap |

## Installation

1. [Download FeelsLike.zip](https://github.com/pflaumax/feels-like/releases/latest/download/FeelsLike.zip) or install it from CurseForge.
2. Unzip it into your AddOns folder, so you get `Interface/AddOns/FeelsLike/FeelsLike.toc`. On Windows "Extract All" adds one more folder around it, so move the inner `FeelsLike` folder.
3. Start the game and check that Feels Like is enabled in the AddOns list.

## FAQ

**Does it change gameplay?** No. It only shows a gauge.

**Does the cold slow me down?** No. Addons can't change your stats, your speed or your health, and Feels Like wouldn't if it could. The cold is for your roleplay.

**Does it need other addons?** No. It also works with ClassicUI Forever.

**Does it work with Titan Panel?** Yes. With Titan Panel, ChocolateBar or any other panel that shows LibDataBroker feeds, Feels Like puts its word there too. Hover it for the reasons and click it for the settings.

**Which languages?** English, Ukrainian, German, French, Spanish and Brazilian Portuguese. The addon starts in your game's language when it has a translation for it, and you can pick another one in the settings: it changes the word, the tooltip and the lines in chat at once. The settings page changes after a reload, and a window offers one right away. `/feels debug` stays English.

**Translations welcome.** Found a line that sounds wrong in your language, or want a new one? Open an issue or a pull request. [TRANSLATING.md](TRANSLATING.md) has the rules and the list of texts.

**Which versions of the game?** It's made for WoW Forever. It also loads on Retail, but there only a few old zones have a climate, so most places read as Mild.

**My undead should feel the cold.** Pick Like the living under Undead feel in the settings, and your undead feels the weather like a human. The default is Numb: dead flesh hardly feels the weather.

**A zone feels wrong.** Stand there, type `/feels debug` and send me what it prints. Ideas for what should make you colder or warmer are always welcome too.

## For addon authors

Other addons can read the reading:

```lua
local value, word, cozy = FeelsLike.GetTemperature()
```

- `value` is the felt temperature from -100 (coldest) to 100 (hottest), the addon's own scale, not degrees.
- `word` is the word for that reading: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy.
- `cozy` is true by a fire or in an inn when the reading there is Mild or Warm and not close to Cold. Cold by a fire is not Cozy, and neither is a hot inn or a swim.

It always returns the real reading, also while `/feels test` moves the gauge, and nothing before the first reading, right after login. `FeelsLike.API_VERSION` is 1 and goes up only when a change breaks callers.

## Project folders

```
FeelsLike    the addon, this is the folder that goes into Interface/AddOns
tools        scripts that build the art and the release zip
tests        tests that run outside the game
```

Not affiliated with Nintendo or Blizzard. The gauge is drawn as vector graphics, so it stays sharp at any size.

## License

MIT, see [LICENSE](LICENSE).
