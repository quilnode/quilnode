import AppKit
import Combine
import Foundation
import Sparkle

// This executable can target only uniquely named disposable fixture apps.
let arguments = CommandLine.arguments
guard arguments.count == 3 else { exit(64) }
let target = URL(fileURLWithPath: arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
guard let bundle = Bundle(url: target),
    bundle.bundleIdentifier?.hasPrefix("com.quilnode.qualification.fixture.") == true,
    target.lastPathComponent == "Fixture.app",
    target.pathComponents.contains(where: { $0.hasPrefix("quilnode-update-lab-") }),
    ["install", "probe", "cancel", "interrupt"].contains(arguments[2])
else { exit(64) }

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let driver = QualificationUserDriver(mode: arguments[2])
let controller = AppUpdateController(bundle: bundle, userDriver: driver)
var phases: [String] = []
let observation = controller.$phase.sink { phase in phases.append(String(describing: phase)) }
var finished = false
driver.finish = {
    guard !finished else { return }
    finished = true
    // Let Sparkle deliver cycle completion and the controller's KVO updates.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let result: [String: Any] = [
            "events": driver.events, "phases": phases,
            "errorCode": driver.errorCode as Any? ?? NSNull(),
            "errorDomain": driver.errorDomain as Any? ?? NSNull(),
            "errorChain": driver.errorChain,
            "canCheck": controller.canCheck,
            "lastAttemptRecorded": controller.lastAttemptAt != nil,
        ]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        exit(0)
    }
}
DispatchQueue.main.async { controller.checkNow() }
DispatchQueue.main.asyncAfter(deadline: .now() + 45) {
    fputs("Fixture update exceeded its time limit.\n", stderr)
    exit(70)
}
application.run()
