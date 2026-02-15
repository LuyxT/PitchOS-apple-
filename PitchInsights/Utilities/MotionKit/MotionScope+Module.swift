import Foundation

extension Module {
    var motionScope: MotionScope {
        switch self {
        case .trainerProfil:
            return .profile
        case .kader:
            return .kader
        case .kalender:
            return .kalender
        case .trainingsplanung:
            return .trainingsplan
        case .spielanalyse:
            return .analyse
        case .taktiktafel:
            return .taktik
        case .messenger:
            return .messenger
        case .dateien:
            return .dateien
        case .verwaltung:
            return .verwaltung
        case .mannschaftskasse:
            return .mannschaftskasse
        case .einstellungen:
            return .global
        }
    }
}
