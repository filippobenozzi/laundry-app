import SwiftUI

/// For a label that has fallen off, or writing that no camera will ever read.
struct ManualReadingView: View {
    @State private var text = ""
    @State private var chosen: [CareSymbol] = []
    @State private var showPicker = false

    private var reading: LabelReading {
        LabelReading(
            composition: CompositionParser.parse(text),
            symbols: chosen.map { DetectedSymbol(symbol: $0, confidence: 1, source: .manuale, box: nil) },
            rawText: text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.blockSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Composizione")
                    TextField("es. 80% cotone 20% poliestere", text: $text, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...5)
                        .padding(14)
                        .background(Theme.well)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    if !reading.composition.isEmpty {
                        Text(reading.composition.allParts.map(\.displayName).joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionLabel(text: "Simboli")
                        Spacer()
                        Button { showPicker = true } label: {
                            Label("Aggiungi", systemImage: "plus").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    if chosen.isEmpty {
                        Text("Facoltativi: senza simboli il consiglio si basa solo sulle fibre.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(chosen) { symbol in
                                HStack {
                                    CareSymbolRow(symbol: symbol)
                                    Button {
                                        chosen.removeAll { $0.id == symbol.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.muted)
                                            .frame(width: 32, height: 32)
                                    }
                                }
                                .padding(.vertical, 10)
                                if symbol.id != chosen.last?.id { Hairline() }
                            }
                        }
                    }
                }

                NavigationLink {
                    ResultView(outcome: ScanOutcome(reading: reading, image: nil))
                } label: {
                    Text("Vedi il consiglio")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.ink))
                }
                .disabled(reading.isEmpty)
                .opacity(reading.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .navigationTitle("A mano")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            SymbolPickerView(replacing: nil) { symbol in
                chosen.removeAll { $0.family == symbol.family }
                chosen.append(symbol)
                chosen.sort { CareFamily.allCases.firstIndex(of: $0.family)! < CareFamily.allCases.firstIndex(of: $1.family)! }
            }
        }
    }
}
