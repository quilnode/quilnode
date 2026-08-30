import AppKit
import SwiftUI

@MainActor
final class ApplicationQuitInterlockPresenter {
    private var panel: NSPanel?
    private var completion: ((Bool) -> Void)?

    func present(completion: @escaping (Bool) -> Void) {
        guard panel == nil else {
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        self.completion = completion
        let content = OperatorInterlockView(
            model: OperatorInterlockPresentation.quitDuringUpdate,
            onCancel: { [weak self] in self?.finish(shouldQuit: false) },
            onConfirm: { [weak self] _ in self?.finish(shouldQuit: true) }
        )
        .quilThemed(.quilNode)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 680),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "QuilNode Update"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: content)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(shouldQuit: Bool) {
        guard let completion else { return }
        self.completion = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        completion(shouldQuit)
    }
}
