import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension PrivilegedServiceClient {
    public static func readFirewallStatus(
        timeout: TimeInterval = 8
    ) -> (status: ManagedFirewallStatus?, error: String?) {
        decodeFirewallResponse(response(.firewallStatus, timeout: timeout))
    }

    public static func configureFirewall(
        timeout: TimeInterval = 20
    ) -> (status: ManagedFirewallStatus?, error: String?) {
        decodeFirewallResponse(response(.firewallConfigure, timeout: timeout))
    }

    private static func decodeFirewallResponse(
        _ result: (response: PrivilegedServiceResponse?, error: String, exitCode: Int32)
    ) -> (status: ManagedFirewallStatus?, error: String?) {
        guard result.exitCode == 0,
            let output = result.response?.firewallOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return (try decoder.decode(ManagedFirewallStatus.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable firewall state.")
        }
    }
}
