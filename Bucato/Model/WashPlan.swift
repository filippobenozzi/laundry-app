import Foundation

struct PlanRow: Identifiable, Sendable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

/// The answer to "come lo lavo?": a handful of lines, in the order in which the
/// laundry actually happens.
struct WashPlan: Sendable {
    var headline: String
    var rows: [PlanRow]
    var warnings: [String]
    var summary: String
    /// Says out loud how much of this came from the label and how much from the
    /// fibres, so nobody mistakes a guess for an instruction.
    var basis: String
}

enum WashPlanBuilder {

    static func build(from reading: LabelReading) -> WashPlan {
        let effects = reading.bestPerFamily.map(\.symbol.effect)
        let fibers = reading.composition.fibers
        let cares = fibers.map(\.care)

        // MARK: washing

        let doNotWash = effects.contains(where: \.doNotWash)
        let printedTemp = effects.filter { !$0.temperatureIsImplied }.compactMap(\.maxWashC).min()
        let impliedTemp = effects.filter(\.temperatureIsImplied).compactMap(\.maxWashC).min()
        let fiberTemp = cares.map(\.maxWashC).min()
        // A number printed on the label is an instruction; the ceiling a symbol
        // merely implies still has to make room for the fibre.
        let symbolTemp = printedTemp ?? [impliedTemp, fiberTemp].compactMap { $0 }.min()
        let handWash = effects.contains(where: \.handWashOnly) || (fiberTemp != nil && cares.allSatisfy(\.handWashOnly))
        let temperature = symbolTemp ?? fiberTemp
        let spin = ([effects.compactMap(\.spin).min(), cares.map(\.spin).min()].compactMap { $0 }).min() ?? .full
        let detergent = ([effects.compactMap(\.detergent).max(), cares.map(\.detergent).max()].compactMap { $0 }).max() ?? .standard

        var rows: [PlanRow] = []
        var warnings: [String] = []
        let headline: String

        if doNotWash {
            headline = "Non lavarlo in acqua"
            rows.append(PlanRow(icon: "drop.triangle", title: "Lavaggio",
                                detail: "Vietato: né lavatrice né a mano."))
        } else if handWash {
            let celsius = temperature ?? 30
            headline = "A mano, acqua a \(celsius) °C"
            rows.append(PlanRow(icon: "hand.raised", title: "A mano",
                                detail: "Acqua fino a \(celsius) °C, \(detergent.label). Cinque minuti in ammollo, senza strofinare né torcere."))
        } else if let celsius = temperature {
            let program = programName(temperature: celsius, effects: effects, fibers: fibers, detergent: detergent)
            headline = "Lavatrice a \(celsius) °C, \(program)"
            rows.append(PlanRow(icon: "washer", title: "Lavatrice",
                                detail: "Massimo \(celsius) °C, \(program), \(spin.label), \(detergent.label)."))
        } else {
            headline = "Serve almeno un dato dall'etichetta"
            rows.append(PlanRow(icon: "questionmark.circle", title: "Lavaggio",
                                detail: "Senza composizione né simbolo di lavaggio conviene andare sul sicuro: 30 °C, ciclo delicato."))
        }

        // The label is the manufacturer's promise, the fibres are physics. When they
        // disagree, say so instead of silently picking one.
        if let symbolTemp = printedTemp, let fiberTemp, fiberTemp < symbolTemp,
           let strictest = fibers.filter({ $0.care.maxWashC == fiberTemp }).first {
            let share = reading.composition.share(of: strictest).map { "\($0)% di " } ?? ""
            warnings.append("L'etichetta arriva a \(symbolTemp) °C, ma con \(share)\(strictest.name.lowercased()) conviene fermarsi a \(fiberTemp) °C.")
        }

        // MARK: bleaching

        let bleachAllowed = effects.compactMap(\.bleachable).first ?? cares.allSatisfy(\.bleachable)
        let oxygenOnly = effects.contains(where: \.oxygenBleachOnly)
        rows.append(PlanRow(
            icon: "sparkles",
            title: "Candeggio",
            detail: bleachAllowed
                ? (oxygenOnly ? "Solo smacchiatori all'ossigeno, mai cloro." : "Consentito, ma usalo solo sul bianco e diluito.")
                : "Vietato, cloro e ossigeno compresi. Attenzione ai detersivi \"per bianchi\"."))

        // MARK: drying

        let symbolTumble = effects.compactMap(\.tumble).min()
        let fiberTumble = cares.map(\.tumble).min()
        let tumble = symbolTumble ?? fiberTumble ?? .normal
        if let symbolTumble, let fiberTumble, fiberTumble < symbolTumble,
           let strictest = fibers.first(where: { $0.care.tumble == fiberTumble }) {
            warnings.append("L'etichetta ammette l'asciugatrice, ma \(strictest.name.lowercased()) non la regge: stendilo all'aria.")
        }
        let method = effects.compactMap(\.dryMethod).first(where: { $0 != .tumble })
        let inShade = effects.contains(where: \.dryInShade)
        var dryDetail: String
        switch tumble {
        case .forbidden:
            dryDetail = "Niente asciugatrice. "
        case .low:
            dryDetail = "Asciugatrice a bassa temperatura, meglio togliendolo ancora umido. "
        case .normal:
            dryDetail = "Asciugatrice consentita. "
        }
        switch method {
        case .piano: dryDetail += "Stendilo in piano, dandogli la forma da bagnato."
        case .gocciolare: dryDetail += "Appendilo bagnato, senza strizzarlo."
        case .filo: dryDetail += "Appendilo su un filo."
        case .tumble, .none:
            if tumble == .forbidden {
                dryDetail += fibers.contains(where: { $0.family == .animale })
                    ? "Stendilo in piano: appeso si allunga."
                    : "Stendilo all'aria."
            } else {
                dryDetail += "In alternativa all'aria."
            }
        }
        if inShade { dryDetail += " Lontano dal sole diretto." }
        rows.append(PlanRow(icon: "wind", title: "Asciugatura", detail: dryDetail))

        // MARK: ironing

        let symbolIron = effects.compactMap(\.ironDots).min()
        let fiberIron = cares.map(\.ironDots).min()
        let ironDots = symbolIron ?? fiberIron ?? 3
        if let symbolIron, let fiberIron, fiberIron < symbolIron,
           let strictest = fibers.first(where: { $0.care.ironDots == fiberIron }) {
            warnings.append("Il ferro dell'etichetta è tarato sul tessuto: sulle parti in \(strictest.name.lowercased()) tieniti più basso.")
        }
        let noSteam = effects.contains(where: \.noSteam) || ironDots == 1
        let ironDetail: String
        switch ironDots {
        case 0: ironDetail = "Non stirare. Per le pieghe basta appenderlo in bagno mentre fai la doccia."
        case 1: ironDetail = "Ferro tiepido, max 110 °C, senza vapore e al rovescio."
        case 2: ironDetail = "Ferro medio, max 150 °C\(noSteam ? ", senza vapore" : "")."
        default: ironDetail = "Ferro caldo, fino a 200 °C\(noSteam ? ", senza vapore" : "")."
        }
        rows.append(PlanRow(icon: "thermometer.medium", title: "Stiratura", detail: ironDetail))

        // MARK: professional care

        if let pro = effects.compactMap(\.proCleaning).first {
            let mild = effects.contains(where: \.proMild)
            let detail: String
            switch pro {
            case .perchlor: detail = "Lavaggio a secco in lavanderia\(mild ? ", ciclo delicato" : "")."
            case .hydrocarbon: detail = "Lavaggio a secco con solvente delicato\(mild ? ", ciclo ridotto" : "")."
            case .wet: detail = "Wet cleaning professionale\(mild ? ", ciclo delicato" : ""): lavaggio ad acqua fatto in lavanderia."
            case .none: detail = "Niente lavanderia a secco: i solventi rovinerebbero il capo."
            }
            rows.append(PlanRow(icon: "building.2", title: "Lavanderia", detail: detail))
        }

        // MARK: what tends to go wrong

        for fiber in fibers.sorted(by: { (reading.composition.share(of: $0) ?? 0) > (reading.composition.share(of: $1) ?? 0) }) {
            for warning in fiber.care.warnings where !warnings.contains(warning) {
                warnings.append(warning)
            }
        }
        if let elastane = fibers.first(where: { $0.id == "elastan" || $0.id == "elastomultiestere" }),
           let share = reading.composition.share(of: elastane), share <= 15 {
            warnings.insert("Basta quel \(share)% di \(elastane.name.lowercased()) a decidere il lavaggio di tutto il capo: niente ammorbidente e niente asciugatrice.", at: 0)
        }
        if fibers.contains(where: { $0.family == .sintetica }) && fibers.allSatisfy({ $0.family == .sintetica }) {
            warnings.append("Rovescialo prima di lavarlo: le fibre sintetiche fanno i pallini proprio sullo sfregamento esterno.")
        }
        warnings = Array(warnings.prefix(5))

        // MARK: basis and summary

        let fromImage = reading.symbols.filter { $0.source == .immagine }.count
        let fromText = reading.symbols.filter { $0.source == .testo }.count
        var basisParts: [String] = []
        if fromImage > 0 { basisParts.append("\(fromImage) simbol\(fromImage == 1 ? "o" : "i") dalla foto") }
        if fromText > 0 { basisParts.append("\(fromText) istruzion\(fromText == 1 ? "e" : "i") scritta") }
        let fiberCount = reading.composition.allParts.count
        if fiberCount > 0 { basisParts.append("\(fiberCount) fibr\(fiberCount == 1 ? "a" : "e") in composizione") }
        let basis = basisParts.isEmpty
            ? "Non ho letto nulla dall'etichetta: quello che vedi è il consiglio prudente di default."
            : "Consiglio costruito su " + basisParts.joined(separator: ", ") + "."

        var summary = headline + "."
        if let main = fibers.first {
            let share = reading.composition.share(of: main).map { "\($0)% " } ?? ""
            summary += " È soprattutto \(share)\(main.name.lowercased()): \(main.summary.lowercased())"
        }
        if let first = warnings.first { summary += " " + first }

        return WashPlan(headline: headline, rows: rows, warnings: warnings, summary: summary, basis: basis)
    }

