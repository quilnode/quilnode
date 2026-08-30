import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension PrivilegedServiceClient {
    public static func readWalletInventory(
        timeout: TimeInterval = 60
    ) -> (inventory: WalletInventory?, error: String?) {
        let result = response(.walletInventory, timeout: timeout)
        guard result.exitCode == 0, let output = result.response?.walletOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return (try decoder.decode(WalletInventory.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable wallet metadata.")
        }
    }

    public static func inspectKeyset(
        manifestPath: String,
        timeout: TimeInterval = 20
    ) -> (inspection: KeysetInspection?, error: String?) {
        let result = response(.walletInspect, manifestPath: manifestPath, timeout: timeout)
        guard result.exitCode == 0, let output = result.response?.walletOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        do {
            return (try JSONDecoder().decode(KeysetInspection.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable keyset metadata.")
        }
    }
}
