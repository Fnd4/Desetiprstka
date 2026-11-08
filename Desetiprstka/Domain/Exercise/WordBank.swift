import Foundation

/// Slovník slov a vět, ze kterých generátor vybírá.
/// Generátor si sám vyfiltruje jen to, co jde napsat známými klávesami,
/// takže sem stačí přidávat další slova – nic dalšího se měnit nemusí.
struct WordBank: Sendable {
    let words: [String]
    let sentences: [String]

    init(words: [String], sentences: [String]) {
        // Normalizace, deduplikace, jen malá písmena ve slovech.
        var seen = Set<String>()
        self.words = words
            .map { $0.precomposedStringWithCanonicalMapping.lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        self.sentences = sentences.map { $0.precomposedStringWithCanonicalMapping }
    }

    /// Slovník pro jazyk cvičení z Nastavení.
    static var current: WordBank { PracticeLanguage.current.wordBank }

    static let english = WordBank(words: EnglishWords.words, sentences: EnglishWords.sentences)

    static let czech = WordBank(
        words: CzechWords.all + CzechWordsExtended.words,
        sentences: CzechWords.sentences + CzechWordsExtended.sentences
    )
}

private enum CzechWords {
    static let all: [String] = homeRow + basic + common + longer + rareLetters

    /// Slova jen ze základní řady (a s d f g h j k l).
    static let homeRow: [String] = [
        "sad", "had", "dal", "dala", "jas", "jak", "kal", "lak", "hala", "hlad",
        "hlas", "klas", "slad", "sklad", "lhal", "lhala", "sahal", "sahala", "dlaha",
        "halda", "salsa", "gala", "dlask", "skalka", "lada", "kladka",
    ]

    /// Krátká slova bez diakritiky.
    static let basic: [String] = [
        "ale", "ano", "asi", "do", "na", "ne", "se", "si", "on", "ona", "oni", "ono",
        "od", "po", "za", "ve", "ke", "ze", "by", "my", "vy", "ty", "to", "tak", "tam",
        "ten", "kde", "kdo", "co", "jen", "jet", "jde", "den", "dno", "les", "led", "let",
        "lev", "nos", "noc", "nic", "oko", "pes", "pak", "pan", "pod", "pro", "rok", "ret",
        "sen", "sto", "syn", "kus", "kov", "krb", "moc", "med", "mez", "obr", "osa", "dub",
        "buk", "byt", "bod", "bez", "dar", "dort", "hora", "hrad", "hrob", "jaro", "jedu",
        "kafe", "kolo", "kost", "list", "lano", "seno", "noha", "kino", "film", "golf",
        "olej", "dole", "voda", "vlak", "vlna", "ruka", "ruce", "nula", "jako", "jeho",
        "jedna", "jedno", "jeden", "nikde", "nikdo", "kolik", "holka", "deska", "lidi",
        "hodil", "hodila", "nesla", "nesli", "jedla", "sedla", "salon", "slon", "sloni",
        "fialka", "kolega", "koleno", "kolena", "hodina", "hodiny", "dalekohled",
        "strom", "okno", "sport", "tenis", "orel", "kotel", "kotva", "vlasy", "nebe",
        "obraz", "domov", "dobro", "kniha", "kocour", "kostel", "kopec", "kolem",
        "maminka", "mapa", "most", "motor", "noviny", "obloha", "oblek", "okurka",
        "opice", "osel", "park", "pero", "pilot", "planeta", "pohoda", "pokoj", "pole",
        "policie", "posel", "potok", "prase", "pravda", "pravidlo", "program", "projekt",
        "radost", "rodina", "rostlina", "sebe", "sestra", "sever", "silnice", "sklep",
        "slovo", "slova", "slunce", "sova", "spolu", "stan", "stanice", "student",
        "stolek", "strana", "stroj", "sedadlo", "tabule", "tanec", "teplo", "toto",
        "tramvaj", "tento", "tato", "trubka", "ulice", "vodopad", "volno", "vrabec",
        "vrba", "veverka", "venku", "vesnice", "vedro", "zebra", "zelenina", "zima",
        "zvonek", "bota", "boty", "brambora", "buben", "budova", "bunda", "cesta",
        "citron", "cukr", "drak", "datum", "fotka", "fotbal", "hokej", "holub", "hrnek",
        "jablko", "jahoda", "kabel", "kabelka", "kakao", "kapsa", "kapr", "karta",
        "koberec", "koruna", "lampa", "lavice", "lekce", "lopata", "meloun", "menu",
        "metro", "mrak", "mrkev", "obchod", "oblak", "obrana", "ocel", "odpoledne",
        "okolo", "opera", "osoba", "ovoce", "palec", "pivo", "plot", "postel", "prach",
        "prst", "rameno", "robot", "sako", "sedlo", "skupina", "smetana", "sobota",
        "sopka", "srdce", "stopa", "tabulka", "talent", "telefon", "tunel", "tygr",
        "ucho", "uzel", "vata", "volant", "vozidlo", "auto", "autobus", "banka", "bratr",
        "cena", "cibule", "dcera", "dopis", "doktor", "domek", "dvorek", "fronta",
        "hudba", "jazyk", "jelen", "klobouk", "koupelna", "lednice", "letadlo", "mlha",
        "mostek", "nebo", "nora", "oblouk", "perla", "pomoc", "potraviny", "provaz",
        "sklenice", "slepice", "smrk", "sousedka", "srna", "stolice",
    ]

