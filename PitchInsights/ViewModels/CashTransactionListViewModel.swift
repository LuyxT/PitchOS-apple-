import Foundation
import SwiftUI
import Combine

@MainActor
final class CashTransactionListViewModel: ObservableObject {
    @Published var selectedTransactionID: UUID?
    @Published var hoveredTransactionID: UUID?

    func select(_ transactionID: UUID?) {
        selectedTransactionID = transactionID
    }
}
