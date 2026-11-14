-- Brazilian Portuguese. Keys are the English texts, as the code writes them.

local _, ns = ...

ns.Locale.Add("pt", "Português", {
	-- The word next to the gauge.
	["Freezing"] = "Congelante",
	["Cold"] = "Frio",
	["Mild"] = "Ameno",
	["Warm"] = "Morno",
	["Hot"] = "Quente",
	["Scorching"] = "Escaldante",
	["Cozy"] = "Aconchegante",

	-- Tooltip.
	["Why:"] = "Motivo:",
	["Shift-drag to move"] = "Shift + arrastar para mover",
	["A test value. /feels test off ends it."] = "Valor de teste. /feels test off encerra o teste.",
	["Click to open the settings"] = "Clique para abrir as configurações",

	-- Reasons in the tooltip.
	["a cold place"] = "um lugar frio",
	["a cool place"] = "um lugar fresco",
	["a warm place"] = "um lugar quente",
	["a hot place"] = "um lugar muito quente",
	["the night"] = "a noite",
	["the sun"] = "o sol",
	["rain"] = "a chuva",
	["snow"] = "a neve",
	["a sandstorm"] = "uma tempestade de areia",
	["the weather"] = "o clima",
	["winter"] = "o inverno",
	["summer"] = "o verão",
	["Winter Veil"] = "o Véu de Inverno",
	["Midsummer"] = "o Solstício",
	["the season"] = "a estação",
	["humid air"] = "o ar úmido",
	["the inn"] = "a estalagem",
	["a roof"] = "um teto",
	["a campfire"] = "uma fogueira",
	["a torch"] = "uma tocha",
	["the water"] = "a água",
	["wet clothes"] = "roupas molhadas",
	["your body"] = "seu corpo",
	["your fur"] = "sua pelagem",
	["your race"] = "sua raça",
	["dead flesh"] = "a carne morta",
	["a drink"] = "o álcool",
	["a fight"] = "um combate",
	["a frost spell"] = "um feitiço de gelo",
	["fire"] = "o fogo",
	["death"] = "a morte",

	-- Hints in chat.
	["hold Shift and drag to move the gauge."] = "segure Shift e arraste para mover o termômetro.",
	["the gauge is locked. Unlock it in the settings: /feels"] =
		"o termômetro está travado. Destrave-o nas configurações: /feels",
	["settings open after combat."] = "as configurações abrirão depois do combate.",
	["settings open after the boss fight, the Challenge Mode run or the PvP match."] =
		"as configurações abrirão depois do combate contra o chefe, do Modo Desafio ou da partida JxJ.",
	["type /reload to change the settings page too."] = "digite /reload para mudar também a página de configurações.",

	-- Settings.
	["Units"] = "Unidades",
	["Celsius"] = "Celsius",
	["Fahrenheit"] = "Fahrenheit",
	["Unit symbol inside the gauge."] = "Símbolo da unidade dentro do termômetro.",
	["Show status"] = "Mostrar status",
	["On hover"] = "Ao passar o mouse",
	["Always"] = "Sempre",
	["Never"] = "Nunca",
	["The status is one word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."] =
		"O status é uma palavra ao lado do termômetro: Congelante, Frio, Ameno, Morno, Quente, Escaldante ou Aconchegante.",
	["Tooltip on hover"] = "Dica ao passar o mouse",
	["On: hover the gauge for a tooltip with the status and why it is so. Off: no tooltip, only the status word as set above."] =
		"Ativado: passe o mouse sobre o termômetro para ver uma dica com o status e o motivo. Desativado: sem dica, apenas a palavra de status, conforme definido acima.",
	["Feel by race"] = "Sensação por raça",
	["Your race changes how strongly you feel the cold and the heat. Dwarves handle the cold better. Tauren handle the cold but feel the heat more, and trolls the other way round. The undead feel little of either. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren. It shows in cold and hot places: a mild place feels almost the same to everyone."] =
		"Sua raça muda a intensidade com que você sente o frio e o calor. Os anões aguentam melhor o frio. Os taurens aguentam o frio, mas sofrem mais com o calor, e com os trolls é o contrário. Os mortos-vivos quase não sentem nenhum dos dois. Druidas na forma de felino, de urso, de viagem, aquática ou de luniscante têm pelagem, como os taurens. Isso aparece em lugares frios e quentes: um lugar ameno é quase igual para todos.",
	["Undead feel"] = "Sensação dos mortos-vivos",
	["Numb"] = "Insensível",
	["Like the living"] = "Como os vivos",
	["Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."] =
		"Apenas para personagens mortos-vivos, enquanto \"Sensação por raça\" estiver ativada. Insensível: a carne morta quase não sente o clima, mas teme o fogo, e um feitiço de fogo em combate a queima por um instante. Como os vivos: sentem o clima como um humano.",
	["Seasons and holidays"] = "Estações e festas",
	["On: winter (December to February) feels a little colder and summer (June to August) a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar. Off: the date changes nothing, and every day feels like spring or autumn."] =
		"Ativado: o inverno (de dezembro a fevereiro) fica um pouco mais frio e o verão (de junho a agosto) um pouco mais quente, principalmente durante o Véu de Inverno e o Festival do Fogo do Solstício. Segue o calendário do servidor. Desativado: a data não muda nada, e todo dia parece primavera ou outono.",
	["Flavor lines in chat"] = "Frases de ambientação no bate-papo",
	["Now and then a short line in chat, only for you, when your character starts to feel the cold, the heat or Cozy."] =
		"De vez em quando, uma frase curta no bate-papo, só para você, quando seu personagem começa a sentir frio, calor ou aconchego.",
	["Language"] = "Idioma",
	["The language of the status, the tooltip and the lines in chat. They change at once. This page changes after a reload of the interface, and the addon offers one."] =
		"O idioma do status, da dica e das frases no bate-papo. Eles mudam na hora. Esta página muda depois de recarregar a interface, e o addon oferece isso.",
	["Feels Like: the language changed. The status, the tooltip and the lines in chat have changed already. The settings page changes after a reload of the interface. Reload now?"] =
		"Feels Like: o idioma mudou. O status, a dica e as frases no bate-papo já mudaram. A página de configurações muda depois de recarregar a interface. Recarregar agora?",
	["Reload"] = "Recarregar",
	["Later"] = "Mais tarde",
	["Lock position"] = "Travar posição",
	["When unlocked, hold Shift and drag the gauge to move it."] =
		"Quando destravado, segure Shift e arraste o termômetro para movê-lo.",
	["Scale"] = "Escala",
	["Position"] = "Posição",
	["Reset"] = "Redefinir",
	["Move the gauge back to its default place by the minimap."] =
		"Devolve o termômetro ao lugar padrão, ao lado do minimapa.",

	-- Lines in chat: the cold and the heat.
	["You shiver from the cold. (/shiver)"] = "Você treme de frio. (/shiver)",
	["Your teeth chatter. You need a fire."] = "Seus dentes batem. Você precisa de uma fogueira.",
	["The cold bites through your clothes."] = "O frio atravessa suas roupas.",
	["A chill runs down your back."] = "Um arrepio percorre suas costas.",
	["Your breath steams in the cold air."] = "Seu hálito vira vapor no ar frio.",
	["You rub your hands to keep them warm."] = "Você esfrega as mãos para aquecê-las.",
	["Sweat runs down your face."] = "O suor escorre pelo seu rosto.",
	["The heat makes you sluggish."] = "O calor deixa você sem energia.",
	["You look for a bit of shade."] = "Você procura um pouco de sombra.",
	["The heat is unbearable."] = "O calor é insuportável.",
	["The air burns in your lungs."] = "O ar queima seus pulmões.",
	["You feel like you are in an oven."] = "Você se sente dentro de um forno.",

	-- Fire and Cozy.
	["Ouch! That burns!"] = "Ai! Isso queima!",
	["You jump out of the flames."] = "Você salta para fora das chamas.",
	["Hot, hot, hot!"] = "Quente, quente, quente!",
	["You warm your hands by the fire."] = "Você aquece as mãos junto ao fogo.",
	["The fire's warmth seeps into your bones."] = "O calor do fogo chega até os seus ossos.",
	["You relax by the crackling fire."] = "Você relaxa ao som do fogo crepitando.",
	["The warmth of the inn wraps around you."] = "O calor da estalagem envolve você.",
	["You feel warm and cozy."] = "Você sente um calor aconchegante.",
	["It is good to be inside."] = "Como é bom estar sob um teto.",

	-- Wet clothes, weather, a drink and a torch.
	["Your wet clothes cling to you."] = "As roupas molhadas grudam no seu corpo.",
	["Water drips from your clothes."] = "A água pinga das suas roupas.",
	["You are soaked to the skin."] = "A água encharcou você até os ossos.",
	["Rain runs down your neck."] = "A chuva escorre pelo seu pescoço.",
	["The rain drums on your shoulders."] = "A chuva tamborila nos seus ombros.",
	["You pull your collar up against the rain."] = "Você levanta a gola contra a chuva.",
	["Snowflakes melt on your face."] = "Flocos de neve derretem no seu rosto.",
	["Snow settles on your shoulders."] = "A neve se acumula nos seus ombros.",
	["The snow crunches under your feet."] = "A neve range sob os seus pés.",
	["The drink warms you from the inside."] = "O álcool aquece você por dentro.",
	["A pleasant warmth spreads through you."] = "Um calor agradável se espalha pelo seu corpo.",
	["The cold seems a little further away."] = "O frio parece um pouco mais distante.",
	["The torch warms your hand."] = "A tocha aquece a sua mão.",
	["The flame pushes the cold back a little."] = "A chama afasta um pouco o frio.",
	["You hold the torch a bit closer."] = "Você segura a tocha um pouco mais perto.",

	-- The undead.
	["The frost stiffens your dead joints."] = "A geada enrijece suas juntas mortas.",
	["Ice creeps over your cold flesh."] = "O gelo avança sobre sua carne fria.",
	["Even the dead feel this cold."] = "Até os mortos sentem este frio.",
	["A chill settles in your bones."] = "O frio se instala nos seus ossos.",
	["No breath steams from your lips, but the cold is there."] =
		"Nenhum vapor sai dos seus lábios, mas o frio está aí.",
	["Your stiff fingers ache from the cold."] = "Seus dedos rígidos doem de frio.",
	["The heat dries your dead skin."] = "O calor resseca sua pele morta.",
	["No sweat comes, only the heat."] = "Não há suor, só o calor.",
	["The heat is unbearable, even for the dead."] = "O calor é insuportável, até para os mortos.",
	["Your dry flesh cracks in the heat."] = "Sua carne seca racha com o calor.",

	-- Fur.
	["The cold gets even through your fur."] = "O frio atravessa até a sua pelagem.",
	["Frost gathers in your fur."] = "A geada se acumula na sua pelagem.",
	["You shake the ice from your coat."] = "Você sacode o gelo da pelagem.",
	["Your fur bristles in the cold."] = "Sua pelagem se arrepia com o frio.",
	["Your thick coat keeps the worst of the chill out."] = "Sua pelagem espessa protege você do pior do frio.",
	["A chill runs under your fur."] = "Um arrepio corre por baixo da sua pelagem.",
	["Your fur is far too warm for this."] = "Sua pelagem é quente demais para este calor.",
	["You pant in the heat."] = "Você ofega com o calor.",
	["Your thick fur is unbearable in this heat."] = "Sua pelagem espessa é insuportável neste calor.",
}, { "ptBR" })
