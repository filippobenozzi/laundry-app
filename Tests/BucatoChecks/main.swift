import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}
func section(_ title: String) { print("\n== \(title)") }

// MARK: - Fibre lookup

section("FiberCatalog.match")
check(FiberCatalog.match("cotone")?.id == "cotone", "italian name")
check(FiberCatalog.match("COTTON")?.id == "cotone", "english, uppercase")
check(FiberCatalog.match("Algodón")?.id == "cotone", "spanish with accent")
check(FiberCatalog.match("polvestere")?.id == "poliestere", "ocr typo, one letter off")
check(FiberCatalog.match("lana merino")?.id == "merino", "longest alias wins over 'lana'")
check(FiberCatalog.match("elasthanne")?.id == "elastan", "french elastane")
check(FiberCatalog.match("viscosa LENZING")?.id == "viscosa", "brand suffix ignored")
check(FiberCatalog.match("made in italy") == nil, "not a fibre")

// MARK: - Composition

section("CompositionParser")
let simple = CompositionParser.parse("80% COTONE 20% POLIESTERE")
check(simple.allParts.count == 2, "two fibres")
check(simple.allParts.first?.fiber?.id == "cotone" && simple.allParts.first?.percentage == 80, "80% cotone")
check(simple.allParts.last?.fiber?.id == "poliestere" && simple.allParts.last?.percentage == 20, "20% poliestere")

let reversed = CompositionParser.parse("COTONE 100%")
check(reversed.allParts.count == 1 && reversed.allParts[0].fiber?.id == "cotone", "name before percentage")

let namesFirst = CompositionParser.parse("COTONE 80% POLIESTERE 20%")
check(namesFirst.allParts.count == 2, "names before percentages: two fibres")
check(namesFirst.allParts.first?.fiber?.id == "cotone" && namesFirst.allParts.first?.percentage == 80,
      "cotone keeps its 80%, not the poliestere that follows")
check(namesFirst.allParts.last?.fiber?.id == "poliestere" && namesFirst.allParts.last?.percentage == 20,
      "poliestere keeps its 20%")

let multilingual = CompositionParser.parse("""
95% COTONE 5% ELASTAN
95% COTTON 5% ELASTANE
95% BAUMWOLLE 5% ELASTHAN
""")
check(multilingual.allParts.count == 2, "the same composition in three languages is read once")
check(multilingual.fibers.map(\.id) == ["cotone", "elastan"], "cotone + elastan")
check(multilingual.share(of: FiberCatalog.fiber(id: "elastan")!) == 5, "elastane share")

let sectioned = CompositionParser.parse("ESTERNO: 100% POLIESTERE - FODERA: 100% VISCOSA")
check(sectioned.sections.count == 2, "shell and lining are separate sections")
check(sectioned.sections.first?.name == "Esterno", "shell named")
check(sectioned.sections.last?.name == "Fodera", "lining named")
check(sectioned.fibers.count == 2, "both fibres kept")

let noisy = CompositionParser.parse("MADE IN PORTUGAL\nART. 4521/B\n70% VISCOSA 30% LINO\nTAGLIA 46")
check(noisy.allParts.count == 2, "article numbers and sizes are not fibres")
check(noisy.fibers.map(\.id).sorted() == ["lino", "viscosa"], "viscosa + lino")

check(CompositionParser.parse("Nessuna percentuale qui").isEmpty, "no percentages, no composition")

// MARK: - Instructions written in words

section("CareTextHints")
let hints = CareTextHints.hints(in: "Lavare a mano. Non candeggiare. Non stirare. Non asciugare in asciugatrice.")
let hintIDs = Set(hints.map(\.symbol.id))
check(hintIDs.contains("wash-hand"), "hand wash")
check(hintIDs.contains("bleach-none"), "do not bleach")
check(hintIDs.contains("iron-none"), "do not iron")
check(hintIDs.contains("tumble-none"), "do not tumble dry")
check(CareTextHints.hints(in: "Machine wash 30").first?.symbol.id == "wash-30", "temperature in words")
check(CareTextHints.hints(in: "Taglia 40").isEmpty, "a size is not a wash temperature")

// MARK: - Symbol lookup

