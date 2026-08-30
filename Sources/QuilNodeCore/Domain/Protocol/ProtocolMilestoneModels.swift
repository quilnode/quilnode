import Foundation

public enum ProtocolMilestoneKind: String, Codable, Sendable {
    case reset
    case cutover
    case amnesty
    case activation
    case migration
}

public enum ProtocolMilestoneSupport: String, Codable, Sendable {
    case included
    case missing
    case unknown
}

/// Describes the strength of the source evidence behind a scheduled frame.
/// Human-readable comments are useful provenance, but only compiled
/// declarations can create a protocol-level ambiguity.
public enum ProtocolMilestoneSourceAssessment: Equatable, Sendable {
    case verified
    case documentationNote
    case executableConflict
}

public struct ProtocolSourceFile: Equatable, Sendable {
    public var path: String
    public var contents: String

    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}

public struct ProtocolMilestone: Codable, Equatable, Identifiable, Sendable {
    public var symbol: String
    public var title: String
    public var kind: ProtocolMilestoneKind
    public var targetFrame: UInt64
    public var previousTargetFrame: UInt64?
    public var summary: String
    public var operatorImpact: String
    public var sourcePath: String
    public var sourceLine: Int
    public var branch: String
    public var commit: String
    public var committedAt: Date
    public var checkedAt: Date
    /// Alternative values found in other executable declarations of the same
    /// symbol at the same commit. This is the only condition treated as a
    /// source conflict.
    public var conflictingFrames: [UInt64]
    /// Different values found in comments that describe the same milestone.
    /// These are retained for provenance but never override executable code.
    public var documentationFrames: [UInt64]
    public var installedSupport: ProtocolMilestoneSupport

    public var id: String { symbol }
    public var hasSourceConflict: Bool { !conflictingFrames.isEmpty }
    public var hasDocumentationNote: Bool { !documentationFrames.isEmpty }
    public var sourceAssessment: ProtocolMilestoneSourceAssessment {
        if hasSourceConflict { return .executableConflict }
        if hasDocumentationNote { return .documentationNote }
        return .verified
    }

    public init(
        symbol: String,
        title: String,
        kind: ProtocolMilestoneKind,
        targetFrame: UInt64,
        previousTargetFrame: UInt64? = nil,
        summary: String,
        operatorImpact: String,
        sourcePath: String,
        sourceLine: Int,
        branch: String,
        commit: String,
        committedAt: Date,
        checkedAt: Date,
        conflictingFrames: [UInt64] = [],
        documentationFrames: [UInt64] = [],
        installedSupport: ProtocolMilestoneSupport = .unknown
    ) {
        self.symbol = symbol
        self.title = title
        self.kind = kind
        self.targetFrame = targetFrame
        self.previousTargetFrame = previousTargetFrame
        self.summary = summary
        self.operatorImpact = operatorImpact
        self.sourcePath = sourcePath
        self.sourceLine = sourceLine
        self.branch = branch
        self.commit = commit
        self.committedAt = committedAt
        self.checkedAt = checkedAt
        self.conflictingFrames = conflictingFrames
        self.documentationFrames = documentationFrames
        self.installedSupport = installedSupport
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, title, kind, targetFrame, previousTargetFrame, summary
        case operatorImpact, sourcePath, sourceLine, branch, commit
        case committedAt, checkedAt, conflictingFrames, documentationFrames
        case installedSupport, evidenceSchemaVersion
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try values.decode(String.self, forKey: .symbol)
        title = try values.decode(String.self, forKey: .title)
        kind = try values.decode(ProtocolMilestoneKind.self, forKey: .kind)
        targetFrame = try values.decode(UInt64.self, forKey: .targetFrame)
        previousTargetFrame = try values.decodeIfPresent(UInt64.self, forKey: .previousTargetFrame)
        summary = try values.decode(String.self, forKey: .summary)
        operatorImpact = try values.decode(String.self, forKey: .operatorImpact)
        sourcePath = try values.decode(String.self, forKey: .sourcePath)
        sourceLine = try values.decode(Int.self, forKey: .sourceLine)
        branch = try values.decode(String.self, forKey: .branch)
        commit = try values.decode(String.self, forKey: .commit)
        committedAt = try values.decode(Date.self, forKey: .committedAt)
        checkedAt = try values.decode(Date.self, forKey: .checkedAt)
        installedSupport =
            try values.decodeIfPresent(
                ProtocolMilestoneSupport.self,
                forKey: .installedSupport
            ) ?? .unknown

        let schema = try values.decodeIfPresent(Int.self, forKey: .evidenceSchemaVersion) ?? 1
        let storedConflicts = try values.decodeIfPresent([UInt64].self, forKey: .conflictingFrames) ?? []
        if schema < 2 {
            // Build 62 and earlier used this field for comment references. Move
            // the cached values to their correct, non-alarming classification.
            conflictingFrames = []
            documentationFrames = storedConflicts
        } else {
            conflictingFrames = storedConflicts
            documentationFrames =
                try values.decodeIfPresent(
                    [UInt64].self,
                    forKey: .documentationFrames
                ) ?? []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(symbol, forKey: .symbol)
        try values.encode(title, forKey: .title)
        try values.encode(kind, forKey: .kind)
        try values.encode(targetFrame, forKey: .targetFrame)
        try values.encodeIfPresent(previousTargetFrame, forKey: .previousTargetFrame)
        try values.encode(summary, forKey: .summary)
        try values.encode(operatorImpact, forKey: .operatorImpact)
        try values.encode(sourcePath, forKey: .sourcePath)
        try values.encode(sourceLine, forKey: .sourceLine)
        try values.encode(branch, forKey: .branch)
        try values.encode(commit, forKey: .commit)
        try values.encode(committedAt, forKey: .committedAt)
        try values.encode(checkedAt, forKey: .checkedAt)
        try values.encode(conflictingFrames, forKey: .conflictingFrames)
        try values.encode(documentationFrames, forKey: .documentationFrames)
        try values.encode(installedSupport, forKey: .installedSupport)
        try values.encode(2, forKey: .evidenceSchemaVersion)
    }
}
