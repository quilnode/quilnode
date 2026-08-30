import Combine
import Foundation

@MainActor
final class PrivacyModeController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: PrivacyMode.defaultsKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: PrivacyMode.defaultsKey)
    }

    func toggle() {
        isEnabled.toggle()
    }
}
