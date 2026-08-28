import Foundation

/// The five families of the ISO 3758 / GINETEX care code, in the order they are
/// always printed on a label: tub, triangle, square, iron, circle.
enum CareFamily: String, Codable, CaseIterable, Sendable {
    case lavaggio, candeggio, asciugatura, stiratura, professionale

    var title: String {
        switch self {
        case .lavaggio: return "Lavaggio"
        case .candeggio: return "Candeggio"
        case .asciugatura: return "Asciugatura"
        case .stiratura: return "Stiratura"
        case .professionale: return "Lavaggio professionale"
        }
    }

    /// What the outline itself means, before any dot or bar is added.
    var shapeMeaning: String {
        switch self {
        case .lavaggio: return "La bacinella è l'acqua: dice se e a che temperatura puoi lavare il capo."
        case .candeggio: return "Il triangolo è la candeggina e ogni altro smacchiatore ossidante."
        case .asciugatura: return "Il quadrato è l'asciugatura: con il cerchio dentro parla dell'asciugatrice, con le linee dell'aria."
        case .stiratura: return "Il ferro è la stiratura, e i pallini sono la temperatura massima della piastra."
        case .professionale: return "Il cerchio è la lavanderia: le lettere dicono al lavandaio che solvente usare."
        }
    }
}

// MARK: - How a symbol is drawn

enum GlyphBase: String, Codable, Sendable {
    case washtub, triangle, square, iron, circle
}

/// The mark that lives inside the outline.
enum GlyphInner: String, Codable, Sendable {
    case tumbleCircle       // asciugatrice
    case lineVertical       // steso su filo
    case lineVerticalDouble // gocciolare senza strizzare
    case lineHorizontal     // in piano
    case lineHorizontalDouble
    case bleachStripes      // due tratti obliqui: solo ossigeno
    case hand               // lavaggio a mano
    case steamCrossed       // stirare senza vapore
}

/// Everything needed to draw a care symbol as a line drawing.
struct GlyphSpec: Equatable, Sendable {
    var base: GlyphBase
    var text: String? = nil          // "30", "60", "P", "F", "W"
    var dots: Int = 0                // pallini di temperatura
    var bars: Int = 0               // trattini sotto: trattamento più delicato
    var crossed: Bool = false        // divieto
    var shaded: Bool = false         // tratto obliquo nell'angolo: all'ombra
    var inner: GlyphInner? = nil
}

// MARK: - What a symbol changes in the wash plan

enum DryMethod: String, Codable, Sendable {
    case tumble, filo, piano, gocciolare
}

enum ProCleaning: String, Codable, Sendable {
    case perchlor, hydrocarbon, wet, none
}

/// The constraints a single symbol imposes. Everything is optional: a symbol only
/// speaks about its own family.
struct CareEffect: Sendable {
    var maxWashC: Int? = nil
    /// True when the temperature comes from the standard rather than from a number
    /// printed on the label — the hand-wash symbol implies 40 °C, it does not say
    /// it. An implied ceiling gives way to what the fibre can actually take.
    var temperatureIsImplied: Bool = false
    var handWashOnly: Bool = false
    var doNotWash: Bool = false
    var spin: SpinLevel? = nil
    var detergent: DetergentKind? = nil
    var bleachable: Bool? = nil
    var oxygenBleachOnly: Bool = false
    var tumble: TumbleLevel? = nil
    var dryMethod: DryMethod? = nil
    var dryInShade: Bool = false
    var ironDots: Int? = nil
    var noSteam: Bool = false
    var proCleaning: ProCleaning? = nil
    var proMild: Bool = false
}

struct CareSymbol: Identifiable, Sendable {
    let id: String
    let family: CareFamily
    let title: String
    /// One or two sentences: what the symbol says.
    let meaning: String
    /// What to actually do about it. Nil when the meaning is already the action.
    let tip: String?
    let glyph: GlyphSpec
    let effect: CareEffect
}

enum CareSymbolCatalog {

    // MARK: Lavaggio

