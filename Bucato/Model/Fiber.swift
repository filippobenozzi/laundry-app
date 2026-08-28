import Foundation

/// What a fibre is made of. Drives both the one-line explanation shown in the
/// result and the tone of the advice: an animal fibre is felted by heat and
/// agitation, a synthetic one melts, a cellulosic one loses its body when wet.
enum FiberFamily: String, Codable, CaseIterable, Sendable {
    case vegetale       // cotton, linen, hemp — cellulose grown in a field
    case animale        // wool, silk, cashmere — protein
    case artificiale    // viscose, modal, lyocell — cellulose dissolved and spun
    case sintetica      // polyester, nylon, elastane — made from polymers
    case altro          // leather, down, metallic threads

    var label: String {
        switch self {
        case .vegetale: return "Fibra vegetale"
        case .animale: return "Fibra animale"
        case .artificiale: return "Fibra artificiale"
        case .sintetica: return "Fibra sintetica"
        case .altro: return "Materiale"
        }
    }
}

/// How aggressively a machine may treat the fibre. The advice engine takes the
/// strictest value across everything the label declares.
enum SpinLevel: Int, Codable, Comparable, Sendable {
    case none = 0       // do not spin at all
    case low = 1        // ~400 rpm
    case medium = 2     // ~800 rpm
    case full = 3       // whatever the machine does

    static func < (a: SpinLevel, b: SpinLevel) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .none: return "senza centrifuga"
        case .low: return "centrifuga bassa, max 400 giri"
        case .medium: return "centrifuga media, max 800 giri"
        case .full: return "centrifuga libera"
        }
    }
}

enum TumbleLevel: Int, Codable, Comparable, Sendable {
    case forbidden = 0
    case low = 1
    case normal = 2

    static func < (a: TumbleLevel, b: TumbleLevel) -> Bool { a.rawValue < b.rawValue }
}

enum DetergentKind: Int, Codable, Comparable, Sendable {
    case standard = 0
    case delicati = 1
    case lana = 2       // enzyme-free: enzymes eat protein fibres

    static func < (a: DetergentKind, b: DetergentKind) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .standard: return "detersivo normale"
        case .delicati: return "detersivo per delicati"
        case .lana: return "detersivo per lana o seta, senza enzimi"
        }
    }
}

/// The care envelope of a single fibre, before the label's own symbols are applied.
struct FiberCare: Sendable {
    var maxWashC: Int
    var handWashOnly: Bool = false
    var spin: SpinLevel = .full
    var tumble: TumbleLevel = .normal
    /// Iron temperature in dots, the same scale the symbol uses. 0 means never.
    var ironDots: Int = 3
    var bleachable: Bool = false
    var dryCleanFriendly: Bool = true
    var detergent: DetergentKind = .standard
    /// Short, specific things that go wrong with this fibre.
    var warnings: [String] = []
}

struct Fiber: Identifiable, Sendable {
    let id: String
    let name: String
    let family: FiberFamily
    /// Lowercase, accent-free spellings seen on labels, in several languages.
    let aliases: [String]
    /// One sentence: what it is. Deliberately short — the app explains, it doesn't lecture.
    let summary: String
    let care: FiberCare
}

enum FiberCatalog {

