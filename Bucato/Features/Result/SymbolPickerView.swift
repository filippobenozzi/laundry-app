import SwiftUI

/// The whole alphabet, to pick from when the photo was not enough.
struct SymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var replacing: CareSymbol?
    var onPick: (CareSymbol) -> Void

    @State private var family: CareFamily

    init(replacing: CareSymbol?, onPick: @escaping (CareSymbol) -> Void) {
        self.replacing = replacing
        self.onPick = onPick
        _family = State(initialValue: replacing?.family ?? .lavaggio)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Famiglia", selection: $family) {
                    ForEach(CareFamily.allCases, id: \.self) { family in
                        Text(shortTitle(family)).tag(family)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(CareSymbolCatalog.family(family)) { symbol in
                            Button {
                                onPick(symbol)
                                dismiss()
                            } label: {
                                CareSymbolRow(symbol: symbol, compact: true)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Hairline()
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                }
            }
            .background(Theme.paper)
            .navigationTitle(replacing == nil ? "Aggiungi simbolo" : "Sostituisci")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }

    private func shortTitle(_ family: CareFamily) -> String {
        switch family {
        case .lavaggio: return "Lava"
        case .candeggio: return "Sbianca"
        case .asciugatura: return "Asciuga"
        case .stiratura: return "Stira"
        case .professionale: return "Secco"
        }
    }
}