    private static func washTemperature(_ celsius: Int, bars: Int) -> CareSymbol {
        let cycle: String
        let tip: String
        let spin: SpinLevel
        let detergent: DetergentKind?
        switch bars {
        case 2:
            cycle = ", ciclo molto delicato"
            tip = "Due trattini sotto la bacinella: programma delicati o lana, cestello mezzo vuoto e centrifuga al minimo."
            spin = .low
            detergent = .delicati
        case 1:
            cycle = ", ciclo delicato"
            tip = "Un trattino sotto la bacinella: usa il programma sintetici, con centrifuga ridotta."
            spin = .medium
            detergent = nil
        default:
            cycle = ""
            tip = "Nessun trattino: lavaggio normale, il capo regge l'agitazione piena."
            spin = .full
            detergent = nil
        }
        return CareSymbol(
            id: "wash-\(celsius)\(bars > 0 ? "-\(bars)" : "")",
            family: .lavaggio,
            title: "Lavaggio a \(celsius) °C\(cycle)",
            meaning: "\(celsius) °C è la temperatura massima, non quella consigliata: puoi sempre lavare più freddo.",
            tip: tip,
            glyph: GlyphSpec(base: .washtub, text: "\(celsius)", bars: bars),
            effect: CareEffect(maxWashC: celsius, spin: spin, detergent: detergent)
        )
    }

