import Foundation
import CoreGraphics

/// Where a symbol came from, so the app can be honest about how sure it is.
enum SymbolSource: String, Codable, Sendable {
    case immagine   // recognised in the photo
    case testo      // written out in words on the label
    case manuale    // the person added it
    case salvato    // read back from a garment in the wardrobe

    var label: String {
        switch self {
        case .immagine: return "riconosciuto dalla foto"
        case .testo: return "scritto sull'etichetta"
        case .manuale: return "aggiunto a mano"
        case .salvato: return "salvato con il capo"
        }
    }
}

struct DetectedSymbol: Identifiable, Sendable {
    let id = UUID()
    let symbol: CareSymbol
    var confidence: Double
    var source: SymbolSource
    /// Normalised to the analysed image, origin top-left. Nil when not from a photo.
    var box: CGRect?

    var isUncertain: Bool { source == .immagine && confidence < 0.62 }
}

/// Everything Bucato managed to read off one label.
struct LabelReading: Sendable {
    var composition: Composition
    var symbols: [DetectedSymbol]
    var rawText: String

    var isEmpty: Bool { composition.isEmpty && symbols.isEmpty }

    /// One symbol per family, most confident first — labels never carry two
    /// contradictory symbols of the same family.
    var bestPerFamily: [DetectedSymbol] {
        var chosen: [CareFamily: DetectedSymbol] = [:]
        for detected in symbols {
            let family = detected.symbol.family
            if let existing = chosen[family] {
                if detected.confidence > existing.confidence { chosen[family] = detected }
            } else {
                chosen[family] = detected
            }
        }
        return CareFamily.allCases.compactMap { chosen[$0] }
    }
}

/// Care instructions printed in words. Many labels write them out next to the
/// symbols, in one or more languages, and the words are far easier to read than
/// the drawings.
enum CareTextHints {

    private static let rules: [(patterns: [String], symbolID: String)] = [
        (["non lavare", "do not wash", "nicht waschen", "ne pas laver", "no lavar"], "wash-none"),
        (["lavaggio a mano", "lavare a mano", "solo a mano", "hand wash", "handwash", "handwasche",
          "lavage a la main", "lavar a mano"], "wash-hand"),
        (["non candeggiare", "no candeggio", "do not bleach", "nicht bleichen", "ne pas blanchir",
          "no usar lejia", "non usare candeggina"], "bleach-none"),
        (["non stirare", "do not iron", "nicht bugeln", "ne pas repasser", "no planchar"], "iron-none"),
        (["stirare senza vapore", "no steam", "senza vapore", "ohne dampf"], "iron-no-steam"),
        (["non asciugare in asciugatrice", "non usare asciugatrice", "do not tumble dry",
          "no tumble dry", "nicht in den trockner", "ne pas secher en machine", "no usar secadora",
          "non asciugare a macchina"], "tumble-none"),
        (["asciugare in piano", "asciugatura in piano", "dry flat", "lay flat to dry",
          "liegend trocknen", "secher a plat"], "dry-flat"),
        (["asciugare all ombra", "all ombra", "dry in shade", "im schatten trocknen"], "dry-line-shade"),
        (["stendere su filo", "asciugare steso", "line dry", "hang to dry", "hang dry"], "dry-line"),
        (["lavaggio a secco", "solo lavaggio a secco", "dry clean only", "dry clean",
          "nur chemisch reinigen", "nettoyage a sec", "limpieza en seco"], "pro-P"),
        (["non lavare a secco", "do not dry clean", "nicht chemisch reinigen"], "pro-none"),
    ]

    private static let temperaturePattern = try! NSRegularExpression(
        pattern: #"(?:max\.?\s*)?(30|40|50|60|70|90|95)\s*(?:°|º|o)?\s*c?\b"#, options: [.caseInsensitive])

    /// Reads care instructions out of the label text. Returns them already scored
    /// below the photo detections, so a symbol seen in the image wins a tie.
    static func hints(in text: String) -> [DetectedSymbol] {
        let normalized = FiberCatalog.normalize(text)
        var found: [DetectedSymbol] = []
        var seenFamilies = Set<CareFamily>()

        for (patterns, symbolID) in rules {
            guard patterns.contains(where: { normalized.contains($0) }),
                  let symbol = CareSymbolCatalog.symbol(id: symbolID),
                  seenFamilies.insert(symbol.family).inserted else { continue }
            found.append(DetectedSymbol(symbol: symbol, confidence: 0.9, source: .testo, box: nil))
        }

        // A temperature written in words only counts when the text is talking about
        // washing, otherwise "60" is just a size or a fabric weight.
        let washWords = ["lav", "wash", "wasch", "machine", "lavatrice", "waschen", "laver"]
        if !seenFamilies.contains(.lavaggio), washWords.contains(where: { normalized.contains($0) }) {
            let ns = normalized as NSString
            let matches = temperaturePattern.matches(in: normalized, range: NSRange(location: 0, length: ns.length))
            let temperatures = matches.compactMap { Int(ns.substring(with: $0.range(at: 1))) }
            if let lowest = temperatures.min() {
                let celsius = lowest == 90 ? 95 : lowest
                if let symbol = CareSymbolCatalog.symbol(id: "wash-\(celsius)") {
                    found.append(DetectedSymbol(symbol: symbol, confidence: 0.85, source: .testo, box: nil))
                }
            }
        }

        return found
    }
}
