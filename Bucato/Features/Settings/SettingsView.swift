import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useAppleIntelligence") private var useAppleIntelligence = true

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.blockSpacing) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Apple Intelligence")
                        Toggle("Commento scritto dal telefono", isOn: $useAppleIntelligence)
                            .tint(Theme.ink)
                            .disabled(!OnDeviceAdvisor.isReady)
                        Text(OnDeviceAdvisor.availability.explanation)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Il consiglio vero e proprio non dipende da questo: temperature, programmi e divieti li decide l'app da sola, con regole scritte a mano.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Privacy")
                        Text("Le foto vengono lette sul dispositivo e non vengono salvate da nessuna parte, se non nell'armadio quando sei tu a chiederlo. Nessun account, nessuna rete, nessun tracciamento.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Bucato")
                        Text("I simboli seguono la norma ISO 3758, quella usata sulle etichette europee. Restano un'indicazione: se un capo è prezioso, in caso di dubbio vince sempre il trattamento più delicato.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Link("Codice sorgente su GitHub", destination: URL(string: "https://github.com/filippobenozzi/laundry-app")!)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        Text("Versione \(version)")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 12)
            }
            .background(Theme.paper)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }
}
