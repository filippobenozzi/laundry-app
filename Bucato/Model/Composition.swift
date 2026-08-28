import Foundation

/// One line of a composition: "80% cotone".
struct CompositionPart: Identifiable, Sendable {
    let id = UUID()
    let percentage: Int?
    let fiber: Fiber?
    /// What was actually printed, kept so the app can show an honest
    /// "non riconosciuto" instead of pretending.
    let rawName: String

    var displayName: String { fiber?.name ?? rawName.capitalized }
}

/// Labels often describe more than one piece of the garment: shell, lining, filling.
struct CompositionSection: Identifiable, Sendable {
    let id = UUID()
    let name: String?
    let parts: [CompositionPart]
}

struct Composition: Sendable {
    var sections: [CompositionSection]

    var isEmpty: Bool { sections.allSatisfy { $0.parts.isEmpty } }
    var allParts: [CompositionPart] { sections.flatMap(\.parts) }
    var fibers: [Fiber] {
        var seen = Set<String>()
        return allParts.compactMap(\.fiber).filter { seen.insert($0.id).inserted }
    }

    /// The share of the garment a fibre takes up, across every section, used to
    /// decide whether 5% elastane is worth a warning (it is).
    func share(of fiber: Fiber) -> Int? {
        let values = allParts.filter { $0.fiber?.id == fiber.id }.compactMap(\.percentage)
        return values.max()
    }
}

/// Turns the text Vision reads off a label into a composition.
enum CompositionParser {

    /// Words that introduce a part of the garment, in the languages that end up
    /// printed on European labels.
    private static let sectionWords: [(keys: [String], name: String)] = [
        (["esterno", "tessuto esterno", "shell", "outer", "outer shell", "obermaterial", "exterieur", "dessus", "tejido exterior"], "Esterno"),
        (["fodera", "lining", "futter", "doublure", "forro", "voering"], "Fodera"),
        (["imbottitura", "filling", "padding", "fullung", "rembourrage", "relleno", "wadding"], "Imbottitura"),
        (["rivestimento", "coating", "beschichtung"], "Rivestimento"),
        (["polsini", "cuffs", "bordi", "rib", "costine", "collo", "collar"], "Bordi"),
        (["ricamo", "embroidery", "stampa", "print"], "Ricamo"),
    ]

