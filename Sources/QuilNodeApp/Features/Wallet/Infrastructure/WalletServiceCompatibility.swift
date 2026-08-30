import Foundation

enum WalletServiceCompatibility {
    static func requiresUpgrade(for message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("invalid passwordless service response")
            || normalized.contains("serviceaction")
            || normalized.contains("protocol is incompatible")
            || normalized.contains("passwordless service is not available")
            || normalized.contains("walletinventory")
    }
}
