import Foundation

public enum ProtocolMilestoneDetector {
    private static let declaration = try! NSRegularExpression(
        pattern:
            #"(?m)^\s*pub\s+const\s+([A-Z][A-Z0-9_]*(?:RESET|CUTOVER|AMNESTY|ACTIVATION|MIGRATION)[A-Z0-9_]*_FRAME)\s*:\s*u(?:32|64|size)\s*=\s*([0-9][0-9_]*)\s*;"#
    )

    private struct DeclarationCandidate {
        var symbol: String
        var frame: UInt64
        var file: ProtocolSourceFile
        var line: Int
        var docs: String
    }

    public static func detect(
        files: [ProtocolSourceFile],
        branch: String,
        commit: String,
        committedAt: Date,
        checkedAt: Date = Date()
    ) -> [ProtocolMilestone] {
        let productionFiles = files.filter { file in
            let path = file.path.lowercased()
            return path.hasSuffix(".rs")
                && !path.contains("/tests/")
                && !path.contains("/benches/")
                && !path.hasSuffix("_test.rs")
        }

        var candidates: [DeclarationCandidate] = []
        for file in productionFiles {
            let text = file.contents as NSString
            let fullRange = NSRange(location: 0, length: text.length)
            for match in declaration.matches(in: file.contents, range: fullRange) {
                guard match.numberOfRanges == 3 else { continue }
                let symbol = text.substring(with: match.range(at: 1))
                guard let frame = parseFrame(text.substring(with: match.range(at: 2))) else { continue }

                let line = text.substring(to: match.range.location).reduce(into: 1) { count, character in
                    if character == "\n" { count += 1 }
                }
                let docs = documentation(beforeUTF16Offset: match.range.location, in: file.contents)
                candidates.append(
                    DeclarationCandidate(symbol: symbol, frame: frame, file: file, line: line, docs: docs)
                )
            }
        }

        var results: [ProtocolMilestone] = []
        for symbol in Set(candidates.map(\.symbol)).sorted() {
            let definitions =
                candidates
                .filter { $0.symbol == symbol }
                .sorted {
                    if $0.file.path != $1.file.path { return $0.file.path < $1.file.path }
                    return $0.line < $1.line
                }
            guard let canonical = definitions.first else { continue }
            let kind = kind(for: symbol)
            let executableAlternatives = Set(definitions.map(\.frame))
                .subtracting([canonical.frame])
                .sorted()
            results.append(
                ProtocolMilestone(
                    symbol: symbol,
                    title: humanTitle(symbol),
                    kind: kind,
                    targetFrame: canonical.frame,
                    summary: conciseSummary(canonical.docs, fallback: kind),
                    operatorImpact: impact(for: symbol, kind: kind),
                    sourcePath: canonical.file.path,
                    sourceLine: canonical.line,
                    branch: branch,
                    commit: commit.lowercased(),
                    committedAt: committedAt,
                    checkedAt: checkedAt,
                    conflictingFrames: executableAlternatives,
                    documentationFrames: documentationReferences(
                        for: symbol,
                        canonicalFrame: canonical.frame,
                        in: productionFiles
                    )
                )
            )
        }
        return results.sorted {
            if $0.targetFrame != $1.targetFrame { return $0.targetFrame < $1.targetFrame }
            return $0.symbol < $1.symbol
        }
    }

    private static func parseFrame(_ raw: String) -> UInt64? {
        UInt64(raw.replacingOccurrences(of: "_", with: ""))
    }

    private static func kind(for symbol: String) -> ProtocolMilestoneKind {
        if symbol.contains("RESET") { return .reset }
        if symbol.contains("CUTOVER") { return .cutover }
        if symbol.contains("AMNESTY") { return .amnesty }
        if symbol.contains("MIGRATION") { return .migration }
        return .activation
    }

