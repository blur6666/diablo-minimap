extends RefCounted

## Every user-visible string in the mod, in the 13 languages the game ships.
##
## Registered at runtime from this Dictionary - no CSV, no .translation import
## step. Control auto-translation resolves the keys on Labels and Buttons, and
## menu_tooltip.gd runs its text through tr() explicitly, so tooltips take keys
## too. Both re-resolve when the player changes language, so the options rows
## follow the language dropdown live.
##
## Locale list mirrors options_menu.gd's `languages`. Anything outside it falls
## back to Godot's default "en" - the project sets no locale/fallback override.
##
## Keys are prefixed with the mod id to keep them out of the vanilla namespace.
##
## Caveat worth keeping in mind: only "en" and "pt_BR" have been eyeballed by a
## speaker. The rest are machine-quality and fine to correct in place - each is
## one line, and nothing else has to change.
##
## Tooltip strings must not contain braces: menu_tooltip.gd calls
## .format(G.format_dict) on the translated result.

const KEY_MAP_SIZE := "BLUR6_DIABLO_MINIMAP_SIZE"
const KEY_MAP_OPACITY := "BLUR6_DIABLO_MINIMAP_OPACITY"
const KEY_DIABLO := "BLUR6_DIABLO_MINIMAP_DIABLO"
const KEY_DIABLO_TIP := "BLUR6_DIABLO_MINIMAP_DIABLO_TIP"
const KEY_OUTLINE := "BLUR6_DIABLO_MINIMAP_OUTLINE"
const KEY_OUTLINE_TIP := "BLUR6_DIABLO_MINIMAP_OUTLINE_TIP"
const KEY_RESET := "BLUR6_DIABLO_MINIMAP_RESET"