    static let all: [CareSymbol] = [

        washTemperature(95, bars: 0),
        washTemperature(70, bars: 0),
        washTemperature(60, bars: 0),
        washTemperature(60, bars: 1),
        washTemperature(50, bars: 0),
        washTemperature(50, bars: 1),
        washTemperature(40, bars: 0),
        washTemperature(40, bars: 1),
        washTemperature(40, bars: 2),
        washTemperature(30, bars: 0),
        washTemperature(30, bars: 1),
        washTemperature(30, bars: 2),

        CareSymbol(
            id: "wash-unknown", family: .lavaggio,
            title: "Lavabile in acqua",
            meaning: "La bacinella c'è, ma la temperatura stampata dentro non si legge.",
            tip: "Regolati sulla composizione: sotto trovi la temperatura più prudente per queste fibre.",
            glyph: GlyphSpec(base: .washtub),
            effect: CareEffect()
        ),

        CareSymbol(
            id: "wash-hand", family: .lavaggio,
            title: "Lavaggio a mano",
            meaning: "Solo a mano, in acqua fino a 40 °C, senza strofinare e senza torcere il capo.",
            tip: "Bacinella d'acqua tiepida, un cucchiaino di detersivo delicato, cinque minuti in ammollo. Poi premi l'acqua fuori dentro un asciugamano.",
            glyph: GlyphSpec(base: .washtub, inner: .hand),
            effect: CareEffect(maxWashC: 40, temperatureIsImplied: true, handWashOnly: true,
                               spin: SpinLevel.none, detergent: .delicati)
        ),

        CareSymbol(
            id: "wash-none", family: .lavaggio,
            title: "Non lavare in acqua",
            meaning: "Il capo non va bagnato: né lavatrice né lavaggio a mano.",
            tip: "Guarda il cerchio del lavaggio professionale: quasi sempre accanto c'è la lettera del solvente da usare in lavanderia.",
            glyph: GlyphSpec(base: .washtub, crossed: true),
            effect: CareEffect(doNotWash: true)
        ),

        // MARK: Candeggio

        CareSymbol(
            id: "bleach-any", family: .candeggio,
            title: "Candeggio consentito",
            meaning: "Il triangolo vuoto permette qualsiasi candeggiante, cloro compreso.",
            tip: "Anche quando è permesso, la candeggina consuma le fibre: usala solo sul bianco e diluita.",
            glyph: GlyphSpec(base: .triangle),
            effect: CareEffect(bleachable: true)
        ),

        CareSymbol(
            id: "bleach-oxygen", family: .candeggio,
            title: "Solo candeggio all'ossigeno",
            meaning: "I due tratti obliqui escludono il cloro: sono ammessi solo gli smacchiatori all'ossigeno attivo.",
            tip: "Sono i comuni smacchiatori in polvere per capi colorati, quelli senza cloro.",
            glyph: GlyphSpec(base: .triangle, inner: .bleachStripes),
            effect: CareEffect(bleachable: true, oxygenBleachOnly: true)
        ),

        CareSymbol(
            id: "bleach-none", family: .candeggio,
            title: "Non candeggiare",
            meaning: "Nessun candeggiante, né a base di cloro né all'ossigeno.",
            tip: "Attenzione ai detersivi \"per bianchi\": molti contengono sbiancanti.",
            glyph: GlyphSpec(base: .triangle, crossed: true),
            effect: CareEffect(bleachable: false)
        ),

        // MARK: Asciugatura

        CareSymbol(
            id: "tumble-normal", family: .asciugatura,
            title: "Asciugatrice a temperatura normale",
            meaning: "Due pallini nel cerchio: il capo regge il ciclo caldo dell'asciugatrice.",
            tip: nil,
            glyph: GlyphSpec(base: .square, dots: 2, inner: .tumbleCircle),
            effect: CareEffect(tumble: .normal, dryMethod: .tumble)
        ),

        CareSymbol(
            id: "tumble-low", family: .asciugatura,
            title: "Asciugatrice a bassa temperatura",
            meaning: "Un solo pallino: asciugatrice sì, ma sul programma delicato o \"basso calore\".",
            tip: "Togli il capo ancora leggermente umido: gli ultimi minuti sono quelli che restringono.",
            glyph: GlyphSpec(base: .square, dots: 1, inner: .tumbleCircle),
            effect: CareEffect(tumble: .low, dryMethod: .tumble)
        ),

        CareSymbol(
            id: "tumble-none", family: .asciugatura,
            title: "Non usare l'asciugatrice",
            meaning: "Il cerchio barrato nel quadrato vieta l'asciugatrice a qualsiasi temperatura.",
            tip: "Il capo va asciugato all'aria: guarda le linee dentro il quadrato per sapere come.",
            glyph: GlyphSpec(base: .square, crossed: true, inner: .tumbleCircle),
            effect: CareEffect(tumble: .forbidden)
        ),

        CareSymbol(
            id: "dry-line", family: .asciugatura,
            title: "Asciugare steso su filo",
            meaning: "La linea verticale nel quadrato: appendi il capo e lascialo asciugare all'aria.",
            tip: nil,
            glyph: GlyphSpec(base: .square, inner: .lineVertical),
            effect: CareEffect(tumble: .forbidden, dryMethod: .filo)
        ),

        CareSymbol(
            id: "dry-drip", family: .asciugatura,
            title: "Asciugare gocciolante",
            meaning: "Due linee verticali: appendi il capo bagnato senza strizzarlo e senza centrifugarlo.",
            tip: "Mettici sotto un asciugamano o una bacinella: perderà parecchia acqua.",
            glyph: GlyphSpec(base: .square, inner: .lineVerticalDouble),
            effect: CareEffect(spin: SpinLevel.none, tumble: .forbidden, dryMethod: .gocciolare)
        ),

        CareSymbol(
            id: "dry-flat", family: .asciugatura,
            title: "Asciugare in piano",
            meaning: "La linea orizzontale: il capo va steso disteso, non appeso.",
            tip: "Appeso si allungherebbe sotto il proprio peso. Stendilo su un asciugamano e dagli la forma giusta da bagnato.",
            glyph: GlyphSpec(base: .square, inner: .lineHorizontal),
            effect: CareEffect(tumble: .forbidden, dryMethod: .piano)
        ),

        CareSymbol(
            id: "dry-flat-drip", family: .asciugatura,
            title: "Asciugare in piano, senza strizzare",
            meaning: "Due linee orizzontali: in piano e senza centrifuga, ancora gocciolante.",
            tip: nil,
            glyph: GlyphSpec(base: .square, inner: .lineHorizontalDouble),
            effect: CareEffect(spin: SpinLevel.none, tumble: .forbidden, dryMethod: .piano)
        ),

        CareSymbol(
            id: "dry-line-shade", family: .asciugatura,
            title: "Asciugare su filo, all'ombra",
            meaning: "Il tratto nell'angolo aggiunge \"all'ombra\": stendi il capo lontano dal sole diretto.",
            tip: "Il sole scolora i tessuti tinti e ingiallisce il bianco sintetico.",
            glyph: GlyphSpec(base: .square, shaded: true, inner: .lineVertical),
            effect: CareEffect(tumble: .forbidden, dryMethod: .filo, dryInShade: true)
        ),

        CareSymbol(
            id: "dry-flat-shade", family: .asciugatura,
            title: "Asciugare in piano, all'ombra",
            meaning: "In piano e lontano dal sole diretto.",
            tip: nil,
            glyph: GlyphSpec(base: .square, shaded: true, inner: .lineHorizontal),
            effect: CareEffect(tumble: .forbidden, dryMethod: .piano, dryInShade: true)
        ),

        CareSymbol(
            id: "dry-none", family: .asciugatura,
            title: "Non asciugare",
            meaning: "Il quadrato barrato: il capo non va sottoposto ad asciugatura, in nessuna forma.",
            tip: "Compare quasi solo insieme al divieto di lavaggio: è un capo da lavanderia.",
            glyph: GlyphSpec(base: .square, crossed: true),
            effect: CareEffect(tumble: .forbidden)
        ),

        // MARK: Stiratura

        CareSymbol(
            id: "iron-3", family: .stiratura,
            title: "Ferro caldo, max 200 °C",
            meaning: "Tre pallini: la posizione più calda del ferro, quella di cotone e lino.",
            tip: nil,
            glyph: GlyphSpec(base: .iron, dots: 3),
            effect: CareEffect(ironDots: 3)
        ),

        CareSymbol(
            id: "iron-2", family: .stiratura,
            title: "Ferro medio, max 150 °C",
            meaning: "Due pallini: temperatura media, quella di lana, poliestere e viscosa.",
            tip: "Meglio ancora al rovescio o con un panno umido sopra.",
            glyph: GlyphSpec(base: .iron, dots: 2),
            effect: CareEffect(ironDots: 2)
        ),

        CareSymbol(
            id: "iron-1", family: .stiratura,
            title: "Ferro tiepido, max 110 °C",
            meaning: "Un pallino: ferro appena tiepido, e senza vapore.",
            tip: "È la posizione di seta, acrilico ed elastan. Stira sempre al rovescio.",
            glyph: GlyphSpec(base: .iron, dots: 1),
            effect: CareEffect(ironDots: 1, noSteam: true)
        ),

        CareSymbol(
            id: "iron-any", family: .stiratura,
            title: "Si può stirare",
            meaning: "Il ferro senza pallini: la stiratura è permessa, ma la temperatura non è indicata.",
            tip: "Parti dal minimo e sali solo se serve, sempre al rovescio.",
            glyph: GlyphSpec(base: .iron),
            effect: CareEffect()
        ),

        CareSymbol(
            id: "iron-none", family: .stiratura,
            title: "Non stirare",
            meaning: "Il ferro barrato: il calore rovinerebbe la fibra o le stampe.",
            tip: "Per togliere le pieghe appendi il capo in bagno mentre fai la doccia: il vapore basta.",
            glyph: GlyphSpec(base: .iron, crossed: true),
            effect: CareEffect(ironDots: 0)
        ),

        CareSymbol(
            id: "iron-no-steam", family: .stiratura,
            title: "Stirare senza vapore",
            meaning: "Il vapore barrato sotto il ferro: si può stirare, ma a secco.",
            tip: "Sui capi lucidi il vapore lascia aloni che non vanno più via.",
            glyph: GlyphSpec(base: .iron, inner: .steamCrossed),
            effect: CareEffect(noSteam: true)
        ),

        // MARK: Lavaggio professionale

        CareSymbol(
            id: "pro-any", family: .professionale,
            title: "Lavaggio professionale consentito",
            meaning: "Il cerchio da solo dice che il capo può andare in lavanderia, senza indicare il solvente.",
            tip: nil,
            glyph: GlyphSpec(base: .circle),
            effect: CareEffect(proCleaning: .perchlor)
        ),

        CareSymbol(
            id: "pro-P", family: .professionale,
            title: "Lavaggio a secco (percloroetilene)",
            meaning: "La P dice al lavandaio che può usare il solvente classico. È un'informazione per lui, non per te.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, text: "P"),
            effect: CareEffect(proCleaning: .perchlor)
        ),

        CareSymbol(
            id: "pro-P-mild", family: .professionale,
            title: "Lavaggio a secco delicato (percloroetilene)",
            meaning: "Stesso solvente, ma con ciclo ridotto: meno meccanica, meno calore, meno umidità.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, text: "P", bars: 1),
            effect: CareEffect(proCleaning: .perchlor, proMild: true)
        ),

        CareSymbol(
            id: "pro-F", family: .professionale,
            title: "Lavaggio a secco (idrocarburi)",
            meaning: "La F indica il solvente più delicato a base di idrocarburi.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, text: "F"),
            effect: CareEffect(proCleaning: .hydrocarbon)
        ),

        CareSymbol(
            id: "pro-F-mild", family: .professionale,
            title: "Lavaggio a secco delicato (idrocarburi)",
            meaning: "Solvente a idrocarburi, ciclo ridotto.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, text: "F", bars: 1),
            effect: CareEffect(proCleaning: .hydrocarbon, proMild: true)
        ),

        CareSymbol(
            id: "pro-none", family: .professionale,
            title: "Non lavare a secco",
            meaning: "Il cerchio barrato: i solventi della lavanderia rovinerebbero il capo o le sue finiture.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, crossed: true),
            effect: CareEffect(proCleaning: ProCleaning.none)
        ),

        CareSymbol(
            id: "pro-W", family: .professionale,
            title: "Wet cleaning professionale",
            meaning: "La W è il lavaggio ad acqua fatto in lavanderia, con macchine e detersivi controllati.",
            tip: "Non è il permesso di lavarlo in casa: la bacinella resta l'unico simbolo che parla della tua lavatrice.",
            glyph: GlyphSpec(base: .circle, text: "W"),
            effect: CareEffect(proCleaning: .wet)
        ),

        CareSymbol(
            id: "pro-W-mild", family: .professionale,
            title: "Wet cleaning delicato",
            meaning: "Lavaggio ad acqua professionale con ciclo ridotto.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, text: "W", bars: 1),
            effect: CareEffect(proCleaning: .wet, proMild: true)
        ),

        CareSymbol(
            id: "pro-W-none", family: .professionale,
            title: "Niente wet cleaning",
            meaning: "La W barrata esclude anche il lavaggio ad acqua professionale.",
            tip: nil,
            glyph: GlyphSpec(base: .circle, text: "W", crossed: true),
            effect: CareEffect(proCleaning: ProCleaning.none)
        ),
    ]

