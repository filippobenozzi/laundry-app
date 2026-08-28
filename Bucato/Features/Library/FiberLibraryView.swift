import SwiftUI

struct FiberLibraryView: View {
    @State private var query = ""

    private var families: [(family: FiberFamily, fibers: [Fiber])] {
        FiberFamily.allCases.compactMap { family in
            let fibers = FiberCatalog.all.filter { $0.family == family && matches($0) }
            return fibers.isEmpty ? nil : (family, fibers)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.blockSpacing) {
                    ForEach(families, id: \.family) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: group.family.label)
                            VStack(spacing: 0) {
                                ForEach(group.fibers) { fiber in
                                    NavigationLink { FiberDetailView(fiber: fiber) } label: {
                                        row(fiber)
                                    }
                                    .buttonStyle(.plain)
                                    if fiber.id != group.fibers.last?.id { Hairline() }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .background(Theme.paper)
            .navigationTitle("Fibre")
            .searchable(text: $query, prompt: "Cerca una fibra")
        }
    }

    private func row(_ fiber: Fiber) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fiber.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(fiber.care.handWashOnly ? "a mano" : "\(fiber.care.maxWashC) °C")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted.opacity(0.5))
            }
            Text(fiber.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func matches(_ fiber: Fiber) -> Bool {
        guard !query.isEmpty else { return true }
        let needle = FiberCatalog.normalize(query)
        return FiberCatalog.normalize(fiber.name).contains(needle)
            || fiber.aliases.contains { FiberCatalog.normalize($0).contains(needle) }
    }
}

struct FiberDetailView: View {
    let fiber: Fiber

    private var care: FiberCare { fiber.care }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.blockSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(fiber.family.label)
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted)
                    Text(fiber.name)
                        .font(.title.weight(.semibold))
                    Text(fiber.summary)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Da sola, questa fibra")
                    VStack(spacing: 0) {
                        line("Lavaggio", care.handWashOnly
                             ? "solo a mano, fino a \(care.maxWashC) °C"
                             : (care.maxWashC == 0 ? "non lavare in acqua" : "fino a \(care.maxWashC) °C"))
                        Hairline()
                        line("Centrifuga", care.spin.label)
                        Hairline()
                        line("Asciugatrice", care.tumble == .forbidden ? "no"
                             : (care.tumble == .low ? "sì, a bassa temperatura" : "sì"))
                        Hairline()
                        line("Ferro", ironText)
                        Hairline()
                        line("Candeggio", care.bleachable ? "tollerato sul bianco" : "no")
                        Hairline()
                        line("Detersivo", care.detergent.label)
                    }
                }

                if !care.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Cosa va storto")
                        ForEach(Array(care.warnings.enumerated()), id: \.offset) { _, warning in
                            HStack(alignment: .top, spacing: 10) {
                                Text("—").foregroundStyle(Theme.muted)
                                Text(warning).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.well)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Sull'etichetta la trovi come")
                    Text(fiber.aliases.prefix(8).map { $0.capitalized }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 40)
        }
        .background(Theme.paper)
        .navigationTitle(fiber.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ironText: String {
        switch care.ironDots {
        case 0: return "no"
        case 1: return "tiepido, max 110 °C"
        case 2: return "medio, max 150 °C"
        default: return "caldo, fino a 200 °C"
        }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
    }
}