    static let all: [Fiber] = [

        // MARK: Vegetali

        Fiber(id: "cotone", name: "Cotone", family: .vegetale,
              aliases: ["cotone", "cotton", "coton", "baumwolle", "algodon", "algodao", "katoen",
                        "bomull", "pamuk", "co", "cotone organico", "organic cotton", "cotone biologico"],
              summary: "Fibra naturale dal batuffolo della pianta di cotone: assorbe molta acqua, resiste al caldo e si lava facilmente.",
              care: FiberCare(maxWashC: 60, spin: .full, tumble: .normal, ironDots: 3,
                              bleachable: true, detergent: .standard,
                              warnings: ["Se non è prelavato può restringere al primo lavaggio caldo.",
                                         "I colori scuri stingono: primi lavaggi da soli."])),

        Fiber(id: "lino", name: "Lino", family: .vegetale,
              aliases: ["lino", "linen", "lin", "leinen", "linnen", "li"],
              summary: "Fibra dal fusto della pianta di lino: fresca e resistente, ma si sgualcisce per natura.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .low, ironDots: 3,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Stiralo umido: da asciutto le pieghe non vengono via.",
                                         "L'asciugatrice lo indurisce e lo fa restringere."])),

        Fiber(id: "canapa", name: "Canapa", family: .vegetale,
              aliases: ["canapa", "hemp", "chanvre", "hanf", "canamo"],
              summary: "Fibra del fusto della canapa: molto resistente, si ammorbidisce a ogni lavaggio.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .low, ironDots: 3,
                              bleachable: false, detergent: .standard,
                              warnings: ["Evita l'ammorbidente: chiude la fibra e toglie traspirabilità."])),

        Fiber(id: "ramie", name: "Ramié", family: .vegetale,
              aliases: ["ramie", "rami", "ramia"],
              summary: "Fibra vegetale lucida e rigida, spesso mescolata al cotone per dare corpo.",
              care: FiberCare(maxWashC: 40, spin: .low, tumble: .forbidden, ironDots: 2,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Fragile allo sfregamento: lavalo rovesciato."])),

        Fiber(id: "iuta", name: "Iuta", family: .vegetale,
              aliases: ["iuta", "juta", "jute"],
              summary: "Fibra grezza e rustica, usata per borse e dettagli: teme l'acqua.",
              care: FiberCare(maxWashC: 0, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 1, bleachable: false, detergent: .delicati,
                              warnings: ["Meglio solo una spazzolata: in acqua perde forma e colore."])),

        // MARK: Animali

        Fiber(id: "lana", name: "Lana", family: .animale,
              aliases: ["lana", "wool", "laine", "wolle", "ull", "lana vergine", "virgin wool",
                        "schurwolle", "pure new wool", "wo", "wv", "wm"],
              summary: "Pelo di pecora: tiene caldo, si autopulisce all'aria, ma infeltrisce con calore e sfregamento.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 1,
                              bleachable: false, detergent: .lana,
                              warnings: ["Mai acqua calda o sbalzi di temperatura: infeltrisce e non torna indietro.",
                                         "Asciugala in piano: appesa si allunga sotto il proprio peso.",
                                         "Spesso basta arieggiarla invece di lavarla."])),

        Fiber(id: "merino", name: "Lana merino", family: .animale,
              aliases: ["merino", "lana merino", "merino wool", "extrafine merino"],
              summary: "Lana di pecora merino, molto più fine: morbida sulla pelle ma ancora più delicata.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 1,
                              bleachable: false, detergent: .lana,
                              warnings: ["Programma lana o a mano, sempre a freddo.",
                                         "Non strizzare: premi l'acqua fuori dentro un asciugamano."])),

        Fiber(id: "cashmere", name: "Cashmere", family: .animale,
              aliases: ["cashmere", "kashmir", "kaschmir", "cachemire", "cachemira", "wS"],
              summary: "Sottopelo della capra del Kashmir: leggerissimo e caldo, la fibra più fragile del guardaroba.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 1, bleachable: false, detergent: .lana,
                              warnings: ["A mano in acqua fredda, due minuti e basta.",
                                         "Pillole normali all'inizio: togli i pallini con un pettine per cashmere."])),

        Fiber(id: "mohair", name: "Mohair", family: .animale,
              aliases: ["mohair", "moher"],
              summary: "Pelo di capra d'angora: lucido e peloso, tende a perdere peli.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 0, bleachable: false, detergent: .lana,
                              warnings: ["Un giro in freezer dentro un sacchetto riduce la perdita di peli."])),

        Fiber(id: "alpaca", name: "Alpaca", family: .animale,
              aliases: ["alpaca", "alpaka", "alpaga"],
              summary: "Pelo di alpaca: caldo come la lana ma senza lanolina, quindi meno pruriginoso.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 1, bleachable: false, detergent: .lana,
                              warnings: ["Si allunga da bagnato: asciugalo sempre in piano."])),

        Fiber(id: "angora", name: "Angora", family: .animale,
              aliases: ["angora", "coniglio angora", "angora rabbit"],
              summary: "Pelo di coniglio d'angora: soffice e caldissimo, perde peli con facilità.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 0, bleachable: false, detergent: .lana,
                              warnings: ["Lavalo il meno possibile: aria e vapore bastano quasi sempre."])),

        Fiber(id: "cammello", name: "Cammello", family: .animale,
              aliases: ["cammello", "camel", "camel hair", "kamelhaar", "peli di cammello"],
              summary: "Pelo di cammello: molto caldo e leggero, si tratta come una lana pregiata.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 1, bleachable: false, detergent: .lana,
                              warnings: ["In genere è un capo da lavaggio a secco: controlla il simbolo del cerchio."])),

        Fiber(id: "seta", name: "Seta", family: .animale,
              aliases: ["seta", "silk", "soie", "seide", "seda", "ipek", "s"],
              summary: "Filo prodotto dal baco da seta: liscia e lucida, ma proteica e quindi sensibile a caldo e detersivi.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 1, bleachable: false, detergent: .lana,
                              warnings: ["Niente enzimi né candeggina: mangiano la fibra.",
                                         "Il deodorante e il sudore la macchiano in modo permanente.",
                                         "Stirala al rovescio, appena umida, senza vapore diretto."])),

        // MARK: Artificiali (cellulosa rigenerata)

        Fiber(id: "viscosa", name: "Viscosa", family: .artificiale,
              aliases: ["viscosa", "viscose", "rayon", "viskose", "cv", "raion"],
              summary: "Cellulosa di legno sciolta e filata: cade come la seta, ma bagnata perde metà della sua forza.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 2,
                              bleachable: false, detergent: .delicati,
                              warnings: ["È la fibra che restringe di più: acqua fredda e ciclo delicato.",
                                         "Non torcerla da bagnata, si deforma."])),

        Fiber(id: "modal", name: "Modal", family: .artificiale,
              aliases: ["modal", "modale", "cmd"],
              summary: "Viscosa di faggio migliorata: più morbida e più stabile in lavatrice.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .low, ironDots: 2,
                              bleachable: false, detergent: .delicati,
                              warnings: ["L'ammorbidente in eccesso la rende unta e la fa perdere assorbenza."])),

        Fiber(id: "lyocell", name: "Lyocell (Tencel)", family: .artificiale,
              aliases: ["lyocell", "tencel", "liocel", "cly"],
              summary: "Cellulosa prodotta con solvente riciclato: resistente anche da bagnata, la più pratica delle artificiali.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .low, ironDots: 2,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Può fibrillare, cioè fare una leggera peluria, se strofinata."])),

        Fiber(id: "cupro", name: "Cupro", family: .artificiale,
              aliases: ["cupro", "bemberg", "cuprammonium", "cuo"],
              summary: "Cellulosa da linter di cotone: fresca e scivolosa, usata quasi sempre per le fodere.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 1,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Restringe con l'acqua calda: freddo e ciclo delicato."])),

        Fiber(id: "acetato", name: "Acetato", family: .artificiale,
              aliases: ["acetato", "acetate", "acetat", "ca", "triacetato", "triacetate", "ctA"],
              summary: "Cellulosa trasformata in plastica e filata: lucida, economica, molto sensibile al calore.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .low, tumble: .forbidden,
                              ironDots: 1, bleachable: false, detergent: .delicati,
                              warnings: ["Si scioglie con l'acetone: attenzione allo smalto.",
                                         "Ferro tiepido e sempre al rovescio, altrimenti diventa lucido."])),

        Fiber(id: "bambu", name: "Bambù", family: .artificiale,
              aliases: ["bambu", "bamboo", "bambus", "viscosa di bambu", "bamboo viscose"],
              summary: "Quasi sempre viscosa ricavata dal bambù: morbidissima e assorbente, delicata come la viscosa.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 2,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Restringe con il caldo: lavaggio freddo."])),

        // MARK: Sintetiche

        Fiber(id: "poliestere", name: "Poliestere", family: .sintetica,
              aliases: ["poliestere", "polyester", "polyester", "poliester", "pes", "pl", "pet",
                        "polyester recycled", "poliestere riciclato"],
              summary: "Plastica filata: non restringe, asciuga in fretta, ma trattiene gli odori e teme il ferro caldo.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .low, ironDots: 1,
                              bleachable: false, detergent: .standard,
                              warnings: ["Sopra i 60 °C la fibra si fissa e le pieghe restano per sempre.",
                                         "Contro l'odore di sudore: mezza tazza di aceto bianco nell'ammorbidente."])),

        Fiber(id: "poliammide", name: "Poliammide (nylon)", family: .sintetica,
              aliases: ["poliammide", "polyamide", "nylon", "polyamid", "pa", "poliamida", "nailon"],
              summary: "La prima fibra sintetica: elastica e molto resistente all'abrasione, ma ingiallisce con il calore.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .low, ironDots: 1,
                              bleachable: false, detergent: .standard,
                              warnings: ["Sensibile al sole e alla candeggina: ingiallisce.",
                                         "Lava calze e collant in un sacchetto a rete."])),

        Fiber(id: "elastan", name: "Elastan (spandex)", family: .sintetica,
              aliases: ["elastan", "elastane", "elasthanne", "elasthan", "spandex", "lycra", "ea", "el",
                        "elastam", "elastane roica", "dorlastan"],
              summary: "Il filo di gomma che dà l'elasticità: basta il 2% per condizionare il lavaggio dell'intero capo.",
              care: FiberCare(maxWashC: 40, spin: .low, tumble: .forbidden, ironDots: 1,
                              bleachable: false, detergent: .standard,
                              warnings: ["Calore e ammorbidente rompono l'elastico: il capo si sborsa.",
                                         "Mai asciugatrice e mai ferro sulle parti elastiche."])),

        Fiber(id: "elastomultiestere", name: "Elastomultiestere", family: .sintetica,
              aliases: ["elastomultiestere", "elastomultiester", "elastolefin", "elastodiene", "ed"],
              summary: "Poliestere reso elastico: si comporta come l'elastan, con gli stessi limiti di temperatura.",
              care: FiberCare(maxWashC: 40, spin: .low, tumble: .forbidden, ironDots: 1,
                              bleachable: false, detergent: .standard,
                              warnings: ["Niente asciugatrice: l'elasticità si perde con il calore."])),

        Fiber(id: "acrilico", name: "Acrilico", family: .sintetica,
              aliases: ["acrilico", "acrylic", "acryl", "acrilica", "pan", "pc", "acrilan", "dralon"],
              summary: "L'imitazione sintetica della lana: calda e leggera, ma fa i pallini molto in fretta.",
              care: FiberCare(maxWashC: 40, spin: .low, tumble: .forbidden, ironDots: 1,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Si deforma con il calore e non torna più in forma.",
                                         "Rovescialo prima di lavarlo per limitare i pallini."])),

        Fiber(id: "modacrilico", name: "Modacrilico", family: .sintetica,
              aliases: ["modacrilico", "modacrylic", "modacryl", "ma"],
              summary: "Acrilico modificato, ignifugo: usato nelle pellicce sintetiche e negli indumenti da lavoro.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 0,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Il ferro caldo lo scioglie: non stirarlo."])),

        Fiber(id: "polipropilene", name: "Polipropilene", family: .sintetica,
              aliases: ["polipropilene", "polypropylene", "polypropylen", "pp", "prolen"],
              summary: "Fibra tecnica che non assorbe acqua: allontana il sudore, tipica dell'intimo sportivo.",
              care: FiberCare(maxWashC: 40, spin: .medium, tumble: .forbidden, ironDots: 0,
                              bleachable: false, detergent: .standard,
                              warnings: ["Fonde a bassa temperatura: niente ferro e niente asciugatrice."])),

        Fiber(id: "poliuretano", name: "Poliuretano", family: .sintetica,
              aliases: ["poliuretano", "polyurethane", "pu", "similpelle", "ecopelle", "faux leather",
                        "leatherette", "kunstleder"],
              summary: "Rivestimento plastico che imita la pelle: teme il calore, le pieghe e i solventi.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 0, bleachable: false, dryCleanFriendly: false,
                              detergent: .delicati,
                              warnings: ["Pulisci con un panno umido invece di lavarlo.",
                                         "Con il tempo lo strato si screpola: tienilo lontano dai termosifoni."])),

        // MARK: Altro

        Fiber(id: "pelle", name: "Pelle", family: .altro,
              aliases: ["pelle", "cuoio", "leather", "cuir", "leder", "piel", "vera pelle", "nabuk",
                        "nubuck", "camoscio", "suede"],
              summary: "Pelle animale conciata: l'acqua la irrigidisce e la macchia, va nutrita non lavata.",
              care: FiberCare(maxWashC: 0, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 0, bleachable: false, detergent: .delicati,
                              warnings: ["Mai in lavatrice: pulizia professionale o panno umido e crema.",
                                         "Asciugala lontano da fonti di calore, altrimenti si spacca."])),

        Fiber(id: "piuma", name: "Piuma e piumino", family: .altro,
              aliases: ["piuma", "piume", "piumino", "down", "daunen", "duvet", "feather", "goose down",
                        "plumas", "penne"],
              summary: "Imbottitura di piume d'oca o d'anatra: isola grazie all'aria, e l'aria va restituita asciugando.",
              care: FiberCare(maxWashC: 30, spin: .medium, tumble: .low, ironDots: 0,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Asciugatrice a bassa temperatura con due palline da tennis: è l'unico modo di ridare volume.",
                                         "Se resta umido dentro fa muffa e odore: asciugalo fino in fondo.",
                                         "Niente ammorbidente: appiattisce la piuma."])),

        Fiber(id: "pelliccia", name: "Pelliccia sintetica", family: .altro,
              aliases: ["pelliccia", "eco pelliccia", "ecopelliccia", "faux fur", "fake fur", "fourrure",
                        "kunstpelz", "pelo sintetico"],
              summary: "Pelo finto su base tessile: il calore lo arriccia e non si può più ravvivare.",
              care: FiberCare(maxWashC: 30, spin: .low, tumble: .forbidden, ironDots: 0,
                              bleachable: false, detergent: .delicati,
                              warnings: ["Niente asciugatrice: il pelo si accartoccia.",
                                         "Pettinalo da umido con una spazzola morbida."])),

        Fiber(id: "metallico", name: "Filato metallico", family: .altro,
              aliases: ["metallico", "metallic", "lurex", "filato metallico", "metallisierte faser", "mt"],
              summary: "Filo laminato che dà il brillante: si graffia e si annerisce con il calore.",
              care: FiberCare(maxWashC: 30, handWashOnly: true, spin: .none, tumble: .forbidden,
                              ironDots: 0, bleachable: false, detergent: .delicati,
                              warnings: ["Lavalo rovesciato, a mano, e non stirarlo mai sul lato lucido."])),
    ]

    private static let index: [String: Fiber] = {
        var map: [String: Fiber] = [:]
        for fiber in all {
            map[fiber.id] = fiber
            for alias in fiber.aliases {
                map[normalize(alias)] = fiber
            }
        }
        return map
    }()

    static func fiber(id: String) -> Fiber? { all.first { $0.id == id } }

    /// Lowercases, strips accents and collapses whitespace so that "Poliéstere",
    /// "POLYESTER" and "poli estere" all land on the same key.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    /// Resolves a name read off a label, tolerating the odd wrong letter that OCR
    /// leaves behind ("polvestere", "cotonc").
    static func match(_ raw: String) -> Fiber? {
        let key = normalize(raw)
        guard key.count >= 2 else { return nil }
        if let exact = index[key] { return exact }

        // A label often reads "cotone organico" or "viscosa LENZING": try the
        // longest alias contained in the string before falling back to distance.
        var best: (fiber: Fiber, length: Int)?
        for (alias, fiber) in index where alias.count >= 4 && key.contains(alias) {
            if best == nil || alias.count > best!.length { best = (fiber, alias.count) }
        }
        if let best { return best.fiber }

        guard key.count >= 4 else { return nil }
        var closest: (fiber: Fiber, distance: Int)?
        for (alias, fiber) in index where abs(alias.count - key.count) <= 2 && alias.count >= 4 {
            let distance = levenshtein(key, alias)
            let budget = key.count >= 8 ? 2 : 1
            guard distance <= budget else { continue }
            if closest == nil || distance < closest!.distance { closest = (fiber, distance) }
        }
        return closest?.fiber
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            current[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[t.count]
    }
}
