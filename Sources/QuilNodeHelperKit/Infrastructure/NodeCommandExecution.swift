import Foundation

extension QuilNodeHelper {
    static func nodeProcessIsRunning() -> Bool {
        guard let output = try? runLaunchctl(["print", serviceTarget]),
            let regex = try? NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)\s*$"#)
        else { return false }
        return regex.firstMatch(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        ) != nil
    }

    static func runNodeTool(_ arguments: [String], timeout: TimeInterval) throws -> String {
        let plist = try? readPlist()
        if plist?["UserName"] as? String == serviceUser {
            return try runAsServiceUser(nodeLink, arguments, timeout: timeout)
        }
        return try run(nodeLink, arguments, timeout: timeout)
    }
}