    private static func programName(temperature: Int, effects: [CareEffect], fibers: [Fiber], detergent: DetergentKind) -> String {
        if detergent == .lana { return "programma lana o seta" }
        if fibers.contains(where: { ["viscosa", "cupro", "acetato", "bambu", "seta", "pelliccia", "metallico"].contains($0.id) }) {
            return "programma delicati"
        }
        if effects.contains(where: { $0.spin == .low }) { return "programma delicati" }
        if effects.contains(where: { $0.spin == .medium }) { return "programma sintetici" }
        if fibers.allSatisfy({ $0.family == .sintetica }) && !fibers.isEmpty { return "programma sintetici" }
        if temperature >= 60 { return "programma cotone" }
        return "programma normale"
    }

    /// A compact digest of the label, used to prompt the on-device model.
    static func facts(from reading: LabelReading) -> String {
        var lines: [String] = []
        for section in reading.composition.sections where !section.parts.isEmpty {
            let parts = section.parts.map { part -> String in
                let percentage = part.percentage.map { "\($0)% " } ?? ""
                return percentage + part.displayName
            }
            lines.append((section.name.map { "\($0): " } ?? "Composizione: ") + parts.joined(separator: ", "))
        }
        for detected in reading.bestPerFamily {
            lines.append("\(detected.symbol.family.title): \(detected.symbol.title)")
        }
        return lines.joined(separator: "\n")
    }
}
