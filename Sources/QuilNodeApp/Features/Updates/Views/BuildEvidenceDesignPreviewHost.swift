import SwiftUI

#if DEBUG
    struct BuildEvidenceDesignPreviewHost: View {
        @State private var followsLatest = true

        private let snapshot = BuildLogSnapshot.parse(
            """
               Compiling quil-types v0.1.0
               Compiling quil-lattice-ct v0.1.0
            warning: unused import: `signed_mod`
              --> crates/quil-lattice-ct/src/range.rs:26:20
               Compiling ring v0.16.20
               Compiling rocksdb v0.22.0
               Compiling quil-node v2.1.0.25
                Finished release [optimized] target(s) in 6m 12s
            """,
            observedAt: Date()
        )

        var body: some View {
            BuildEvidencePanel(
                snapshot: snapshot,
                isLive: true,
                privacyModeEnabled: false,
                followsLatest: $followsLatest,
                revision: 1
            )
            .padding(18)
            .background { ThemeCanvasBackground() }
        }
    }
#endif
