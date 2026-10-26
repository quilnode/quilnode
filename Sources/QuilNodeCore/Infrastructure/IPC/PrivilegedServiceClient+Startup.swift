import Foundation

extension PrivilegedServiceClient {
    public static func nodeStartupPolicy(enabled: Bool? = nil) -> (enabled: Bool?, error: String?) {
        let result = response(
            enabled.map { $0 ? .nodeStartupEnable : .nodeStartupDisable } ?? .nodeStartupStatus,
            timeout: 25
        )
        guard result.exitCode == 0, let value = result.response?.nodeStartAtBoot else {
            return (nil, result.response?.message ?? result.error)
        }
        return (value, nil)
    }
}
