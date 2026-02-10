import Foundation
import SwiftUI
import Combine

@MainActor
final class CashTransactionDetailViewModel: ObservableObject {
    @Published var localDraft: CashTransactionDraft
    @Published var errorMessage: String?

    init(draft: CashTransactionDraft) {
        self.localDraft = draft
    }

    func sync(with draft: CashTransactionDraft) {
        localDraft = draft
    }

    func validate() -> Bool {
        let validation = CashValidationService().validateTransactionDraft(localDraft)
        errorMessage = validation
        return validation == nil
    }
}