section("CareSymbolCatalog")
check(CareSymbolCatalog.match(GlyphSpec(base: .washtub, text: "30", bars: 1))?.id == "wash-30-1", "30 °C, one bar")
check(CareSymbolCatalog.match(GlyphSpec(base: .triangle, crossed: true))?.id == "bleach-none", "crossed triangle")
check(CareSymbolCatalog.match(GlyphSpec(base: .iron, dots: 2))?.id == "iron-2", "two-dot iron")
check(CareSymbolCatalog.match(GlyphSpec(base: .square, crossed: true, inner: .tumbleCircle))?.id == "tumble-none", "no tumble dry")
check(CareSymbolCatalog.match(GlyphSpec(base: .circle, text: "P"))?.id == "pro-P", "dry clean P")
check(CareSymbolCatalog.washTemperature(forDots: 4) == 60, "four dots is 60 °C")
check(CareSymbolCatalog.all.allSatisfy { !$0.meaning.isEmpty }, "every symbol explains itself")
check(Set(CareSymbolCatalog.all.map(\.id)).count == CareSymbolCatalog.all.count, "symbol ids are unique")
check(Set(FiberCatalog.all.map(\.id)).count == FiberCatalog.all.count, "fibre ids are unique")

// MARK: - The advice itself

section("WashPlanBuilder")
func reading(_ text: String, _ symbolIDs: [String] = []) -> LabelReading {
    LabelReading(
        composition: CompositionParser.parse(text),
        symbols: symbolIDs.compactMap { CareSymbolCatalog.symbol(id: $0) }
            .map { DetectedSymbol(symbol: $0, confidence: 0.9, source: .immagine, box: nil) },
        rawText: text)
}

let wool = WashPlanBuilder.build(from: reading("100% LANA"))
check(wool.headline.contains("30 °C"), "wool washes at 30: \(wool.headline)")
check(wool.headline.contains("lana"), "wool programme")
check(wool.rows.contains { $0.title == "Asciugatura" && $0.detail.contains("Niente asciugatrice") }, "wool never goes in the dryer")

let stretchJeans = WashPlanBuilder.build(from: reading("98% COTONE 2% ELASTAN", ["wash-40", "tumble-none", "iron-2"]))
check(stretchJeans.headline.contains("40 °C"), "label temperature wins: \(stretchJeans.headline)")
check(stretchJeans.warnings.first?.contains("2%") == true, "the 2% elastane leads the warnings")
check(stretchJeans.rows.contains { $0.title == "Stiratura" && $0.detail.contains("150") }, "two-dot iron")

let conflict = WashPlanBuilder.build(from: reading("60% VISCOSA 40% COTONE", ["wash-60"]))
check(conflict.warnings.contains { $0.contains("60 °C") && $0.contains("30 °C") }, "flags a label that is kinder to the machine than to the fibre")

let woolByHand = WashPlanBuilder.build(from: reading("100% LANA", ["wash-hand"]))
check(woolByHand.headline == "A mano, acqua a 30 °C", "the hand-wash symbol implies 40 °C, the wool says 30: \(woolByHand.headline)")

let dryCleanOnly = WashPlanBuilder.build(from: reading("100% SETA", ["wash-none", "pro-P"]))
check(dryCleanOnly.headline == "Non lavarlo in acqua", "do-not-wash wins")
check(dryCleanOnly.rows.contains { $0.title == "Lavanderia" }, "sends it to the cleaner")

let nothing = WashPlanBuilder.build(from: reading(""))
check(nothing.rows.count >= 4, "still produces a cautious plan")
check(nothing.basis.contains("default"), "and says it is a default")

let facts = WashPlanBuilder.facts(from: reading("95% COTONE 5% ELASTAN", ["wash-30-1"]))
check(facts.contains("95% Cotone") && facts.contains("Lavaggio"), "digest for the on-device model")

// MARK: - Reading the drawings back out of a picture

section("SymbolDetector")

func detect(_ specs: [GlyphSpec], noise: Bool = false) -> [DetectedSymbol] {
    let sheet = GlyphRasterizer.sheet(specs, noise: noise)
    let size = CGSize(width: sheet.image.width, height: sheet.image.height)
    // Stands in for Vision: whatever text the symbol was drawn with.
    let reader: SymbolDetector.TextReader = { _, region in
        let centre = CGPoint(x: region.midX * size.width, y: region.midY * size.height)
        for (index, box) in sheet.boxes.enumerated() where box.contains(centre) {
            return sheet.specs[index].text
        }
        return nil
    }
    return SymbolDetector.detect(in: sheet.image, readText: reader).symbols
}

