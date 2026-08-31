import CryptoKit
import Foundation

// Builder-side verifier: public keys only, including Sparkle's signed-feed format.
// This tool is never embedded in the app and never opens a private key.
enum VerificationFailure: Error { case invalidInput, invalidSignature }

func decode(_ text: String, length: Int) throws -> Data {
    guard let data = Data(base64Encoded: text), data.count == length,
        data.base64EncodedString() == text
    else { throw VerificationFailure.invalidInput }
    return data
}

do {
    let arguments = CommandLine.arguments
    guard arguments.count == 4 || arguments.count == 5 else {
        throw VerificationFailure.invalidInput
    }
    let mode = arguments[1]
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: decode(arguments[2], length: 32))
    let url = URL(fileURLWithPath: arguments[3])
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true,
        let size = values.fileSize, size <= 1_073_741_824
    else { throw VerificationFailure.invalidInput }
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    let content: Data
    let signature: Data
    if mode == "feed", arguments.count == 4 {
        guard data.count <= 2_097_152,
            let text = String(data: data, encoding: .utf8),
            let range = text.range(of: "<!-- sparkle-signatures:", options: .backwards)
        else { throw VerificationFailure.invalidInput }
        let block = String(text[range.lowerBound...])
        let expression = try NSRegularExpression(
            pattern: #"\A<!-- sparkle-signatures:\nedSignature: ([A-Za-z0-9+/]{86}==)\nlength: ([0-9]+)\n-->\n\z"#)
        guard let match = expression.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
            let signatureRange = Range(match.range(at: 1), in: block),
            let lengthRange = Range(match.range(at: 2), in: block),
            let length = Int(block[lengthRange])
        else { throw VerificationFailure.invalidInput }
        content = Data(text[..<range.lowerBound].utf8)
        guard content.count == length,
            content.range(of: Data("<!-- sparkle-signatures:".utf8)) == nil
        else { throw VerificationFailure.invalidInput }
        signature = try decode(String(block[signatureRange]), length: 64)
    } else if mode == "file", arguments.count == 5 {
        content = data
        signature = try decode(arguments[4], length: 64)
    } else {
        throw VerificationFailure.invalidInput
    }
    guard publicKey.isValidSignature(signature, for: content) else {
        throw VerificationFailure.invalidSignature
    }
} catch {
    FileHandle.standardError.write(Data("Ed25519 verification failed.\n".utf8))
    exit(1)
}
