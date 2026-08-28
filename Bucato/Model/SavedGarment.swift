import Foundation
import SwiftData

/// A garment kept in the wardrobe. Only the reading is stored — the plan is
/// recomputed on the spot, so improving the advice improves old entries too.
@Model
final class SavedGarment {
    var name: String = ""
    var createdAt: Date = Date()
    var rawText: String = ""
    var symbolIDs: [String] = []
    @Attribute(.externalStorage) var photo: Data?

    init(name: String, rawText: String, symbolIDs: [String], photo: Data?, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
        self.rawText = rawText
        self.symbolIDs = symbolIDs
        self.photo = photo
    }

    var reading: LabelReading {
        LabelReading(
            composition: CompositionParser.parse(rawText),
            symbols: symbolIDs.compactMap(CareSymbolCatalog.symbol(id:))
                .map { DetectedSymbol(symbol: $0, confidence: 1, source: .salvato, box: nil) },
            rawText: rawText)
    }

    var plan: WashPlan { WashPlanBuilder.build(from: reading) }
}
