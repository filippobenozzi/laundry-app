import SwiftData
import SwiftUI

/// Everything read off one label, and what to do about it.
struct ResultView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useAppleIntelligence") private var useAppleIntelligence = true

    @State private var reading: LabelReading
    @State private var image: UIImage?
    @State private var note: String?
    @State private var isWritingNote = false
    @State private var showPicker = false
    @State private var replacing: DetectedSymbol?
    @State private var showSaveDialog = false
    @State private var name = ""
    @State private var savedName: String?
    /// Asked once: whether the model is there does not change while a label is open.
    @State private var canWriteNote = OnDeviceAdvisor.isReady

    private let garment: SavedGarment?

    init(outcome: ScanOutcome) {
        _reading = State(initialValue: outcome.reading)
        _image = State(initialValue: outcome.image)
        garment = nil
    }

    init(garment: SavedGarment) {
        _reading = State(initialValue: garment.reading)
        _image = State(initialValue: garment.photo.flatMap(UIImage.init(data:)))
        self.garment = garment
    }

    private var plan: WashPlan { WashPlanBuilder.build(from: reading) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.blockSpacing) {
                header
                if let image { photo(image) }
                composition
                symbols
                instructions
                if !plan.warnings.isEmpty { warnings }
                if useAppleIntelligence, canWriteNote { intelligence }
                footer
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 44)
        }
        .background(Theme.paper)
        .navigationTitle(garment?.name ?? savedName ?? "Etichetta")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            SymbolPickerView(replacing: replacing?.symbol) { chosen in
                add(chosen)
            }
        }
        .alert("Salva nell'armadio", isPresented: $showSaveDialog) {
            TextField("Nome del capo", text: $name)
            Button("Salva") { save() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Un nome che riconosci: \"maglione grigio\", \"camicia di lino\".")
        }
        .task(id: taskKey) { await writeNote() }
    }

    // MARK: - Blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.headline)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(plan.basis)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 8)
    }

    private func photo(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 190)
            .frame(maxWidth: .infinity)
            .background(Theme.well)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var composition: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Composizione")
            if reading.composition.isEmpty {
                Text("Nessuna percentuale letta sull'etichetta.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(reading.composition.sections) { section in
                    if let name = section.name {
                        Text(name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                    }
                    VStack(spacing: 0) {
                        ForEach(section.parts) { part in
                            partRow(part)
                            if part.id != section.parts.last?.id { Hairline() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func partRow(_ part: CompositionPart) -> some View {
        if let fiber = part.fiber {
            NavigationLink { FiberDetailView(fiber: fiber) } label: {
                partLabel(part, fiber: fiber)
            }
            .buttonStyle(.plain)
        } else {
            partLabel(part, fiber: nil)
        }
    }

    private func partLabel(_ part: CompositionPart, fiber: Fiber?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(part.percentage.map { "\($0)%" } ?? "—")
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(part.displayName)
                        .font(.body.weight(.medium))
                    if let fiber {
                        Text(fiber.family.label.lowercased())
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Text(fiber?.summary ?? "Fibra non riconosciuta: controlla la scritta sull'etichetta.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if fiber != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted.opacity(0.5))
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var symbols: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "Simboli")
                Spacer()
                Button {
                    replacing = nil
                    showPicker = true
                } label: {
                    Label("Aggiungi", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.ink)
            }

            if reading.symbols.isEmpty {
                Text("Nessun simbolo riconosciuto. Aggiungili a mano: sono cinque al massimo, uno per famiglia.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(reading.symbols) { detected in
                        symbolRow(detected)
                        if detected.id != reading.symbols.last?.id { Hairline() }
                    }
                }
            }
        }
    }

    private func symbolRow(_ detected: DetectedSymbol) -> some View {
        HStack(alignment: .top, spacing: 4) {
            NavigationLink { SymbolDetailView(symbol: detected.symbol) } label: {
                CareSymbolRow(symbol: detected.symbol,
                              footnote: detected.isUncertain ? "Da confermare — \(detected.source.label)" : detected.source.label)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    replacing = detected
                    showPicker = true
                } label: { Label("Sostituisci", systemImage: "arrow.triangle.2.circlepath") }
                Button(role: .destructive) {
                    reading.symbols.removeAll { $0.id == detected.id }
                } label: { Label("Togli", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 12)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Come lavarlo")
            VStack(spacing: 0) {
                ForEach(plan.rows) { row in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: row.icon)
                            .font(.body)
                            .frame(width: 24, height: 22)
                            .foregroundStyle(Theme.ink)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title)
                                .font(.body.weight(.medium))
                            Text(row.detail)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    if row.id != plan.rows.last?.id { Hairline() }
                }
            }
        }
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Attenzione")
            ForEach(Array(plan.warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: 10) {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    Text(warning)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.well)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var intelligence: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "In due parole")
            if let note {
                Text(note)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isWritingNote {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Ci sto pensando…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Text(plan.summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(note == nil ? "Riassunto dell'app." : "Scritto sul telefono da Apple Intelligence, a partire da quello che c'è qui sopra.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let garment {
                Button(role: .destructive) {
                    context.delete(garment)
                    dismiss()
                } label: {
                    Text("Togli dall'armadio")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
            } else if savedName == nil {
                Button {
                    name = suggestedName
                    showSaveDialog = true
                } label: {
                    Label("Salva nell'armadio", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(InkButtonStyle())
            } else {
                Label("Salvato", systemImage: "checkmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
        }
    }

    // MARK: - Actions

    private var suggestedName: String {
        reading.composition.fibers.first?.name ?? "Capo"
    }

    private var taskKey: String {
        reading.symbols.map(\.symbol.id).joined() + reading.composition.allParts.map(\.displayName).joined()
    }

    private func add(_ symbol: CareSymbol) {
        if let replacing {
            reading.symbols.removeAll { $0.id == replacing.id }
            self.replacing = nil
        }
        // One instruction per family: a new one replaces whatever was there.
        reading.symbols.removeAll { $0.symbol.family == symbol.family }
        reading.symbols.append(DetectedSymbol(symbol: symbol, confidence: 1, source: .manuale, box: nil))
        reading.symbols.sort { first, second in
            let order = CareFamily.allCases
            return order.firstIndex(of: first.symbol.family)! < order.firstIndex(of: second.symbol.family)!
        }
        Haptics.tap()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? suggestedName : trimmed
        let data = image?.jpegData(compressionQuality: 0.6)
        context.insert(SavedGarment(name: finalName,
                                    rawText: storedText,
                                    symbolIDs: reading.symbols.map(\.symbol.id),
                                    photo: data))
        savedName = finalName
        Haptics.success()
    }

    /// Saving the composition as text keeps the entry readable and lets a future
    /// version of the parser make more of it.
    private var storedText: String {
        if !reading.composition.isEmpty {
            return reading.composition.sections.map { section in
                let parts = section.parts.map { "\($0.percentage.map { "\($0)% " } ?? "")\($0.displayName)" }
                return (section.name.map { "\($0): " } ?? "") + parts.joined(separator: " ")
            }.joined(separator: "\n")
        }
        return reading.rawText
    }

    private func writeNote() async {
        note = nil
        guard useAppleIntelligence, canWriteNote, !reading.isEmpty else { return }
        isWritingNote = true
        let written = await OnDeviceAdvisor.note(for: reading, plan: plan)
        isWritingNote = false
        note = written
    }
}
