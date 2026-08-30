import Foundation

enum AutomaticUpdateAuthorizationState: Equatable, Sendable {
    case inactive
    case synchronizing
    case ready
    case failed(String)

    var isReady: Bool {
        self == .ready
    }
}
