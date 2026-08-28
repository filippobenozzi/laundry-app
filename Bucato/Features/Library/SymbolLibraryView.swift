import SwiftUI

struct SymbolLibraryView: View {
    @State private var query = ""

    private var families: [(family: CareFamily, symbols: [CareSymbol])] {
        CareFamily.allCases.compactMap { family in
            let symbols = CareSymbolCatalog.family(family).filter(matches)
            return symbols.isEmpty ? nil : (family, symbols)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.blockSpacing, pinnedViews: []) {
                    ForEach(families, id: \.family) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(text: group.family.title)
                                Text(group.family.shapeMeaning)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(spacing: 0) {
                                ForEach(group.symbols) { symbol in
                                    NavigationLink { SymbolDetailView(symbol: symbol) } label: {
                                        CareSymbolRow(symbol: symbol)
                                            .padding(.vertical, 12)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if symbol.id != group.symbols.last?.id { Hairline() }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .background(Theme.paper)
            .navigationTitle("Simboli")
            .searchable(text: $query, prompt: "Cerca un simbolo")
        }
    }

    private func matches(_ symbol: CareSymbol) -> Bool {
        guard !query.isEmpty else { return true }
        let needle = FiberCatalog.normalize(query)
        return FiberCatalog.normalize(symbol.title).contains(needle)
            || FiberCatalog.normalize(symbol.meaning).contains(needle)
    }
}

struct SymbolDetailView: View {
    let symbol: CareSymbol

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.blockSpacing) {
                HStack {
                    Spacer()
                    CareGlyphView(spec: symbol.glyph, size: 132)
                    Spacer()
                }
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text(symbol.title)
                        .font(.title2.weight(.semibold))
                    Text(symbol.meaning)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let tip = symbol.tip {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "In pratica")
                        Text(tip)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.well)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "La famiglia")
                    Text(symbol.family.shapeMeaning)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 40)
        }
        .background(Theme.paper)
        .navigationTitle(symbol.family.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