const STRINGS := {
	KEY_MAP_SIZE: {
		"en": "Map Size",
		"zh_CN": "地图大小",
		"ru": "Размер карты",
		"ko": "지도 크기",
		"ja": "マップサイズ",
		"de": "Kartengröße",
		"es": "Tamaño del mapa",
		"pt_BR": "Tamanho do mapa",
		"fr": "Taille de la carte",
		"it": "Dimensione mappa",
		"cs": "Velikost mapy",
		"fi": "Kartan koko",
		"tr": "Harita Boyutu",
	},
	KEY_MAP_OPACITY: {
		"en": "Map Opacity",
		"zh_CN": "地图不透明度",
		"ru": "Непрозрачность карты",
		"ko": "지도 불투명도",
		"ja": "マップの不透明度",
		"de": "Kartendeckkraft",
		"es": "Opacidad del mapa",
		"pt_BR": "Opacidade do mapa",
		"fr": "Opacité de la carte",
		"it": "Opacità mappa",
		"cs": "Krytí mapy",
		"fi": "Kartan peittävyys",
		"tr": "Harita Opaklığı",
	},
	KEY_DIABLO: {
		"en": "Diablo Style Map",
		"zh_CN": "暗黑破坏神风格地图",
		"ru": "Карта в стиле Diablo",
		"ko": "디아블로 스타일 지도",
		"ja": "ディアブロ風マップ",
		"de": "Karte im Diablo-Stil",
		"es": "Mapa estilo Diablo",
		"pt_BR": "Mapa estilo Diablo",
		"fr": "Carte façon Diablo",
		"it": "Mappa in stile Diablo",
		"cs": "Mapa ve stylu Diabla",
		"fi": "Diablo-tyylinen kartta",
		"tr": "Diablo Tarzı Harita",
	},
	KEY_DIABLO_TIP: {
		"en": "Moves the map to the centre of the screen as a translucent overlay and pins it on the player, Diablo-style. Opacity still applies.",
		"zh_CN": "将地图移到屏幕中央，作为半透明覆盖层并锁定在玩家身上，暗黑破坏神风格。不透明度设置仍然有效。",
		"ru": "Перемещает карту в центр экрана как полупрозрачный слой и закрепляет её на игроке, как в Diablo. Настройка непрозрачности продолжает действовать.",
		"ko": "지도를 화면 중앙에 반투명 오버레이로 옮기고 플레이어에 고정합니다. 디아블로 방식입니다. 불투명도 설정은 그대로 적용됩니다.",
		"ja": "マップを画面中央に半透明のオーバーレイとして表示し、プレイヤーに固定します（ディアブロ風）。不透明度の設定はそのまま適用されます。",
		"de": "Verschiebt die Karte als durchscheinende Überlagerung in die Bildschirmmitte und heftet sie an den Spieler, wie in Diablo. Die Deckkraft gilt weiterhin.",
		"es": "Mueve el mapa al centro de la pantalla como una capa translúcida y lo fija en el jugador, al estilo Diablo. La opacidad se sigue aplicando.",
		"pt_BR": "Move o mapa para o centro da tela como uma camada translúcida e o fixa no jogador, no estilo Diablo. A opacidade continua valendo.",
		"fr": "Déplace la carte au centre de l'écran sous forme de calque translucide et la fixe sur le joueur, façon Diablo. L'opacité reste appliquée.",
		"it": "Sposta la mappa al centro dello schermo come sovrapposizione traslucida e la fissa sul giocatore, in stile Diablo. L'opacità resta valida.",
		"cs": "Přesune mapu doprostřed obrazovky jako průsvitnou vrstvu a ukotví ji na hráče, ve stylu Diabla. Nastavení krytí platí i nadále.",
		"fi": "Siirtää kartan näytön keskelle läpikuultavana kerroksena ja kiinnittää sen pelaajaan, Diablon tapaan. Peittävyysasetus on yhä voimassa.",
		"tr": "Haritayı yarı saydam bir katman olarak ekranın ortasına taşır ve oyuncuya sabitler, Diablo tarzında. Opaklık ayarı geçerli olmaya devam eder.",
	},
	KEY_OUTLINE: {
		"en": "Highlight Map Walls",
		"zh_CN": "高亮地图墙壁",
		"ru": "Подсветка стен на карте",
		"ko": "지도 벽 강조",
		"ja": "マップの壁を強調",
		"de": "Kartenwände hervorheben",
		"es": "Resaltar paredes del mapa",
		"pt_BR": "Destacar paredes do mapa",
		"fr": "Surligner les murs de la carte",
		"it": "Evidenzia i muri sulla mappa",
		"cs": "Zvýraznit stěny na mapě",
		"fi": "Korosta kartan seinät",
		"tr": "Harita Duvarlarını Vurgula",
	},
	KEY_OUTLINE_TIP: {
		"en": "Traces every room and corridor on the map with a bright edge, so the layout reads as walls instead of flat shapes. Map only - the world is untouched.",
		"zh_CN": "用明亮的边缘描出地图上的每个房间和走廊，让布局看起来像墙壁而不是平面色块。仅影响地图，游戏世界不受影响。",
		"ru": "Обводит каждую комнату и коридор на карте яркой линией, чтобы планировка читалась как стены, а не как плоские пятна. Только карта — сам мир не затрагивается.",
		"ko": "지도의 모든 방과 통로에 밝은 테두리를 그려, 배치가 평면 도형이 아닌 벽으로 보이게 합니다. 지도에만 적용되며 게임 월드는 그대로입니다.",
		"ja": "マップ上のすべての部屋と通路を明るい輪郭で縁取り、平面的な図形ではなく壁として見えるようにします。マップのみに適用され、ゲーム世界は変わりません。",
		"de": "Zeichnet jeden Raum und Gang auf der Karte mit einer hellen Kante nach, damit das Layout wie Wände statt wie flache Formen wirkt. Nur die Karte – die Welt bleibt unverändert.",
		"es": "Traza cada sala y pasillo del mapa con un borde brillante, para que el trazado se lea como paredes en lugar de formas planas. Solo el mapa: el mundo no se altera.",
		"pt_BR": "Contorna cada sala e corredor do mapa com uma borda clara, para que o traçado pareça paredes em vez de formas chapadas. Só o mapa — o mundo não é alterado.",
		"fr": "Trace chaque salle et couloir de la carte avec un bord lumineux, pour que le plan se lise comme des murs plutôt que des formes plates. Carte uniquement : le monde reste inchangé.",
		"it": "Traccia ogni stanza e corridoio sulla mappa con un bordo luminoso, così la planimetria si legge come muri invece che come forme piatte. Solo la mappa: il mondo resta invariato.",
		"cs": "Obkreslí každou místnost a chodbu na mapě jasnou linkou, aby půdorys působil jako stěny, ne jako ploché tvary. Týká se jen mapy – svět zůstává beze změny.",
		"fi": "Piirtää kartan jokaisen huoneen ja käytävän reunat kirkkaalla viivalla, jolloin pohjapiirros näyttää seiniltä eikä litteiltä muodoilta. Vain kartta – itse maailma ei muutu.",
		"tr": "Haritadaki her odayı ve koridoru parlak bir kenarla çizer, böylece yerleşim düz şekiller yerine duvarlar gibi görünür. Yalnızca harita — dünya değişmez.",
	},
	KEY_RESET: {
		"en": "Reset Map Options",
		"zh_CN": "重置地图选项",
		"ru": "Сбросить настройки карты",
		"ko": "지도 옵션 초기화",
		"ja": "マップ設定をリセット",
		"de": "Kartenoptionen zurücksetzen",
		"es": "Restablecer opciones del mapa",
		"pt_BR": "Redefinir opções do mapa",
		"fr": "Réinitialiser les options de la carte",
		"it": "Reimposta opzioni mappa",
		"cs": "Obnovit nastavení mapy",
		"fi": "Palauta kartan asetukset",
		"tr": "Harita Seçeneklerini Sıfırla",
	},
}

static var _registered := false


## Call from mod_main._init(), i.e. long before any menu is built. One
## Translation per locale carrying every key, rather than one per key/locale
## pair, so TranslationServer ends up with 13 objects instead of 91.
static func register() -> void:
	if _registered:
		return
	_registered = true
	var by_locale := {}
	for key in STRINGS:
		for locale in STRINGS[key]:
			if not by_locale.has(locale):
				var t := Translation.new()
				t.locale = locale
				by_locale[locale] = t
			by_locale[locale].add_message(key, STRINGS[key][locale])
	for locale in by_locale:
		TranslationServer.add_translation(by_locale[locale])