let row: [GlyphSpec] = [
    GlyphSpec(base: .washtub, text: "30", bars: 1),
    GlyphSpec(base: .triangle, crossed: true),
    GlyphSpec(base: .square, dots: 1, inner: .tumbleCircle),
    GlyphSpec(base: .iron, dots: 2),
    GlyphSpec(base: .circle, text: "P"),
]
let readBack = detect(row)
let ids = readBack.map(\.symbol.id)
print("     read: \(ids)")
check(ids == ["wash-30-1", "bleach-none", "tumble-low", "iron-2", "pro-P"], "a whole row of symbols")
print("     confidence: " + readBack.map { "\($0.symbol.id)=\(String(format: "%.2f", $0.confidence))" }.joined(separator: " "))
check(readBack.allSatisfy { $0.confidence > 0.5 }, "confident about a clean print")

let shapesOnly = detect([
    GlyphSpec(base: .washtub, text: "40"),
    GlyphSpec(base: .triangle),
    GlyphSpec(base: .square, inner: .lineHorizontal),
    GlyphSpec(base: .iron, crossed: true),
    GlyphSpec(base: .circle, crossed: true),
]).map(\.symbol.id)
print("     read: \(shapesOnly)")
check(shapesOnly == ["wash-40", "bleach-any", "dry-flat", "iron-none", "pro-none"], "outlines and prohibitions")

let variants = detect([
    GlyphSpec(base: .washtub, inner: .hand),
    GlyphSpec(base: .washtub, dots: 2),
    GlyphSpec(base: .square, inner: .lineVerticalDouble),
    GlyphSpec(base: .square, crossed: true, inner: .tumbleCircle),
    GlyphSpec(base: .iron, dots: 1),
    GlyphSpec(base: .circle, text: "W", bars: 1),
]).map(\.symbol.id)
print("     read: \(variants)")
check(variants == ["wash-hand", "wash-40", "dry-drip", "tumble-none", "iron-1", "pro-W-mild"], "hand, pallini, lines, bars")

let grainy = detect(row, noise: true).map(\.symbol.id)
print("     read: \(grainy)")
check(grainy == ["wash-30-1", "bleach-none", "tumble-low", "iron-2", "pro-P"], "still readable through grain")

for degrees in [-9.0, 5.0, 12.0] {
    let sheet = GlyphRasterizer.sheet(row)
    let tilted = GlyphRasterizer.tilt(sheet.image, degrees: degrees)
    let reader: SymbolDetector.TextReader = { _, region in
        let index = Int(region.midX * CGFloat(row.count))
        return index >= 0 && index < row.count ? row[index].text : nil
    }
    let ids = SymbolDetector.detect(in: tilted, readText: reader).symbols.map(\.symbol.id)
    check(ids == ["wash-30-1", "bleach-none", "tumble-low", "iron-2", "pro-P"],
          "straightens a label shot \(Int(degrees))° off level")
}

let printed = GlyphRasterizer.labelSheet(
    text: ["95% COTONE  5% ELASTAN",
           "95% COTTON  5% ELASTANE",
           "95% BAUMWOLLE  5% ELASTHAN",
           "MADE IN PORTUGAL   ART. 4521/B"],
    specs: row)
let printedSize = CGSize(width: printed.image.width, height: printed.image.height)
let printedIDs = SymbolDetector.detect(in: printed.image, readText: { _, region in
    let centre = CGPoint(x: region.midX * printedSize.width, y: region.midY * printedSize.height)
    for (index, box) in printed.boxes.enumerated() where box.contains(centre) { return printed.specs[index].text }
    return nil
}).symbols.map(\.symbol.id)
print("     read: \(printedIDs)")
check(printedIDs == ["wash-30-1", "bleach-none", "tumble-low", "iron-2", "pro-P"],
      "the letters of a printed label are not mistaken for symbols")

var unread: [String] = []
for symbol in CareSymbolCatalog.all {
    let sheet = GlyphRasterizer.sheet([symbol.glyph])
    let reader: SymbolDetector.TextReader = { _, _ in symbol.glyph.text }
    let got = SymbolDetector.detect(in: sheet.image, readText: reader).symbols
    if got.first?.symbol.id != symbol.id {
        unread.append("\(symbol.id) → \(got.map(\.symbol.id).joined(separator: "/"))")
    }
}
if !unread.isEmpty { print("     " + unread.joined(separator: ", ")) }
check(unread.isEmpty, "every symbol in the catalogue reads back as itself (\(CareSymbolCatalog.all.count))")

check(SymbolDetector.detect(in: GlyphRasterizer.sheet([]).image).symbols.isEmpty, "blank paper, no symbols")

print("\n\(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")")
exit(failures == 0 ? 0 : 1)
