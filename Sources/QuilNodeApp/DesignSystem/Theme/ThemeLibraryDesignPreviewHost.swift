import SwiftUI

#if DEBUG
    struct ThemeLibraryDesignPreviewHost: View {
        @StateObject private var themeController = ThemeController()
        @State private var isPresented = true

        var body: some View {
            ThemeLibraryView(isPresented: $isPresented)
                .environmentObject(themeController)
                .quilThemed(themeController.selectedTheme)
        }
    }
#endif
