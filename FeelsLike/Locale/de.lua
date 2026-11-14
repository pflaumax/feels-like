-- German. Keys are the English texts, as the code writes them.

local _, ns = ...

ns.Locale.Add("de", "Deutsch", {
	-- The word next to the gauge.
	["Freezing"] = "Eisig",
	["Cold"] = "Kalt",
	["Mild"] = "Mild",
	["Warm"] = "Warm",
	["Hot"] = "Heiß",
	["Scorching"] = "Sengend",
	["Cozy"] = "Gemütlich",

	-- Tooltip.
	["Why:"] = "Warum:",
	["Shift-drag to move"] = "Umschalt + Ziehen zum Verschieben",
	["A test value. /feels test off ends it."] = "Ein Testwert. /feels test off beendet ihn.",
	["Click to open the settings"] = "Klicken, um die Einstellungen zu öffnen",

	-- Reasons in the tooltip.
	["a cold place"] = "ein kalter Ort",
	["a cool place"] = "ein kühler Ort",
	["a warm place"] = "ein warmer Ort",
	["a hot place"] = "ein heißer Ort",
	["the night"] = "die Nacht",
	["the sun"] = "die Sonne",
	["rain"] = "Regen",
	["snow"] = "Schnee",
	["a sandstorm"] = "ein Sandsturm",
	["the weather"] = "das Wetter",
	["winter"] = "der Winter",
	["summer"] = "der Sommer",
	["Winter Veil"] = "Winterhauch",
	["Midsummer"] = "Sonnenwendfest",
	["the season"] = "die Jahreszeit",
	["humid air"] = "feuchte Luft",
	["the inn"] = "das Gasthaus",
	["a roof"] = "ein Dach über dem Kopf",
	["a campfire"] = "ein Lagerfeuer",
	["a torch"] = "eine Fackel",
	["the water"] = "das Wasser",
	["wet clothes"] = "nasse Kleidung",
	["your body"] = "Euer Körper",
	["your fur"] = "Euer Fell",
	["your race"] = "Euer Volk",
	["dead flesh"] = "totes Fleisch",
	["a drink"] = "Alkohol",
	["a fight"] = "ein Kampf",
	["a frost spell"] = "ein Frostzauber",
	["fire"] = "Feuer",
	["death"] = "der Tod",

	-- Hints in chat.
	["hold Shift and drag to move the gauge."] =
		"haltet Umschalt gedrückt und zieht, um das Thermometer zu verschieben.",
	["the gauge is locked. Unlock it in the settings: /feels"] =
		"das Thermometer ist gesperrt. Entsperrt es in den Einstellungen: /feels",
	["settings open after combat."] = "die Einstellungen öffnen sich nach dem Kampf.",
	["settings open after the boss fight, the Challenge Mode run or the PvP match."] =
		"die Einstellungen öffnen sich nach dem Bosskampf, dem Herausforderungsmodus oder dem PvP-Kampf.",
	["type /reload to change the settings page too."] = "gebt /reload ein, um auch die Einstellungsseite umzustellen.",

	-- Settings.
	["Units"] = "Einheiten",
	["Celsius"] = "Celsius",
	["Fahrenheit"] = "Fahrenheit",
	["Unit symbol inside the gauge."] = "Einheitenzeichen im Thermometer.",
	["Show status"] = "Status anzeigen",
	["On hover"] = "Bei Mouseover",
	["Always"] = "Immer",
	["Never"] = "Nie",
	["The status is one word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."] =
		"Der Status ist ein Wort neben dem Thermometer: Eisig, Kalt, Mild, Warm, Heiß, Sengend oder Gemütlich.",
	["Tooltip on hover"] = "Tooltip bei Mouseover",
	["On: hover the gauge for a tooltip with the status and why it is so. Off: no tooltip, only the status word as set above."] =
		"An: Fahrt mit der Maus über das Thermometer, um einen Tooltip mit dem Status und dem Grund dafür zu sehen. Aus: kein Tooltip, nur das Statuswort wie oben eingestellt.",
	["Feel by race"] = "Empfinden nach Volk",
	["Your race changes how strongly you feel the cold and the heat. Dwarves handle the cold better. Tauren handle the cold but feel the heat more, and trolls the other way round. The undead feel little of either. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren. It shows in cold and hot places: a mild place feels almost the same to everyone."] =
		"Euer Volk bestimmt, wie stark Ihr Kälte und Hitze spürt. Zwerge vertragen Kälte besser. Tauren vertragen Kälte, leiden aber stärker unter Hitze, bei Trollen ist es umgekehrt. Untote spüren von beidem wenig. Druiden in Katzen-, Bären-, Reise-, Wasser- oder Mondkingestalt haben ein Fell, wie Tauren. Das zeigt sich an kalten und heißen Orten: Ein milder Ort fühlt sich für alle fast gleich an.",
	["Undead feel"] = "Empfinden der Untoten",
	["Numb"] = "Gefühllos",
	["Like the living"] = "Wie die Lebenden",
	["Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."] =
		"Nur für untote Charaktere, solange \"Empfinden nach Volk\" an ist. Gefühllos: Totes Fleisch spürt das Wetter kaum, fürchtet aber Feuer: Ein Feuerzauber im Kampf versengt es für einen Moment. Wie die Lebenden: Sie spüren das Wetter wie ein Mensch.",
	["Seasons and holidays"] = "Jahreszeiten und Feiertage",
	["On: winter (December to February) feels a little colder and summer (June to August) a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar. Off: the date changes nothing, and every day feels like spring or autumn."] =
		"An: Im Winter (Dezember bis Februar) fühlt es sich etwas kälter an und im Sommer (Juni bis August) etwas wärmer, am stärksten zum Winterhauchfest und zum Sonnenwendfest. Maßgeblich ist der Kalender des Servers. Aus: Das Datum ändert nichts, und jeder Tag fühlt sich an wie Frühling oder Herbst.",
	["Flavor lines in chat"] = "Stimmungstexte im Chat",
	["Now and then a short line in chat, only for you, when your character starts to feel the cold, the heat or Cozy."] =
		"Hin und wieder eine kurze Zeile im Chat, nur für Euch, wenn Euer Charakter Kälte, Hitze oder Gemütlichkeit zu spüren beginnt.",
	["Language"] = "Sprache",
	["The language of the status, the tooltip and the lines in chat. They change at once. This page changes after a reload of the interface, and the addon offers one."] =
		"Die Sprache des Status, des Tooltips und der Zeilen im Chat. Sie ändern sich sofort. Diese Seite ändert sich erst nach dem Neuladen der Benutzeroberfläche, und das Addon bietet es gleich an.",
	["Feels Like: the language changed. The status, the tooltip and the lines in chat have changed already. The settings page changes after a reload of the interface. Reload now?"] =
		"Feels Like: Die Sprache wurde geändert. Status, Tooltip und die Zeilen im Chat sind bereits umgestellt. Die Einstellungsseite ändert sich erst nach dem Neuladen der Benutzeroberfläche. Jetzt neu laden?",
	["Reload"] = "Neu laden",
	["Later"] = "Später",
	["Lock position"] = "Position sperren",
	["When unlocked, hold Shift and drag the gauge to move it."] =
		"Wenn nicht gesperrt: Umschalt gedrückt halten und das Thermometer ziehen, um es zu verschieben.",
	["Scale"] = "Skalierung",
	["Position"] = "Position",
	["Reset"] = "Zurücksetzen",
	["Move the gauge back to its default place by the minimap."] =
		"Setzt das Thermometer an seinen Standardplatz bei der Minikarte zurück.",

	-- Lines in chat: the cold and the heat.
	["You shiver from the cold. (/shiver)"] = "Ihr zittert vor Kälte. (/shiver)",
	["Your teeth chatter. You need a fire."] = "Eure Zähne klappern. Ihr braucht ein Feuer.",
	["The cold bites through your clothes."] = "Die beißende Kälte dringt durch Eure Kleidung.",
	["A chill runs down your back."] = "Ein kalter Schauer läuft Euch über den Rücken.",
	["Your breath steams in the cold air."] = "Euer Atem dampft in der kalten Luft.",
	["You rub your hands to keep them warm."] = "Ihr reibt Euch die Hände warm.",
	["Sweat runs down your face."] = "Schweiß läuft Euch übers Gesicht.",
	["The heat makes you sluggish."] = "Die Hitze macht Euch träge.",
	["You look for a bit of shade."] = "Ihr sucht nach etwas Schatten.",
	["The heat is unbearable."] = "Die Hitze ist unerträglich.",
	["The air burns in your lungs."] = "Die Luft brennt Euch in der Lunge.",
	["You feel like you are in an oven."] = "Ihr fühlt Euch wie in einem Backofen.",

	-- Fire and Cozy.
	["Ouch! That burns!"] = "Autsch! Das brennt!",
	["You jump out of the flames."] = "Ihr springt aus den Flammen.",
	["Hot, hot, hot!"] = "Heiß, heiß, heiß!",
	["You warm your hands by the fire."] = "Ihr wärmt Euch die Hände am Feuer.",
	["The fire's warmth seeps into your bones."] = "Die Wärme des Feuers dringt Euch bis in die Knochen.",
	["You relax by the crackling fire."] = "Ihr entspannt Euch am knisternden Feuer.",
	["The warmth of the inn wraps around you."] = "Die Wärme des Gasthauses umfängt Euch.",
	["You feel warm and cozy."] = "Euch ist wohlig warm.",
	["It is good to be inside."] = "Es tut gut, drinnen zu sein.",

	-- Wet clothes, weather, a drink and a torch.
	["Your wet clothes cling to you."] = "Die nasse Kleidung klebt Euch am Leib.",
	["Water drips from your clothes."] = "Wasser tropft von Eurer Kleidung.",
	["You are soaked to the skin."] = "Ihr seid bis auf die Haut durchnässt.",
	["Rain runs down your neck."] = "Regen läuft Euch in den Nacken.",
	["The rain drums on your shoulders."] = "Der Regen trommelt auf Eure Schultern.",
	["You pull your collar up against the rain."] = "Ihr schlagt den Kragen hoch gegen den Regen.",
	["Snowflakes melt on your face."] = "Schneeflocken schmelzen auf Eurem Gesicht.",
	["Snow settles on your shoulders."] = "Schnee legt sich auf Eure Schultern.",
	["The snow crunches under your feet."] = "Der Schnee knirscht unter Euren Füßen.",
	["The drink warms you from the inside."] = "Der Alkohol wärmt Euch von innen.",
	["A pleasant warmth spreads through you."] = "Eine wohlige Wärme breitet sich in Euch aus.",
	["The cold seems a little further away."] = "Die Kälte scheint ein wenig in die Ferne zu rücken.",
	["The torch warms your hand."] = "Die Fackel wärmt Eure Hand.",
	["The flame pushes the cold back a little."] = "Die Flamme drängt die Kälte ein wenig zurück.",
	["You hold the torch a bit closer."] = "Ihr haltet die Fackel etwas näher an Euch.",

	-- The undead.
	["The frost stiffens your dead joints."] = "Der Frost lässt Eure toten Gelenke erstarren.",
	["Ice creeps over your cold flesh."] = "Eis kriecht über Euer kaltes Fleisch.",
	["Even the dead feel this cold."] = "Diese Kälte spüren selbst die Toten.",
	["A chill settles in your bones."] = "Die Kälte setzt sich in Euren Knochen fest.",
	["No breath steams from your lips, but the cold is there."] =
		"Kein Atem dampft von Euren Lippen, doch die Kälte ist da.",
	["Your stiff fingers ache from the cold."] = "Eure steifen Finger schmerzen vor Kälte.",
	["The heat dries your dead skin."] = "Die Hitze trocknet Eure tote Haut aus.",
	["No sweat comes, only the heat."] = "Kein Schweiß, nur die Hitze.",
	["The heat is unbearable, even for the dead."] = "Die Hitze ist unerträglich, selbst für die Toten.",
	["Your dry flesh cracks in the heat."] = "Euer trockenes Fleisch reißt in der Hitze auf.",

	-- Fur.
	["The cold gets even through your fur."] = "Die Kälte dringt sogar durch Euer Fell.",
	["Frost gathers in your fur."] = "Reif sammelt sich in Eurem Fell.",
	["You shake the ice from your coat."] = "Ihr schüttelt das Eis aus dem Fell.",
	["Your fur bristles in the cold."] = "Euer Fell sträubt sich in der Kälte.",
	["Your thick coat keeps the worst of the chill out."] = "Euer dichtes Fell hält die schlimmste Kälte ab.",
	["A chill runs under your fur."] = "Ein Schauer läuft Euch unters Fell.",
	["Your fur is far too warm for this."] = "Euer Fell ist viel zu warm für diese Hitze.",
	["You pant in the heat."] = "Ihr hechelt in der Hitze.",
	["Your thick fur is unbearable in this heat."] = "Euer dichtes Fell ist in dieser Hitze unerträglich.",
}, { "deDE" })
