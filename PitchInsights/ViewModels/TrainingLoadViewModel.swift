import Foundation

@MainActor
final class TrainingLoadViewModel {
    func loadSummary(planID: UUID, store: AppDataStore) -> TrainingLoadSummary {
        store.loadSummary(planID: planID)
    }

    func materialSummary(planID: UUID, store: AppDataStore) -> [TrainingMaterialQuantity] {
        var aggregate: [String: TrainingMaterialQuantity] = [:]

        for phase in store.phases(for: planID) {
            for exercise in store.exercises(for: phase.id) {
                for material in exercise.materials {
                    let key = "\(material.kind.rawValue)-\(material.displayName.lowercased())"
                    if var existing = aggregate[key] {
                        existing.quantity += material.quantity
                        aggregate[key] = existing
                    } else {
                        aggregate[key] = TrainingMaterialQuantity(
                            kind: material.kind,
                            label: material.displayName,
                            quantity: material.quantity
                        )
                    }
                }
            }
        }

        return aggregate.values.sorted {
            if $0.kind == $1.kind {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.kind.title.localizedCaseInsensitiveCompare($1.kind.title) == .orderedAscending
        }
    }

    func organizationHints(materials: [TrainingMaterialQuantity]) -> [String] {
        guard !materials.isEmpty else {
            return ["Kein Material hinterlegt"]
        }

        var hints: [String] = []
        let cones = materials.filter { $0.kind == .huetchen }.reduce(0) { $0 + $1.quantity }
        let bibs = materials.filter { $0.kind == .leibchen }.reduce(0) { $0 + $1.quantity }
        let goals = materials.filter { $0.kind == .tore }.reduce(0) { $0 + $1.quantity }

        if cones >= 20 {
            hints.append("Hütchen vor Trainingsstart komplett auslegen")
        }
        if bibs > 0 {
            hints.append("Leibchen nach Gruppen sortieren")
        }
        if goals > 0 {
            hints.append("Tore frühzeitig aufbauen und sichern")
        }
        if hints.isEmpty {
            hints.append("Material 15 Minuten vor Start bereitstellen")
        }

        return hints
    }
}
