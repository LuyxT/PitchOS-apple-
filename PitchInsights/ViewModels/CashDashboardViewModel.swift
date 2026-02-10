import Foundation
import SwiftUI
import Combine

@MainActor
final class CashDashboardViewModel: ObservableObject {
    enum RangePreset: String, CaseIterable, Identifiable {
        case month = "30 Tage"
        case quarter = "90 Tage"
        case year = "365 Tage"
        case all = "Gesamt"

        var id: String { rawValue }
    }

    @Published var granularity: CashTimelineGranularity = .daily
    @Published var rangePreset: RangePreset = .quarter

    var range: DateInterval? {
        let now = Date()
        switch rangePreset {
        case .month:
            return DateInterval(start: Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now, end: now)
        case .quarter:
            return DateInterval(start: Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now, end: now)
        case .year:
            return DateInterval(start: Calendar.current.date(byAdding: .day, value: -365, to: now) ?? now, end: now)
        case .all:
            return nil
        }
    }

    func summary(store: AppDataStore) -> CashSummary {
        store.cashSummary(for: range)
    }

    func timeline(store: AppDataStore) -> [CashTimelinePoint] {
        store.cashTimeline(granularity: granularity, range: range)
    }

    func categoryBreakdown(store: AppDataStore) -> [CashCategoryBreakdown] {
        store.cashCategoryBreakdown(for: range)
    }

    var rangeDisplay: String {
        guard let range else { return "Gesamter Zeitraum" }
        return "\(Self.rangeFormatter.string(from: range.start)) – \(Self.rangeFormatter.string(from: range.end))"
    }

    func topExpenseCategories(store: AppDataStore) -> [CashCategoryBreakdown] {
        categoryBreakdown(store: store)
            .filter { breakdown in
                let categoryID = breakdown.categoryID
                return store.cashTransactions.contains(where: {
                    $0.categoryID == categoryID && $0.type == .expense
                })
            }
            .prefix(4)
            .map { $0 }
    }

    func topIncomeCategories(store: AppDataStore) -> [CashCategoryBreakdown] {
        categoryBreakdown(store: store)
            .filter { breakdown in
                let categoryID = breakdown.categoryID
                return store.cashTransactions.contains(where: {
                    $0.categoryID == categoryID && $0.type == .income
                })
            }
            .prefix(4)
            .map { $0 }
    }

    private static let rangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
