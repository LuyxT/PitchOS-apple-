import Foundation

enum LoadState<Value> {
    case idle
    case loading
    case success(Value)
    case empty
    case failure(Error)
}

extension LoadState {
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}
