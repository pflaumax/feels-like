# Feels Like - Temperature Gauge

**[⬇ Download FeelsLike.zip](https://github.com/pflaumax/feels-like/releases/latest/download/FeelsLike.zip)** (latest release) · [How to install](#installation)

A tiny temperature gauge for World of Warcraft. The needle shows how hot or cold your character feels right now, based on zone, time of day, weather and shelter.

Inspired by the temperature gauge in *The Legend of Zelda: Breath of the Wild* and *Tears of the Kingdom*. Built for roleplay and immersion — it never changes gameplay.

## What moves the needle

- **Zone.** Every zone has its own climate. Dun Morogh is cold, Tanaris is scorching, Elwynn is mild. Some places are special: the hot springs of Winterspring, the lava of the Cauldron, Molten Core.
- **Time of day.** Deserts burn in the afternoon and cool down at night. Nights are coldest before dawn: mild lands turn cool, the gloomy ones cold, snowy zones colder still.
- **Weather.** Rain and snow cool you down, sandstorms heat you up.
- **Shelter.** A building feels like a warm room: cooler than a scorching day, warmer than a freezing night. An inn is cozy.
- **Campfire.** Sit by a fire to warm up and feel cozy, Forever's new camp fires included. Once you sat down, you can stand up and stay by the fire. A fire warms you up to Warm, never to Hot.
- **Torch.** Light the Night Watchman's Torch or hold a lit torch, and a cold night gets a little warmer.
- **Fire underfoot.** Step into a campfire or lava and the needle jumps to scorching. Enemy fire spells in combat don't count.
- **Water.** A swim chills you: cold in a mild land, freezing in the snow, just refreshing in a desert. Your clothes dry over time, faster in the heat.

## Reading the gauge

Blue on the left is cold, red on the right is hot. Near the ends of the scale the ring turns icy or red-hot. Hover the gauge for one word next to it: Freezing, Cold, Mild, Warm, Hot, Scorching, or Cozy.

By default the gauge sits by the minimap. Hold Shift and drag it anywhere you like.

## Settings

Options → AddOns → Feels Like:

- **Units:** °C or °F
- **Show word:** on hover, always, or never
- **Lock position** (when unlocked, hold Shift and drag the gauge)
- **Scale**
- **Reset position** (back to the minimap)

## Commands

| Command | What it does |
|---|---|
| `/feels` or `/feelslike` | Opens the settings panel |
| `/feels debug` | Prints every factor of the current reading: client, location, time, weather (with raw `C_Weather` data), shelter, campfire, wetness, fire underfoot, result, renderer, and gauge position relative to the minimap |
| `/feels auras` | Lists your current buffs with IDs. Stand near a fire and run it to find which buff it grants |
| `/feels test <-100..100>` | Holds the needle at a value for 30 seconds |
| `/feels test sweep` | Sweeps the needle across the whole scale, then returns to the real reading |
| `/feels test cozy` | Toggles the Cozy word for 30 seconds |
| `/feels test off` | Immediately returns to the real reading |
| `/feels measure <frame>` | Shows where a frame (name from `/fstack`) sits by the minimap and which gauge scale matches its size |

## Installation

1. [Download FeelsLike.zip](https://github.com/pflaumax/feels-like/releases/latest/download/FeelsLike.zip).
2. Extract it so you end up with `.../World of Warcraft/_retail_/Interface/AddOns/FeelsLike/FeelsLike.toc` (Windows "Extract All" creates an extra wrapping folder by default — move the `FeelsLike` folder itself).
3. Launch the game. On the character select screen: AddOns → Feels Like should be enabled.

## FAQ

**Does it affect gameplay?** No. It only shows a gauge.

**Does it need other addons?** No.

**Which game versions?** WoW Forever. It also loads on Retail, but there only a few old-world zones have a climate, so most of Retail reads as Mild.

**A zone feels wrong.** Stand there, type `/feels debug`, and report the output.

## Project layout

```
FeelsLike/        the addon itself (drop this folder into Interface/AddOns)
tools/            packaging and asset-generation scripts
tests/            unit and smoke tests
```

Not affiliated with Nintendo. The gauge is drawn as vector graphics, so it stays sharp even when small.

## License

MIT — see [LICENSE](LICENSE).
