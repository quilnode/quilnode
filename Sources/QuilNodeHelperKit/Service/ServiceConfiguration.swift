import Foundation

struct ServiceConfiguration: Codable, Sendable {
    var schemaVersion = 1
    var controllerUID: UInt32
    var controllerRequirement: String
    var installedAt: Date
}