    private static func humanTitle(_ symbol: String) -> String {
        symbol.split(separator: "_")
            .filter { $0 != "FRAME" }
            .map { token in
                let value = String(token)
                if value.range(of: #"^V[0-9]+$"#, options: .regularExpression) != nil {
                    return value
                }
                if value == "QUIL" { return "QUIL" }
                return value.prefix(1) + value.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private static func documentation(beforeUTF16Offset offset: Int, in source: String) -> String {
        let prefix = (source as NSString).substring(to: offset)
        let lines = prefix.components(separatedBy: .newlines)
        var docs: [String] = []
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("///") else {
                if trimmed.isEmpty && docs.isEmpty { continue }
                break
            }
            docs.append(String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        }
        return docs.reversed().joined(separator: " ")
    }

    private static func conciseSummary(_ docs: String, fallback kind: ProtocolMilestoneKind) -> String {
        let cleaned =
            docs
            .replacingOccurrences(of: #"\[`?([^\]`]+)`?\]"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return "A source-defined protocol \(kind.rawValue) at a deterministic network frame."
        }
        let sentences = cleaned.split(separator: ".", omittingEmptySubsequences: true).prefix(2)
        let summary = sentences.joined(separator: ". ") + "."
        return summary.count <= 360 ? summary : String(summary.prefix(357)) + "…"
    }

    private static func impact(for symbol: String, kind: ProtocolMilestoneKind) -> String {
        if symbol.contains("PROVER_RESET") {
            return
                "Prover-tree state is re-baselined. Automatic workers may rejoin allocations; watch local active-shard and reward-credit evidence after the boundary."
        }
        if symbol.contains("GRID_RESET") {
            return
                "Grid and prover allocation state are coordinated again. Expect temporary worker rejoining around the boundary."
        }
        if kind == .cutover {
            return
                "A consensus state-commitment transition occurs. The installed node must include the exact activation logic before the target frame."
        }
        if kind == .amnesty {
            return "The protocol changes prover eligibility handling at this frame; no local key migration is inferred."
        }
        return "A deterministic protocol transition is scheduled. Verify installed support before the target frame."
    }

    private static func documentationReferences(
        for symbol: String,
        canonicalFrame: UInt64,
        in files: [ProtocolSourceFile]
    ) -> [UInt64] {
        let parts = symbol.lowercased().split(separator: "_").map(String.init)
        guard let version = parts.first(where: { $0.range(of: #"^v[0-9]+$"#, options: .regularExpression) != nil }),
            let semantic = parts.first(where: {
                ["reset", "cutover", "amnesty", "activation", "migration"].contains($0)
            })
        else { return [] }
        let family = parts.contains("prover") ? "prover" : (parts.contains("grid") ? "grid" : "")
        let numberPattern = try! NSRegularExpression(pattern: #"[0-9][0-9_]{3,}"#)
        var values = Set<UInt64>()
        for file in files {
            for line in commentLines(in: file.contents) {
                let normalized = line.lowercased().replacingOccurrences(of: "_", with: "-")
                guard normalized.contains(semantic), normalized.contains(version),
                    family.isEmpty || normalized.contains(family),
                    normalized.contains("mainnet") || normalized.contains("frame")
                else { continue }
                let nsLine = line as NSString
                for match in numberPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    if let value = parseFrame(nsLine.substring(with: match.range)), value != canonicalFrame {
                        values.insert(value)
                    }
                }
            }
        }
        return values.sorted()
    }

    /// Returns standalone comments only. Executable tokens, string literals,
    /// and test fixtures must never become scheduling evidence.
    private static func commentLines(in source: String) -> [String] {
        var result: [String] = []
        var insideBlock = false
        for rawLine in source.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if insideBlock {
                if let end = trimmed.range(of: "*/") {
                    result.append(String(trimmed[..<end.lowerBound]))
                    insideBlock = false
                } else {
                    result.append(trimmed)
                }
                continue
            }
            if trimmed.hasPrefix("//") {
                result.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("/*") {
                let body = trimmed.dropFirst(2)
                if let end = body.range(of: "*/") {
                    result.append(String(body[..<end.lowerBound]))
                } else {
                    result.append(String(body))
                    insideBlock = true
                }
            }
        }
        return result
    }
}
