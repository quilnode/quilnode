import Foundation

struct ReleaseCheckProgress: Equatable, Sendable {
    enum Stage: String, Equatable, Sendable {
        case preparing
        case branches
        case releases
        case comparison

        var title: String {
            switch self {
            case .preparing: "Preparing secure release check"
            case .branches: "Reading official branch heads"
            case .releases: "Verifying release channels"
            case .comparison: "Comparing with this Mac"
            }
        }

        var fraction: Double {
            switch self {
            case .preparing: 0
            case .branches: 0.25
            case .releases: 0.50
            case .comparison: 0.75
            }
        }

        var stepNumber: Int {
            switch self {
            case .preparing: 1
            case .branches: 2
            case .releases: 3
            case .comparison: 4
            }
        }
    }

    var stage: Stage
    var detail: String
    var startedAt: Date
    var updatedAt: Date

    init(stage: Stage, detail: String, startedAt: Date, updatedAt: Date = Date()) {
        self.stage = stage
        self.detail = detail
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var fraction: Double { stage.fraction }
}
