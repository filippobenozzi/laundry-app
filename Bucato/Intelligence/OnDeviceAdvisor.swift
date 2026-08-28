import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The rule engine already produces the plan; this only rewrites it the way a
/// person would say it out loud. It runs entirely on the phone, on iPhones that
/// have Apple Intelligence, and the app works exactly the same without it.
enum OnDeviceAdvisor {

    enum Availability: Equatable {
        case ready
        case systemTooOld
        case deviceNotEligible
        case notEnabled
        case modelNotReady

        var explanation: String {
            switch self {
            case .ready: return "Attivo: il consiglio in fondo alla scheda è scritto sul telefono da Apple Intelligence."
            case .systemTooOld: return "Serve iOS 26 o successivo."
            case .deviceNotEligible: return "Questo iPhone non supporta Apple Intelligence."
            case .notEnabled: return "Attiva Apple Intelligence in Impostazioni per avere anche il commento scritto."
            case .modelNotReady: return "Il modello si sta ancora scaricando: riprova tra un po'."
            }
        }
    }

    static var availability: Availability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .systemTooOld }
        switch SystemLanguageModel.default.availability {
        case .available: return .ready
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
        case .unavailable(.modelNotReady): return .modelNotReady
        case .unavailable: return .modelNotReady
        }
        #else
        return .systemTooOld
        #endif
    }

    static var isReady: Bool { availability == .ready }

    /// Three short sentences about this specific garment, or nil if the model is
    /// unavailable, refuses, or takes too long.
    static func note(for reading: LabelReading, plan: WashPlan) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), isReady else { return nil }
        return await generate(reading: reading, plan: plan)
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generate(reading: LabelReading, plan: WashPlan) async -> String? {
        let session = LanguageModelSession(instructions: """
        Sei un esperto di lavanderia domestica. Ricevi la lettura di un'etichetta e il \
        programma di lavaggio già deciso dall'app. Il tuo compito è solo spiegarlo a voce \
        di persona, in italiano, con frasi brevi e concrete.

        Regole ferree:
        - Non cambiare mai temperature, programmi o divieti: sono già stati decisi.
        - Non inventare fibre o simboli che non ti sono stati passati.
        - Niente elenchi puntati, niente emoji, niente formule di cortesia.
        - Dai del tu. Massimo venticinque parole per campo.
        """)

        let prompt = """
        Etichetta letta:
        \(WashPlanBuilder.facts(from: reading))

        Programma deciso dall'app:
        \(plan.headline)
        \(plan.rows.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n"))
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GarmentNote.self,
                options: GenerationOptions(temperature: 0.4, maximumResponseTokens: 320))
            return response.content.paragraph
        } catch {
            return nil
        }
    }

    #endif
}

#if canImport(FoundationModels)
/// The shape Apple Intelligence has to fill in. Three sentences, no more.
@available(iOS 26.0, *)
@Generable
struct GarmentNote {
    @Guide(description: "Come lavare il capo, una frase, in italiano.")
    var lavaggio: String

    @Guide(description: "L'errore più facile da commettere con questo capo, una frase.")
    var errore: String

    @Guide(description: "Un accorgimento pratico in più, una frase.")
    var accorgimento: String

    var paragraph: String {
        [lavaggio, errore, accorgimento]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
#endif