    /// Běžná slova s diakritikou.
    static let common: [String] = [
        "až", "být", "čas", "dál", "dva", "dvě", "dům", "hra", "hry", "já", "jí", "jít",
        "keř", "loď", "mít", "mé", "mír", "mám", "pít", "pták", "rád", "řeka", "sůl",
        "sýr", "už", "vůz", "zde", "zem", "žák", "žena", "čaj", "dech", "duch", "chce",
        "chuť", "kůň", "lípa", "louka", "malý", "máma", "maso", "mléko", "myš", "oběd",
        "otec", "pán", "rýže", "sál", "sklo", "soud", "stůl", "sval", "táta", "tráva",
        "věk", "víno", "vítr", "vlk", "vous", "zlato", "zub", "žába", "žlutý", "hodně",
        "chléb", "kočka", "koza", "kráva", "liška", "pátek", "úterý", "čtvrtek",
        "středa", "neděle", "pondělí", "škola", "šaty", "čepice", "dítě", "děti",
        "hřiště", "jídlo", "knížka", "lžíce", "mráz", "nůž", "okýnko", "pohár", "řidič",
        "sníh", "světlo", "šála", "třída", "učitel", "vánoce", "zámek", "žirafa",
        "dárek", "hvězda", "hruška", "měsíc", "slunko", "život", "práce", "přítel",
        "kamarádka", "babička", "dědeček", "maminka", "tatínek", "sestřička", "bráška",
    ]

    /// Delší slova (5+ znaků).
    static let longer: [String] = [
        "kancelář", "klávesnice", "knihovna", "kuchyně", "nádraží", "náměstí",
        "počítač", "pohádka", "polévka", "procházka", "rychlost", "sešit", "trenér",
        "večer", "zahrada", "zmrzlina", "zpráva", "zvíře", "cvičení", "čokoláda",
        "dovolená", "chodník", "jídelna", "kalendář", "kaštan", "klavír", "květina",
        "lékař", "lavička", "město", "minuta", "motýl", "náhoda", "nemocnice",
        "oblečení", "okamžik", "papír", "písnička", "pohled", "poklad", "příroda",
        "rádio", "restaurace", "rohlík", "sladkost", "sušenka", "televize", "tužka",
        "velryba", "vlajka", "výlet", "zrcadlo", "želva", "dopravník", "houpačka",
        "jednička", "klíček", "kytara", "medvěd", "meruňka", "mobilní", "obrázek",
        "ostrov", "pavouk", "pěkný", "pomeranč", "poštovní", "prázdniny", "přesnost",
        "psaní", "rozvrh", "rybník", "schody", "skříň", "sluníčko", "stavebnice",
        "šikovný", "tanečník", "tlačítko", "trpělivost", "úsměv", "vzduch", "zkouška",
        "znamení", "zvonkohra", "hodinky", "brambory", "budoucnost", "dobrodružství",
        "jablečný", "kreslení", "malování", "nakupování", "odpočinek", "pomalu",
        "rychle", "správně", "trénink", "výsledek", "zlepšení", "pokrok", "cíl",
    ]

    /// Slova procvičující méně častá písmena (w, q, x, y, z).
    static let rareLetters: [String] = [
        "taxi", "text", "fax", "box", "mix", "fixa", "xylofon", "luxus", "export",
        "index", "web", "watt", "whisky", "western", "squash", "aquapark", "byl",
        "byla", "bylo", "byli", "pyl", "rys", "zvyk", "hymna", "symbol", "systém",
        "rytmus", "zoo", "zvon", "zkus", "zvuk", "zubař", "kyslík", "slyšet",
    ]

