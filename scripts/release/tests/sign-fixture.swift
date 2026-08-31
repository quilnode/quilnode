import CryptoKit
import Foundation

// Disposable test identity only. Never used by the packager or by the app.
let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data((0..<32).map(UInt8.init)))
let file = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: file)
let signature = try key.signature(for: data).base64EncodedString()
if file.pathExtension == "xml" {
    let block = "<!-- sparkle-signatures:\nedSignature: \(signature)\nlength: \(data.count)\n-->\n"
    try (data + Data(block.utf8)).write(to: file)
} else {
    try Data((signature + "\n").utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
print(key.publicKey.rawRepresentation.base64EncodedString())
