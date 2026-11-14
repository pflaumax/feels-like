-- Spanish. Keys are the English texts, as the code writes them.
-- One table for Spain and Latin America. It avoids the words that differ between the two game clients,
-- like ratón and mouse.

local _, ns = ...

ns.Locale.Add("es", "Español", {
	-- The word next to the gauge.
	["Freezing"] = "Gélido",
	["Cold"] = "Frío",
	["Mild"] = "Templado",
	["Warm"] = "Cálido",
	["Hot"] = "Caluroso",
	["Scorching"] = "Abrasador",
	["Cozy"] = "Acogedor",

	-- Tooltip.
	["Why:"] = "Motivo:",
	["Shift-drag to move"] = "Mayús + arrastrar para mover",
	["A test value. /feels test off ends it."] = "Valor de prueba. /feels test off lo desactiva.",
	["Click to open the settings"] = "Haz clic para abrir la configuración",

	-- Reasons in the tooltip.
	["a cold place"] = "un lugar frío",
	["a cool place"] = "un lugar fresco",
	["a warm place"] = "un lugar cálido",
	["a hot place"] = "un lugar caluroso",
	["the night"] = "la noche",
	["the sun"] = "el sol",
	["rain"] = "la lluvia",
	["snow"] = "la nieve",
	["a sandstorm"] = "una tormenta de arena",
	["the weather"] = "el clima",
	["winter"] = "el invierno",
	["summer"] = "el verano",
	["Winter Veil"] = "el Festival de Invierno",
	["Midsummer"] = "el Solsticio de Verano",
	["the season"] = "la estación",
	["humid air"] = "el aire húmedo",
	["the inn"] = "la posada",
	["a roof"] = "un techo",
	["a campfire"] = "una fogata",
	["a torch"] = "una antorcha",
	["the water"] = "el agua",
	["wet clothes"] = "la ropa mojada",
	["your body"] = "tu cuerpo",
	["your fur"] = "tu pelaje",
	["your race"] = "tu raza",
	["dead flesh"] = "la carne muerta",
	["a drink"] = "el alcohol",
	["a fight"] = "un combate",
	["a frost spell"] = "un hechizo de escarcha",
	["fire"] = "el fuego",
	["death"] = "la muerte",

	-- Hints in chat.
	["hold Shift and drag to move the gauge."] = "mantén Mayús y arrastra para mover el termómetro.",
	["the gauge is locked. Unlock it in the settings: /feels"] =
		"el termómetro está bloqueado. Desbloquéalo en la configuración: /feels",
	["settings open after combat."] = "la configuración se abrirá después del combate.",
	["settings open after the boss fight, the Challenge Mode run or the PvP match."] =
		"la configuración se abrirá después del encuentro contra el jefe, del modo desafío o de la partida JcJ.",
	["type /reload to change the settings page too."] =
		"escribe /reload para cambiar también la página de configuración.",

	-- Settings.
	["Units"] = "Unidades",
	["Celsius"] = "Celsius",
	["Fahrenheit"] = "Fahrenheit",
	["Unit symbol inside the gauge."] = "Símbolo de la unidad dentro del termómetro.",
	["Show status"] = "Mostrar estado",
	["On hover"] = "Al pasar el cursor",
	["Always"] = "Siempre",
	["Never"] = "Nunca",
	["The status is one word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."] =
		"El estado es una palabra junto al termómetro: Gélido, Frío, Templado, Cálido, Caluroso, Abrasador o Acogedor.",
	["Tooltip on hover"] = "Descripción emergente",
	["On: hover the gauge for a tooltip with the status and why it is so. Off: no tooltip, only the status word as set above."] =
		"Activado: pasa el cursor sobre el termómetro para ver una descripción emergente con el estado y su motivo. Desactivado: sin descripción emergente, solo la palabra de estado, según el ajuste de arriba.",
	["Feel by race"] = "Sensación según la raza",
	["Your race changes how strongly you feel the cold and the heat. Dwarves handle the cold better. Tauren handle the cold but feel the heat more, and trolls the other way round. The undead feel little of either. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren. It shows in cold and hot places: a mild place feels almost the same to everyone."] =
		"Tu raza cambia la intensidad con la que sientes el frío y el calor. Los enanos aguantan mejor el frío. Los tauren aguantan el frío pero sufren más el calor, y los trols al revés. Los no-muertos apenas sienten ni lo uno ni lo otro. Los druidas en forma felina, de oso, de viaje, acuática o de lechúcico lunar tienen pelaje, como los tauren. Se nota en lugares fríos y calurosos: un lugar templado se siente casi igual para todos.",
	["Undead feel"] = "Sensación de los no-muertos",
	["Numb"] = "Insensible",
	["Like the living"] = "Como los vivos",
	["Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."] =
		"Solo para personajes no-muertos, mientras «Sensación según la raza» esté activada. Insensible: la carne muerta apenas siente el clima, pero teme al fuego, y un hechizo de fuego en combate la abrasa por un momento. Como los vivos: sienten el clima como un humano.",
	["Seasons and holidays"] = "Estaciones y fiestas",
	["On: winter (December to February) feels a little colder and summer (June to August) a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar. Off: the date changes nothing, and every day feels like spring or autumn."] =
		"Activado: el invierno (de diciembre a febrero) se siente un poco más frío y el verano (de junio a agosto) un poco más cálido, sobre todo durante el Festival de Invierno y el Solsticio de Verano. Sigue el calendario del servidor. Desactivado: la fecha no cambia nada, y cada día se siente como en primavera u otoño.",
	["Flavor lines in chat"] = "Frases de ambiente en el chat",
	["Now and then a short line in chat, only for you, when your character starts to feel the cold, the heat or Cozy."] =
		"De vez en cuando, una frase breve en el chat, solo para ti, cuando tu personaje empieza a sentir frío o calor, o a sentirse a gusto.",
	["Language"] = "Idioma",
	["The language of the status, the tooltip and the lines in chat. They change at once. This page changes after a reload of the interface, and the addon offers one."] =
		"El idioma del estado, de la descripción emergente y de las frases del chat. Cambian al instante. Esta página cambia tras recargar la interfaz, y se te ofrecerá hacerlo.",
	["Feels Like: the language changed. The status, the tooltip and the lines in chat have changed already. The settings page changes after a reload of the interface. Reload now?"] =
		"Feels Like: el idioma ha cambiado. El estado, la descripción emergente y las frases del chat ya han cambiado. La página de configuración cambiará tras recargar la interfaz. ¿Recargar ahora?",
	["Reload"] = "Recargar",
	["Later"] = "Más tarde",
	["Lock position"] = "Bloquear posición",
	["When unlocked, hold Shift and drag the gauge to move it."] =
		"Si no está bloqueado, mantén Mayús y arrastra el termómetro para moverlo.",
	["Scale"] = "Escala",
	["Position"] = "Posición",
	["Reset"] = "Restablecer",
	["Move the gauge back to its default place by the minimap."] =
		"Devuelve el termómetro a su lugar predeterminado junto al minimapa.",

	-- Lines in chat: the cold and the heat.
	["You shiver from the cold. (/shiver)"] = "Tiemblas de frío. (/shiver)",
	["Your teeth chatter. You need a fire."] = "Te castañetean los dientes. Necesitas un fuego.",
	["The cold bites through your clothes."] = "El frío te cala a través de la ropa.",
	["A chill runs down your back."] = "Un escalofrío te recorre la espalda.",
	["Your breath steams in the cold air."] = "Tu aliento humea en el aire frío.",
	["You rub your hands to keep them warm."] = "Te frotas las manos para calentarlas.",
	["Sweat runs down your face."] = "El sudor te corre por la cara.",
	["The heat makes you sluggish."] = "El calor te aletarga.",
	["You look for a bit of shade."] = "Buscas un poco de sombra.",
	["The heat is unbearable."] = "El calor es insoportable.",
	["The air burns in your lungs."] = "El aire te quema los pulmones.",
	["You feel like you are in an oven."] = "Te sientes como en un horno.",

	-- Fire and Cozy.
	["Ouch! That burns!"] = "¡Ay! ¡Eso quema!",
	["You jump out of the flames."] = "Saltas fuera de las llamas.",
	["Hot, hot, hot!"] = "¡Quema, quema, quema!",
	["You warm your hands by the fire."] = "Te calientas las manos junto al fuego.",
	["The fire's warmth seeps into your bones."] = "El calor del fuego te llega hasta los huesos.",
	["You relax by the crackling fire."] = "Te relajas junto al crepitar del fuego.",
	["The warmth of the inn wraps around you."] = "El calor de la posada te envuelve.",
	["You feel warm and cozy."] = "Sientes un calor acogedor.",
	["It is good to be inside."] = "Qué bien se está bajo techo.",

	-- Wet clothes, weather, a drink and a torch.
	["Your wet clothes cling to you."] = "La ropa mojada se te pega al cuerpo.",
	["Water drips from your clothes."] = "El agua gotea de tu ropa.",
	["You are soaked to the skin."] = "El agua te ha calado hasta los huesos.",
	["Rain runs down your neck."] = "La lluvia te corre por el cuello.",
	["The rain drums on your shoulders."] = "La lluvia tamborilea sobre tus hombros.",
	["You pull your collar up against the rain."] = "Te subes el cuello contra la lluvia.",
	["Snowflakes melt on your face."] = "Los copos de nieve se derriten en tu cara.",
	["Snow settles on your shoulders."] = "La nieve se posa sobre tus hombros.",
	["The snow crunches under your feet."] = "La nieve cruje bajo tus pies.",
	["The drink warms you from the inside."] = "El alcohol te calienta por dentro.",
	["A pleasant warmth spreads through you."] = "Un calor agradable se extiende por tu cuerpo.",
	["The cold seems a little further away."] = "El frío parece un poco más lejano.",
	["The torch warms your hand."] = "La antorcha te calienta la mano.",
	["The flame pushes the cold back a little."] = "La llama hace retroceder un poco el frío.",
	["You hold the torch a bit closer."] = "Acercas un poco más la antorcha.",

	-- The undead.
	["The frost stiffens your dead joints."] = "La helada agarrota tus articulaciones muertas.",
	["Ice creeps over your cold flesh."] = "El hielo se extiende por tu carne fría.",
	["Even the dead feel this cold."] = "Hasta los muertos sienten este frío.",
	["A chill settles in your bones."] = "El frío se instala en tus huesos.",
	["No breath steams from your lips, but the cold is there."] = "De tus labios no sale vaho, pero el frío está ahí.",
	["Your stiff fingers ache from the cold."] = "Los dedos rígidos te duelen por el frío.",
	["The heat dries your dead skin."] = "El calor reseca tu piel muerta.",
	["No sweat comes, only the heat."] = "No hay sudor, solo calor.",
	["The heat is unbearable, even for the dead."] = "El calor es insoportable, incluso para los muertos.",
	["Your dry flesh cracks in the heat."] = "Tu carne seca se agrieta con el calor.",

	-- Fur.
	["The cold gets even through your fur."] = "El frío atraviesa incluso tu pelaje.",
	["Frost gathers in your fur."] = "La escarcha se acumula en tu pelaje.",
	["You shake the ice from your coat."] = "Te sacudes el hielo del pelaje.",
	["Your fur bristles in the cold."] = "Se te eriza el pelaje con el frío.",
	["Your thick coat keeps the worst of the chill out."] = "Tu espeso pelaje te protege de lo peor del frío.",
	["A chill runs under your fur."] = "Un escalofrío te recorre bajo el pelaje.",
	["Your fur is far too warm for this."] = "Tu pelaje abriga demasiado para este calor.",
	["You pant in the heat."] = "Jadeas por el calor.",
	["Your thick fur is unbearable in this heat."] = "Tu espeso pelaje es insoportable con este calor.",
}, { "esES", "esMX" })
