import PhotosUI
import SwiftData
import SwiftUI

/// What Bucato hands back after reading a label, on its way to the result screen.
struct ScanOutcome: Identifiable, Hashable {
    let id = UUID()
    var reading: LabelReading
    var image: UIImage?

    static func == (lhs: ScanOutcome, rhs: ScanOutcome) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedGarment.createdAt, order: .reverse) private var garments: [SavedGarment]

    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReading = false
    @State private var outcome: ScanOutcome?
    @State private var showSettings = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.blockSpacing) {
                    intro
                    actions
                    if !garments.isEmpty { wardrobe }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .background(Theme.paper)
            .navigationTitle("Bucato")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Impostazioni")
                }
            }
            .navigationDestination(item: $outcome) { outcome in
                ResultView(outcome: outcome)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(
                    onFinish: { image in
                        showScanner = false
                        read(image)
                    },
                    onCancel: { showScanner = false })
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    defer { photoItem = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    read(image)
                }
            }
            .overlay { if isReading { readingOverlay } }
            .alert("Non ci sono riuscito", isPresented: .init(
                get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("Va bene", role: .cancel) { failure = nil }
            } message: {
                Text(failure ?? "")
            }
        }
    }

    // MARK: - Pieces

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inquadra l'etichetta.")
                .font(.title2.weight(.semibold))
            Text("Bucato legge la composizione e i simboli, spiega che fibre sono e ti dice come lavare il capo senza rovinarlo. Tutto sul telefono: le foto non escono da qui.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                showScanner = true
            } label: {
                Label("Inquadra l'etichetta", systemImage: "camera")
            }
            .buttonStyle(InkButtonStyle())

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label("Scegli una foto", systemImage: "photo.on.rectangle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1))
            }

            NavigationLink {
                ManualReadingView()
            } label: {
                Text("Nessuna etichetta? Componila a mano")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 2)
        }
    }

    private var wardrobe: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Armadio")
            VStack(spacing: 0) {
                ForEach(garments) { garment in
                    NavigationLink {
                        ResultView(garment: garment)
                    } label: {
                        GarmentRow(garment: garment)
                    }
                    .buttonStyle(.plain)
                    if garment.id != garments.last?.id { Hairline() }
                }
            }
        }
    }

    private var readingOverlay: some View {
        ZStack {
            Theme.paper.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text("Leggo l'etichetta…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Reading

    private func read(_ image: UIImage) {
        isReading = true
        Task {
            guard let analysis = await LabelAnalyzer.analyze(image) else {
                isReading = false
                failure = "Non sono riuscito ad aprire questa immagine."
                return
            }
            isReading = false
            if analysis.reading.isEmpty {
                Haptics.warning()
                failure = "Non ho letto né composizione né simboli. Riprova più da vicino, con l'etichetta ben illuminata e distesa."
                return
            }
            Haptics.success()
            outcome = ScanOutcome(reading: analysis.reading, image: UIImage(cgImage: analysis.image))
        }
    }
}

struct GarmentRow: View {
    let garment: SavedGarment

    var body: some View {
        HStack(spacing: 14) {
            if let data = garment.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.well)
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "tshirt").foregroundStyle(Theme.muted))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(garment.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(garment.plan.headline)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted.opacity(0.6))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
