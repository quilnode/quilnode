import SwiftUI

/// A small, shared vocabulary for the width that dashboard content actually
/// receives after the sidebar. Screens choose a simpler composition at each
/// class; individual cards remain flexible inside that composition.
enum DashboardLayoutClass: Equatable, Sendable {
    case compact
    case regular
    case wide

    init(contentWidth: CGFloat) {
        if contentWidth < 860 {
            self = .compact
        } else if contentWidth < 1_120 {
            self = .regular
        } else {
            self = .wide
        }
    }

    var isCompact: Bool { self == .compact }
    var isWide: Bool { self == .wide }
}

private struct DashboardLayoutClassKey: EnvironmentKey {
    static let defaultValue = DashboardLayoutClass.regular
}

extension EnvironmentValues {
    var dashboardLayoutClass: DashboardLayoutClass {
        get { self[DashboardLayoutClassKey.self] }
        set { self[DashboardLayoutClassKey.self] = newValue }
    }
}
