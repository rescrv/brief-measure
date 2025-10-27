import Foundation
import Combine

@MainActor
final class ObservationStatus: ObservableObject {
    static let shared = ObservationStatus()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var nextRetryDate: Date?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastLimitMessage: String?

    private init() {}

    func update(pendingCount: Int, nextRetry: Date?, errorMessage: String?) {
        self.pendingCount = pendingCount
        self.nextRetryDate = nextRetry
        self.lastErrorMessage = errorMessage
    }

    func reportLimitExceeded(message: String) {
        lastLimitMessage = message
        lastErrorMessage = message
    }

    func clearLimitMessage() {
        let limit = lastLimitMessage
        lastLimitMessage = nil
        if lastErrorMessage == limit {
            lastErrorMessage = nil
        }
    }
}