    // MARK: - Věty

    /// Věty začínají písmenem bez diakritiky, aby šly napsat se Shiftem.
    static let sentences: [String] = [
        "Dana jela do lesa.",
        "Na stole je olej.",
        "Ondra nese kolo.",
        "Lenka sedla na kolo.",
        "Sedla si do sedla.",
        "Ondra jel na kole do lesa.",
        "Strom roste u domu.",
        "Petr nese stolek.",
        "Lenka a Petr jdou do parku.",
        "Ten den bylo teplo.",
        "Na podlaze je koberec.",
        "Opice sedla na strom.",
        "Vlak jede pomalu.",
        "Vedle domu je park.",
        "Doma je teplo.",
        "Sova sedla na strom.",
        "Rodina jede do Prahy.",
        "Mapa je na stole.",
        "Dnes je krásný den.",
        "Máma vaří polévku.",
        "Pes běží po louce.",
        "Kočka spí na gauči.",
        "Na stole leží kniha.",
        "Vlak jede do Prahy.",
        "Ráno piju kávu s mlékem.",
        "V lese rostou houby.",
        "Děti si hrají na zahradě.",
        "Učitel píše na tabuli.",
        "Slunce svítí a ptáci zpívají.",
        "Babička peče jablečný koláč.",
        "Tramvaj zastavila u nádraží.",
        "Rád čtu knihy o vesmíru.",
        "Venku prší, vezmi si deštník.",
        "Psaní všemi deseti je užitečná dovednost.",
        "Každý den trénuji psaní na klávesnici.",
        "Na horách leží sníh.",
        "Lidé čekají na autobus.",
        "Ve městě je hodně aut.",
        "Pavel hraje fotbal se sestrou.",
        "Jana má ráda zmrzlinu.",
        "Odpoledne půjdeme do parku.",
        "Kolo stojí před domem.",
        "Mám rád dlouhé procházky.",
        "Večer se díváme na film.",
        "Strom má zelené listy.",
        "Na obloze je jen pár mraků.",
        "Jablka jsou sladká a šťavnatá.",
        "Dědeček sedí na lavičce.",
        "Moje sestra studuje medicínu.",
        "Kluci staví bunkr v lese.",
        "Pomalu a přesně je lepší než rychle a s chybami.",
        "Prsty drž na základní řadě.",
        "Klávesnice je tvůj nástroj.",
        "Zítra pojedeme k moři.",
        "Lev je král zvířat.",
        "Hodiny ukazují přesný čas.",
        "Ryba plave v řece.",
        "Sova v noci loví myši.",
        "Tento týden máme hodně práce.",
        "Kamarád mi poslal dopis.",
        "V kuchyni voní čerstvý chléb.",
        "Malý kluk si staví hrad z písku.",
        "Na podzim padá listí.",
        "V zimě jezdíme na lyže.",
        "Léto je nejteplejší období roku.",
        "Jaro přináší nové květiny.",
        "Auto zastavilo na křižovatce.",
        "Holka nese košík jahod.",
        "Vlak má zpoždění deset minut.",
        "Dobrá nálada je důležitá.",
        "Sklenice je plná vody.",
        "Telefon zvoní už podruhé.",
        "Na koncertě hrála skvělá kapela.",
        "Kdo si hraje, nezlobí.",
        "Bez práce nejsou koláče.",
        "Ranní ptáče dál doskáče.",
        "Kdo jinému jámu kopá, sám do ní padá.",
        "Mluviti stříbro, mlčeti zlato.",
        "Lepší vrabec v hrsti než holub na střeše.",
        "Tichá voda břehy mele.",
        "Jablko nepadá daleko od stromu.",
        "Všude dobře, doma nejlépe.",
        "Hlad je nejlepší kuchař.",
        "Komu se nelení, tomu se zelení.",
        "Opakování je matka moudrosti.",
        "Praha je hlavní město České republiky.",
        "Dvanáct měsíců má jeden rok.",
        "Taxi čeká před hotelem.",
        "Xylofon zní jako zvonky.",
        "Web má novou stránku s kvízem.",
        "Kapr plave v rybníku pod mostem.",
        "Petr a Pavel jdou na hokej.",
        "Mladší bratr se učí psát všemi deseti.",
        "Klid a soustředění jsou základ úspěchu.",
        "Oči sleduj obrazovku, ne klávesnici.",
        "Ukazováčky drž na klávesách F a J.",
    ]
}
