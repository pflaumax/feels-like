-- Ukrainian. Keys are the English texts, as the code writes them.

local _, ns = ...

ns.Locale.Add("uk", "Українська", {
	-- The word next to the gauge.
	["Freezing"] = "Морозно",
	["Cold"] = "Холодно",
	["Mild"] = "Помірно",
	["Warm"] = "Тепло",
	["Hot"] = "Спекотно",
	["Scorching"] = "Пекельно",
	["Cozy"] = "Затишно",

	-- Tooltip.
	["Colder"] = "Холодніше",
	["Warmer"] = "Тепліше",
	["Shift-drag to move"] = "Shift + перетягування, щоб пересунути",
	["A test value. /feels test off ends it."] = "Тестове значення. /feels test off вимикає його.",
	["Click to open the settings"] = "Клацни, щоб відкрити налаштування",

	-- Reasons in the tooltip.
	["a cold place"] = "холодне місце",
	["a cool place"] = "прохолодне місце",
	["a warm place"] = "тепле місце",
	["a hot place"] = "спекотне місце",
	["the night"] = "ніч",
	["the sun"] = "сонце",
	["rain"] = "дощ",
	["snow"] = "сніг",
	["a sandstorm"] = "піщана буря",
	["the weather"] = "погода",
	["winter"] = "зима",
	["summer"] = "літо",
	["Winter Veil"] = "Зимовий Покров",
	["Midsummer"] = "Літнє сонцестояння",
	["the season"] = "пора року",
	["humid air"] = "вологе повітря",
	["the inn"] = "таверна",
	["a roof"] = "дах",
	["a campfire"] = "вогнище",
	["a torch"] = "смолоскип",
	["the water"] = "вода",
	["wet clothes"] = "мокрий одяг",
	["your body"] = "твоє тіло",
	["your fur"] = "твоє хутро",
	["your race"] = "твоя раса",
	["dead flesh"] = "мертва плоть",
	["a drink"] = "випивка",
	["a frost spell"] = "крижане закляття",
	["fire"] = "вогонь",
	["death"] = "смерть",

	-- Hints in chat.
	["hold Shift and drag to move the gauge."] = "затисни Shift і тягни, щоб пересунути датчик.",
	["the gauge is locked. Unlock it in the settings: /feels"] = "датчик закріплено. Відкріпи його в налаштуваннях: /feels",
	["settings open after combat."] = "налаштування відкриються після бою.",
	["type /reload to change the settings page too."] = "введи /reload, щоб змінити й сторінку налаштувань.",

	-- Settings.
	["Units"] = "Одиниці",
	["Celsius"] = "Цельсій",
	["Fahrenheit"] = "Фаренгейт",
	["Unit symbol inside the gauge."] = "Позначка одиниць усередині датчика.",
	["Show word"] = "Показувати слово",
	["On hover"] = "При наведенні",
	["Always"] = "Завжди",
	["Never"] = "Ніколи",
	["One word next to the gauge: Freezing, Cold, Mild, Warm, Hot, Scorching or Cozy."] =
		"Одне слово біля датчика: Морозно, Холодно, Помірно, Тепло, Спекотно, Пекельно або Затишно.",
	["Feel by race"] = "Відчуття за расою",
	["Your race changes how strongly you feel the cold and the heat. Dwarves handle the cold better. Tauren handle the cold but feel the heat more, and trolls the other way round. The undead feel little of either. Druids in cat, bear, travel, aquatic or moonkin form have fur, like tauren."] =
		"Раса змінює те, наскільки сильно ти відчуваєш холод і спеку. Дворфи краще переносять холод. Таурени теж, але гірше переносять спеку, а тролі навпаки. Нежить майже не відчуває ні того, ні іншого. Друїди у формі кота, ведмедя, у подорожній, водній формі чи формі совуха мають хутро, як таурени.",
	["Undead feel"] = "Відчуття нежиті",
	["Numb"] = "Нечутлива",
	["Like the living"] = "Як живі",
	["Only for undead characters, while Feel by race is on. Numb: dead flesh hardly feels the weather, but it fears fire: a fire spell in a fight scorches it for a moment. Like the living: they feel the weather like a human."] =
		"Лише для нежиті, коли ввімкнено «Відчуття за расою». Нечутлива: мертва плоть майже не відчуває погоди, але боїться вогню: вогняне закляття в бою на мить обпікає її. Як живі: відчуває погоду як людина.",
	["Seasons and holidays"] = "Пори року і свята",
	["On: winter (December to February) feels a little colder and summer (June to August) a little warmer, most of all during Winter Veil and Midsummer. It follows the server's calendar. Off: the date changes nothing, and every day feels like spring or autumn."] =
		"Увімкнено: взимку (грудень–лютий) трохи холодніше, влітку (червень–серпень) трохи тепліше, найбільше під час Зимового Покрову та Літнього сонцестояння. За календарем сервера. Вимкнено: дата нічого не змінює, кожен день як навесні чи восени.",
	["Flavor lines in chat"] = "Репліки в чаті",
	["Now and then a short line in chat, only for you, when your character starts to feel the cold, the heat or Cozy."] =
		"Час від часу короткий рядок у чаті, лише для тебе, коли персонаж починає відчувати холод, спеку чи затишок.",
	["Language"] = "Мова",
	["The language of the word, the tooltip and the lines in chat. Type /reload to change this page too."] =
		"Мова слова, підказки й рядків у чаті. Введи /reload, щоб змінити й цю сторінку.",
	["Lock position"] = "Закріпити позицію",
	["When unlocked, hold Shift and drag the gauge to move it."] = "Коли не закріплено, затисни Shift і тягни датчик, щоб пересунути.",
	["Scale"] = "Масштаб",
	["Position"] = "Позиція",
	["Reset"] = "Скинути",
	["Move the gauge back to its default place by the minimap."] = "Повернути датчик на типове місце біля мінікарти.",

	-- Lines in chat: the cold and the heat.
	["You shiver from the cold. (/shiver)"] = "Ти тремтиш від холоду. (/shiver)",
	["Your teeth chatter. You need a fire."] = "У тебе цокотять зуби. Потрібен вогонь.",
	["The cold bites through your clothes."] = "Мороз пробирає крізь одяг.",
	["A chill runs down your back."] = "Холодок пробігає по спині.",
	["Your breath steams in the cold air."] = "Твій подих парує на холодному повітрі.",
	["You rub your hands to keep them warm."] = "Ти розтираєш руки, щоб зігрітися.",
	["Sweat runs down your face."] = "Піт стікає по обличчю.",
	["The heat makes you sluggish."] = "Спека забирає в тебе сили.",
	["You look for a bit of shade."] = "Ти шукаєш хоч трохи тіні.",
	["The heat is unbearable."] = "Спека нестерпна.",
	["The air burns in your lungs."] = "Повітря обпікає легені.",
	["You feel like you are in an oven."] = "Ти наче в печі.",

	-- Fire and Cozy.
	["Ouch! That burns!"] = "Ой! Пече!",
	["You jump out of the flames."] = "Ти вистрибуєш із полум'я.",
	["Hot, hot, hot!"] = "Гаряче, гаряче, гаряче!",
	["You warm your hands by the fire."] = "Ти грієш руки біля вогню.",
	["The fire's warmth seeps into your bones."] = "Тепло вогню проймає до кісток.",
	["You relax by the crackling fire."] = "Ти відпочиваєш під тріск вогнища.",
	["The warmth of the inn wraps around you."] = "Тепло таверни огортає тебе.",
	["You feel warm and cozy."] = "Тобі тепло й затишно.",
	["It is good to be inside."] = "Добре бути під дахом.",

	-- Wet clothes, weather, a drink and a torch.
	["Your wet clothes cling to you."] = "Мокрий одяг липне до тіла.",
	["Water drips from your clothes."] = "З одягу крапає вода.",
	["You are soaked to the skin."] = "На тобі немає сухої нитки.",
	["Rain runs down your neck."] = "Дощ стікає за комір.",
	["The rain drums on your shoulders."] = "Дощ барабанить по плечах.",
	["You pull your collar up against the rain."] = "Ти піднімаєш комір від дощу.",
	["Snowflakes melt on your face."] = "Сніжинки тануть на обличчі.",
	["Snow settles on your shoulders."] = "Сніг лягає на плечі.",
	["The snow crunches under your feet."] = "Сніг рипить під ногами.",
	["The drink warms you from the inside."] = "Випивка гріє зсередини.",
	["A pleasant warmth spreads through you."] = "Приємне тепло розливається тілом.",
	["The cold seems a little further away."] = "Холод ніби трохи відступив.",
	["The torch warms your hand."] = "Смолоскип гріє руку.",
	["The flame pushes the cold back a little."] = "Полум'я трохи відганяє холод.",
	["You hold the torch a bit closer."] = "Ти тримаєш смолоскип ближче до себе.",

	-- The undead.
	["The frost stiffens your dead joints."] = "Мороз сковує твої мертві суглоби.",
	["Ice creeps over your cold flesh."] = "Крига повзе по холодній плоті.",
	["Even the dead feel this cold."] = "Такий холод відчувають навіть мертві.",
	["A chill settles in your bones."] = "Холод оселяється в кістках.",
	["No breath steams from your lips, but the cold is there."] = "Пара не йде з твоїх вуст, та холод є.",
	["Your stiff fingers ache from the cold."] = "Задубілі пальці ниють від холоду.",
	["The heat dries your dead skin."] = "Спека сушить твою мертву шкіру.",
	["No sweat comes, only the heat."] = "Поту немає, лише спека.",
	["The heat is unbearable, even for the dead."] = "Спека нестерпна навіть для мертвих.",
	["Your dry flesh cracks in the heat."] = "Суха плоть тріскається від спеки.",

	-- Fur.
	["The cold gets even through your fur."] = "Холод пробирає навіть крізь хутро.",
	["Frost gathers in your fur."] = "Іній осідає на хутрі.",
	["You shake the ice from your coat."] = "Ти струшуєш лід із шерсті.",
	["Your fur bristles in the cold."] = "Хутро стає дибки від холоду.",
	["Your thick coat keeps the worst of the chill out."] = "Густа шерсть рятує від найгіршого холоду.",
	["A chill runs under your fur."] = "Холодок пробігає під хутром.",
	["Your fur is far too warm for this."] = "У такому хутрі тут надто жарко.",
	["You pant in the heat."] = "Ти важко дихаєш від спеки.",
	["Your thick fur is unbearable in this heat."] = "Густе хутро нестерпне в таку спеку.",
})