    /// Splits on the punctuation labels use between fibres, keeping the numbers.
    private static let percentPattern = try! NSRegularExpression(
        pattern: #"(\d{1,3})\s*(?:%|per\s?cento|percent)"#, options: [.caseInsensitive])
    private static let leadingPercentPattern = try! NSRegularExpression(
        pattern: #"(?:%|per\s?cento|percent)\s*(\d{1,3})"#, options: [.caseInsensitive])

    static func parse(_ text: String) -> Composition {
        let cleaned = text.replacingOccurrences(of: "\n", with: " \n ")
        let entries = extractEntries(from: cleaned)
        guard !entries.isEmpty else { return Composition(sections: []) }

        let groups = group(entries)
        var sections: [CompositionSection] = []
        var seenSignatures = Set<String>()

        for group in groups {
            let signature = group
                .map { "\($0.part.fiber?.id ?? FiberCatalog.normalize($0.part.rawName)):\($0.part.percentage ?? -1)" }
                .sorted().joined(separator: "|")
            // The same composition is often repeated in four languages. Once is enough.
            guard seenSignatures.insert(signature).inserted else { continue }

            let name = sectionName(in: cleaned, before: group.first?.location ?? 0)
            sections.append(CompositionSection(name: name, parts: group.map(\.part)))
        }

        // If several sections carry no name but different fibres, the first one is
        // the garment itself; name the rest only when the label said so.
        return Composition(sections: sections)
    }

    // MARK: - Pieces

    private struct Entry {
        let part: CompositionPart
        let location: Int
        let end: Int
    }

    private static func extractEntries(from text: String) -> [Entry] {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        struct Hit { let percentage: Int; let range: NSRange; let numberFirst: Bool }
        var hits: [Hit] = []
        for match in percentPattern.matches(in: text, range: full) {
            guard let value = Int(ns.substring(with: match.range(at: 1))) else { continue }
            hits.append(Hit(percentage: value, range: match.range, numberFirst: true))
        }
        for match in leadingPercentPattern.matches(in: text, range: full) {
            guard let value = Int(ns.substring(with: match.range(at: 1))) else { continue }
            // Skip the ones already caught by the "80%" form.
            if hits.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) { continue }
            hits.append(Hit(percentage: value, range: match.range, numberFirst: false))
        }
        hits.sort { $0.range.location < $1.range.location }

        // "80% cotone" reads forwards, "cotone 80%" backwards, and a label picks one
        // style and sticks to it. Read both sides of every percentage first, then let
        // the label as a whole decide which side to believe.
        struct Sides { let hit: Hit; let forward: String?; let backward: String? }
        var sides: [Sides] = []
        for (index, hit) in hits.enumerated() where hit.percentage > 0 && hit.percentage <= 100 {
            let afterStart = hit.range.location + hit.range.length
            let afterEnd = index + 1 < hits.count ? hits[index + 1].range.location : ns.length
            let after = afterEnd > afterStart ? ns.substring(with: NSRange(location: afterStart, length: afterEnd - afterStart)) : ""

            let beforeStart = index > 0 ? hits[index - 1].range.location + hits[index - 1].range.length : 0
            let before = hit.range.location > beforeStart
                ? ns.substring(with: NSRange(location: beforeStart, length: hit.range.location - beforeStart))
                : ""

            sides.append(Sides(hit: hit, forward: firstFiberName(after: after), backward: lastFiberName(before: before)))
        }

        let forwardHits = sides.filter { $0.forward.flatMap(FiberCatalog.match) != nil }.count
        let backwardHits = sides.filter { $0.backward.flatMap(FiberCatalog.match) != nil }.count
        let readsBackwards = backwardHits > forwardHits

        var entries: [Entry] = []
        for side in sides {
            let hit = side.hit
            let ordered = readsBackwards
                ? [side.backward, side.forward].compactMap { $0 }
                : [side.forward, side.backward].compactMap { $0 }

            guard let name = ordered.first(where: { FiberCatalog.match($0) != nil }) ?? ordered.first else { continue }
            let fiber = FiberCatalog.match(name)
            // An unrecognised word right next to a percentage is still worth showing,
            // but only if it looks like a fibre name and not like a size or a country.
            guard fiber != nil || (name.count >= 4 && name.count <= 24) else { continue }

            entries.append(Entry(
                part: CompositionPart(percentage: hit.percentage, fiber: fiber, rawName: name.trimmingCharacters(in: .whitespaces)),
                location: hit.range.location,
                end: hit.range.location + hit.range.length))
        }
        return entries
    }

    /// The first run of letters after a percentage, stopping at punctuation, at a
    /// newline or after four words.
    private static func firstFiberName(after text: String) -> String? {
        let stops = CharacterSet(charactersIn: "\n,;/·•|+()[]{}<>*")
        var collected: [String] = []
        var current = ""
        for character in text {
            if character.unicodeScalars.allSatisfy({ stops.contains($0) }) { break }
            if character.isNumber { break }
            if character.isWhitespace {
                if !current.isEmpty { collected.append(current); current = "" }
                if collected.count >= 3 { break }
                continue
            }
            if character.isLetter || character == "'" || character == "-" { current.append(character) }
            else if !current.isEmpty { break }
        }
        if !current.isEmpty { collected.append(current) }
        return bestName(from: collected)
    }

    private static func lastFiberName(before text: String) -> String? {
        let stops = CharacterSet(charactersIn: "\n,;/·•|+()[]{}<>*")
        var collected: [String] = []
        var current = ""
        for character in text.reversed() {
            if character.unicodeScalars.allSatisfy({ stops.contains($0) }) { break }
            if character.isNumber { break }
            if character.isWhitespace {
                if !current.isEmpty { collected.append(String(current.reversed())); current = "" }
                if collected.count >= 3 { break }
                continue
            }
            if character.isLetter || character == "'" || character == "-" { current.append(character) }
            else if !current.isEmpty { break }
        }
        if !current.isEmpty { collected.append(String(current.reversed())) }
        return bestName(from: collected.reversed())
    }

    /// Prefers the longest run of words that the catalogue actually knows, so that
    /// "lana merino" wins over "lana" and stray words are dropped.
    private static func bestName(from words: [String]) -> String? {
        let words = words.filter { $0.count >= 2 }
        guard !words.isEmpty else { return nil }
        for length in stride(from: min(3, words.count), through: 1, by: -1) {
            for start in 0...(words.count - length) {
                let phrase = words[start..<(start + length)].joined(separator: " ")
                if FiberCatalog.match(phrase) != nil { return phrase }
            }
        }
        return words.first
    }

    /// Splits the flat list into groups that each add up to a whole garment.
    private static func group(_ entries: [Entry]) -> [[Entry]] {
        var groups: [[Entry]] = []
        var current: [Entry] = []
        var total = 0
        var used = Set<String>()

        for entry in entries {
            let key = entry.part.fiber?.id ?? FiberCatalog.normalize(entry.part.rawName)
            let percentage = entry.part.percentage ?? 0
            let repeats = used.contains(key)
            let overflows = total + percentage > 100

            if !current.isEmpty && (repeats || overflows) {
                groups.append(current)
                current = []
                total = 0
                used = []
            }
            current.append(entry)
            total += percentage
            used.insert(key)
            if total >= 100 {
                groups.append(current)
                current = []
                total = 0
                used = []
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    private static func sectionName(in text: String, before location: Int) -> String? {
        let ns = text as NSString
        let windowStart = max(0, location - 60)
        let window = FiberCatalog.normalize(ns.substring(with: NSRange(location: windowStart, length: location - windowStart)))
        var best: (name: String, position: Int)?
        for (keys, name) in sectionWords {
            for key in keys {
                if let range = window.range(of: key, options: .backwards) {
                    let position = window.distance(from: window.startIndex, to: range.lowerBound)
                    if best == nil || position > best!.position { best = (name, position) }
                }
            }
        }
        return best?.name
    }
}