    static func symbol(id: String) -> CareSymbol? { all.first { $0.id == id } }

    static func family(_ family: CareFamily) -> [CareSymbol] { all.filter { $0.family == family } }

    /// The temperature a dotted washtub stands for. Older labels print pallini
    /// instead of the number.
    static func washTemperature(forDots dots: Int) -> Int? {
        switch dots {
        case 1: return 30
        case 2: return 40
        case 3: return 50
        case 4: return 60
        case 5: return 70
        case 6: return 95
        default: return nil
        }
    }

    /// Finds the catalog entry that a drawing corresponds to. The detector builds
    /// a `GlyphSpec` from what it saw on the label and looks the meaning up here.
    static func match(_ spec: GlyphSpec) -> CareSymbol? {
        if let exact = all.first(where: { $0.glyph == spec }) { return exact }

        // Nothing matched exactly: fall back to the closest entry of the same base
        // shape, scoring the features that carry the most meaning first.
        var best: (symbol: CareSymbol, score: Int)?
        for candidate in all where candidate.glyph.base == spec.base {
            let g = candidate.glyph
            guard g.crossed == spec.crossed else { continue }
            var score = 0
            if g.text == spec.text { score += 6 } else { score -= 5 }
            if g.inner == spec.inner { score += 5 } else { score -= 4 }
            if g.dots == spec.dots { score += 3 } else { score -= abs(g.dots - spec.dots) }
            if g.bars == spec.bars { score += 2 } else { score -= abs(g.bars - spec.bars) }
            if g.shaded == spec.shaded { score += 1 }
            if best == nil || score > best!.score { best = (candidate, score) }
        }
        guard let best, best.score > 0 else { return nil }
        return best.symbol
    }
}
