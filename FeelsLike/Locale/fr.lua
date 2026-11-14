-- French. Keys are the English texts, as the code writes them.

local _, ns = ...

ns.Locale.Add("fr", "Français", {
	-- The word next to the gauge.
	["Freezing"] = "Glacial",
	["Cold"] = "Froid",
	["Mild"] = "Tempéré",
	["Warm"] = "Doux",
	["Hot"] = "Chaud",
	["Scorching"] = "Torride",
	["Cozy"] = "Au chaud",

	-- Tooltip.
	["Why:"] = "Pourquoi :",
	["Shift-drag to move"] = "Maj + glisser pour déplacer",
	["A test value. /feels test off ends it."] = "Valeur de test. /feels test off y met fin.",
	["Click to open the settings"] = "Cliquer pour ouvrir les options",

	-- Reasons in the tooltip.
	["a cold place"] = "un lieu froid",
	["a cool place"] = "un lieu frais",
	["a warm place"] = "un lieu chaud",
	["a hot place"] = "un lieu brûlant",
	["the night"] = "la nuit",
	["the sun"] = "le soleil",
	["rain"] = "la pluie",
	["snow"] = "la neige",
	["a sandstorm"] = "une tempête de sable",
	["the weather"] = "la météo",
	["winter"] = "l’hiver",
	["summer"] = "l’été",
	["Winter Veil"] = "le Voile d’hiver",
	["Midsummer"] = "le solstice d’été",
	["the season"] = "la saison",
	["humid air"] = "l’air humide",
	["the inn"] = "l’auberge",
	["a roof"] = "un toit",
	["a campfire"] = "un feu de camp",
	["a torch"] = "une torche",
	["the water"] = "l’eau",
	["wet clothes"] = "des vêtements mouillés",
	["your body"] = "votre corps",
	["your fur"] = "votre fourrure",
	["your race"] = "votre race",
	["dead flesh"] = "la chair morte",
	["a drink"] = "l’alcool",
	["a fight"] = "un combat",
	["a frost spell"] = "un sort de givre",
	["fire"] = "le feu",
	["death"] = "la mort",

	-- Hints in chat.
	["hold Shift and drag to move the gauge."] = "maintenez Maj et faites glisser le thermomètre pour le déplacer.",
	["the gauge is locked. Unlock it in the settings: /feels"] =
		"le thermomètre est verrouillé. Déverrouillez-le dans les options : /feels",
	["settings open after combat."] = "les options s’ouvriront après le combat.",
	["settings open after the boss fight, the Challenge Mode run or the PvP match."] =
		"les options s’ouvriront après le combat de boss, le mode Défi ou le match JcJ.",
	["type /reload to change the settings page too."] = "tapez /reload pour changer aussi la page des options.",

	-- Settings.
	["Units"] = "Unités",
	["Celsius"] = "Celsius",
	["Fahrenheit"] = "Fahrenheit",
	["Unit symbol inside the gauge."] = "Symbole de l’unité dans le thermomètre.",
	["Show status"] = "Afficher l’état",
	["On hover"] = "Au survol",
	["Always"] = "Toujours",
	["Never"] = "Jamais",
	["The status is one word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."] =
		"L’état est un mot affiché à côté du thermomètre : Glacial, Froid, Tempéré, Doux, Chaud, Torride ou Au chaud.",
	["Tooltip on hover"] = "Bulle d’aide au survol",
	["On: hover the gauge for a tooltip with the status and why it is so. Off: no tooltip, only the status word as set above."] =
		"Activé : survolez le thermomètre pour afficher une bulle d’aide avec l’état et sa raison. Désactivé : pas de bulle d’aide, seulement le mot d’état, selon le réglage ci-dessus.",
	["Feel by race"] = "Ressenti selon la race",
	["Your race changes how strongly you feel the cold and the heat. Dwarves handle the cold better. Tauren handle the cold but feel the heat more, and trolls the other way round. The undead feel little of either. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren. It shows in cold and hot places: a mild place feels almost the same to everyone."] =
		"Votre race détermine à quel point vous ressentez le froid et la chaleur. Les Nains supportent mieux le froid. Les Taurens supportent le froid mais souffrent davantage de la chaleur, et c’est l’inverse pour les Trolls. Les Morts-vivants ne ressentent presque ni l’un ni l’autre. Les druides en forme de félin, d’ours, de voyage, aquatique ou de sélénien ont une fourrure, comme les Taurens. Cela se remarque dans les lieux froids et chauds : un lieu tempéré paraît presque identique à tout le monde.",
	["Undead feel"] = "Ressenti des morts-vivants",
	["Numb"] = "Insensible",
	["Like the living"] = "Comme les vivants",
	["Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."] =
		"Uniquement pour les personnages morts-vivants, quand « Ressenti selon la race » est activé. Insensible : la chair morte ne ressent presque pas la météo, mais elle craint le feu, et un sort de feu en combat la brûle un instant. Comme les vivants : ils ressentent la météo comme un humain.",
	["Seasons and holidays"] = "Saisons et fêtes",
	["On: winter (December to February) feels a little colder and summer (June to August) a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar. Off: the date changes nothing, and every day feels like spring or autumn."] =
		"Activé : l’hiver (de décembre à février) paraît un peu plus froid et l’été (de juin à août) un peu plus chaud, surtout pendant le Voile d’hiver et la fête du Feu du solstice d’été. Le calendrier du serveur fait foi. Désactivé : la date ne change rien, et chaque jour ressemble au printemps ou à l’automne.",
	["Flavor lines in chat"] = "Phrases d’ambiance",
	["Now and then a short line in chat, only for you, when your character starts to feel the cold, the heat or Cozy."] =
		"De temps en temps, une courte phrase dans la fenêtre de discussion, visible de vous uniquement, quand votre personnage commence à ressentir le froid ou la chaleur, ou à se sentir bien au chaud.",
	["Language"] = "Langue",
	["The language of the status, the tooltip and the lines in chat. They change at once. This page changes after a reload of the interface, and the addon offers one."] =
		"La langue de l’état, de la bulle d’aide et des phrases d’ambiance. Le changement est immédiat. Cette page change après un rechargement de l’interface, et l’add-on vous le propose.",
	["Feels Like: the language changed. The status, the tooltip and the lines in chat have changed already. The settings page changes after a reload of the interface. Reload now?"] =
		"Feels Like : la langue a changé. L’état, la bulle d’aide et les phrases d’ambiance ont déjà changé. La page des options changera après un rechargement de l’interface. Recharger maintenant ?",
	["Reload"] = "Recharger",
	["Later"] = "Plus tard",
	["Lock position"] = "Verrouiller la position",
	["When unlocked, hold Shift and drag the gauge to move it."] =
		"Quand il est déverrouillé, maintenez Maj et faites glisser le thermomètre pour le déplacer.",
	["Scale"] = "Échelle",
	["Position"] = "Position",
	["Reset"] = "Réinitialiser",
	["Move the gauge back to its default place by the minimap."] =
		"Replace le thermomètre à son emplacement par défaut, près de la minicarte.",

	-- Lines in chat: the cold and the heat.
	["You shiver from the cold. (/shiver)"] = "Vous tremblez de froid. (/shiver)",
	["Your teeth chatter. You need a fire."] = "Vous claquez des dents. Il vous faut un feu.",
	["The cold bites through your clothes."] = "Le froid transperce vos vêtements.",
	["A chill runs down your back."] = "Un frisson vous parcourt le dos.",
	["Your breath steams in the cold air."] = "Votre souffle se change en buée dans l’air froid.",
	["You rub your hands to keep them warm."] = "Vous vous frottez les mains pour les réchauffer.",
	["Sweat runs down your face."] = "La sueur coule sur votre visage.",
	["The heat makes you sluggish."] = "La chaleur vous accable.",
	["You look for a bit of shade."] = "Vous cherchez un coin d’ombre.",
	["The heat is unbearable."] = "La chaleur est insupportable.",
	["The air burns in your lungs."] = "L’air vous brûle les poumons.",
	["You feel like you are in an oven."] = "Vous avez l’impression d’être dans un four.",

	-- Fire and Cozy.
	["Ouch! That burns!"] = "Aïe ! Ça brûle !",
	["You jump out of the flames."] = "Vous bondissez hors des flammes.",
	["Hot, hot, hot!"] = "Chaud, chaud, chaud !",
	["You warm your hands by the fire."] = "Vous vous réchauffez les mains près du feu.",
	["The fire's warmth seeps into your bones."] = "La chaleur du feu vous pénètre jusqu’aux os.",
	["You relax by the crackling fire."] = "Vous vous détendez près du feu qui crépite.",
	["The warmth of the inn wraps around you."] = "La chaleur de l’auberge vous enveloppe.",
	["You feel warm and cozy."] = "Vous êtes bien au chaud.",
	["It is good to be inside."] = "Il fait bon être à l’abri.",

	-- Wet clothes, weather, a drink and a torch.
	["Your wet clothes cling to you."] = "Vos vêtements mouillés vous collent à la peau.",
	["Water drips from your clothes."] = "L’eau dégouline de vos vêtements.",
	["You are soaked to the skin."] = "Vous n’avez plus un fil de sec.",
	["Rain runs down your neck."] = "La pluie vous coule dans le cou.",
	["The rain drums on your shoulders."] = "La pluie tambourine sur vos épaules.",
	["You pull your collar up against the rain."] = "Vous relevez votre col contre la pluie.",
	["Snowflakes melt on your face."] = "Des flocons fondent sur votre visage.",
	["Snow settles on your shoulders."] = "La neige se dépose sur vos épaules.",
	["The snow crunches under your feet."] = "La neige crisse sous vos pas.",
	["The drink warms you from the inside."] = "L’alcool vous réchauffe de l’intérieur.",
	["A pleasant warmth spreads through you."] = "Une douce chaleur se répand en vous.",
	["The cold seems a little further away."] = "Le froid semble un peu plus lointain.",
	["The torch warms your hand."] = "La torche vous réchauffe la main.",
	["The flame pushes the cold back a little."] = "La flamme repousse un peu le froid.",
	["You hold the torch a bit closer."] = "Vous tenez la torche un peu plus près de vous.",

	-- The undead.
	["The frost stiffens your dead joints."] = "Le gel raidit vos articulations mortes.",
	["Ice creeps over your cold flesh."] = "La glace gagne peu à peu votre chair froide.",
	["Even the dead feel this cold."] = "Même les morts sentent ce froid.",
	["A chill settles in your bones."] = "Le froid s’installe dans vos os.",
	["No breath steams from your lips, but the cold is there."] =
		"Aucune buée ne sort de vos lèvres, mais le froid est bien là.",
	["Your stiff fingers ache from the cold."] = "Le froid fait souffrir vos doigts raidis.",
	["The heat dries your dead skin."] = "La chaleur dessèche votre peau morte.",
	["No sweat comes, only the heat."] = "Pas de sueur, seulement la chaleur.",
	["The heat is unbearable, even for the dead."] = "La chaleur est insupportable, même pour les morts.",
	["Your dry flesh cracks in the heat."] = "Votre chair sèche se craquelle sous la chaleur.",

	-- Fur.
	["The cold gets even through your fur."] = "Le froid traverse même votre fourrure.",
	["Frost gathers in your fur."] = "Le givre s’accumule dans votre fourrure.",
	["You shake the ice from your coat."] = "Vous secouez la glace de votre pelage.",
	["Your fur bristles in the cold."] = "Votre fourrure se hérisse dans le froid.",
	["Your thick coat keeps the worst of the chill out."] = "Votre épais pelage vous protège du pire du froid.",
	["A chill runs under your fur."] = "Un frisson court sous votre fourrure.",
	["Your fur is far too warm for this."] = "Votre fourrure est bien trop chaude pour ce climat.",
	["You pant in the heat."] = "Vous haletez sous la chaleur.",
	["Your thick fur is unbearable in this heat."] = "Votre épaisse fourrure est insupportable par cette chaleur.",
}, { "frFR" })
