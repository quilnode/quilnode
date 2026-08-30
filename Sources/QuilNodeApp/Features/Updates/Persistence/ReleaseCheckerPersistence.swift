import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    func recoverOperationJournal() {
        guard let url = try? Self.applicationSupportDirectory().appendingPathComponent("update-operation.json"),
            let data = try? BoundedLocalData.read(from: url, maximumBytes: 256 * 1_024)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var journal = try? decoder.decode(UpdateOperationJournal.self, from: data) else { return }
        operationJournal = journal

        let restoredLogURL = Self.validatedRestoredLogURL(journal.logPath)
        let workflow = Self.workflow(for: journal.channel)

        // Keep a recent successful operation visible after an app relaunch.
        // A build/install belongs to the application-level coordinator, not
        // the lifetime of a particular Update Center view. The user may
        // dismiss it explicitly once they have reviewed the result.
        if journal.status == .installed,
            Date().timeIntervalSince(journal.updatedAt) < 24 * 60 * 60
        {
            progress = NodeUpdateProgress(
                status: .succeeded,
                workflow: workflow,
                step: .healthGate,
                phase: "Update complete",
                detail: journal.detail,
                fraction: 1,
                startedAt: journal.startedAt,
                phaseStartedAt: journal.updatedAt,
                stepStartedAt: journal.updatedAt,
                updatedAt: journal.updatedAt,
                isEstimate: false,
                logURL: restoredLogURL
            )
            lastMessage = journal.detail
            return
        }
        // A failed activation attempt does not invalidate the already hashed
        // staging bundle. Recover it just like an interrupted/staged build so
        // retrying never recompiles or downloads the same artifact.
        if (journal.status == .staged || journal.status == .failed),
            let (manifestURL, manifest) = Self.restoredManifest(journal.manifestPath)
        {
            stagedUpdate = StagedNodeUpdate(
                channel: manifest.channel,
                version: manifest.version,
                manifestURL: manifestURL
            )
            progress = NodeUpdateProgress(
                status: .ready,
                workflow: workflow,
                step: .switchRuntime,
                phase: "Ready to install",
                detail: "A previously verified build is preserved and ready for activation.",
                fraction: max(journal.fraction, 0.97),
                startedAt: journal.startedAt,
                updatedAt: journal.updatedAt,
                isEstimate: false,
                logURL: restoredLogURL
            )
            lastMessage = "Recovered staged update \(manifest.version)."
            return
        }

        guard journal.status == .running || journal.status == .staged else { return }
        journal.status = .interrupted
        journal.phase = "Build interrupted safely"
        journal.detail = "The app exited before activation. The installed node and its stores were not changed."
        journal.updatedAt = Date()
        operationJournal = journal
        progress = NodeUpdateProgress(
            status: .failed,
            workflow: workflow,
            step: NodeUpdateStep.classify(phase: journal.phase, workflow: workflow),
            phase: journal.phase,
            detail: journal.detail,
            fraction: journal.fraction,
            startedAt: journal.startedAt,
            updatedAt: journal.updatedAt,
            isEstimate: false,
            logURL: restoredLogURL
        )
        lastMessage = "Recovered an interrupted update record; no partial build was activated."
        persistOperationJournal()
    }

    nonisolated static func workflow(for channel: String) -> NodeUpdateWorkflow {
        switch channel {
        case "approved-dev", "raw-dev": .sourceNode
        case "signed": .signedNode
        default: .generic
        }
    }

    func removeTerminalOperationJournal() {
        guard
            operationJournal?.status == .installed
                || operationJournal?.status == .failed
                || operationJournal?.status == .interrupted,
            let url = try? Self.applicationSupportDirectory()
                .appendingPathComponent("update-operation.json")
        else { return }
        try? FileManager.default.removeItem(at: url)
        operationJournal = nil
    }

    func persistOperationJournal() {
        guard let journal = operationJournal,
            let url = try? Self.applicationSupportDirectory().appendingPathComponent("update-operation.json")
        else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try PrivateLocalFileSystem.write(try encoder.encode(journal), atomicallyTo: url)
        } catch {}
    }

    func loadHistory() {
        guard let url = try? Self.applicationSupportDirectory().appendingPathComponent("update-history.json"),
            let data = try? BoundedLocalData.read(from: url, maximumBytes: 2 * 1_024 * 1_024)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        history = (try? decoder.decode([NodeUpdateEvent].self, from: data)) ?? []
    }

    func persistHistory() {
        guard let url = try? Self.applicationSupportDirectory().appendingPathComponent("update-history.json") else {
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try PrivateLocalFileSystem.write(try encoder.encode(history), atomicallyTo: url)
        } catch {}
    }

    func loadProtocolMilestones() {
        guard let url = try? Self.applicationSupportDirectory().appendingPathComponent("protocol-milestones.json"),
            let data = try? BoundedLocalData.read(from: url, maximumBytes: 4 * 1_024 * 1_024)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        protocolMilestones = (try? decoder.decode([ProtocolMilestone].self, from: data)) ?? []
    }

    func persistProtocolMilestones() {
        guard let url = try? Self.applicationSupportDirectory().appendingPathComponent("protocol-milestones.json")
        else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try PrivateLocalFileSystem.write(try encoder.encode(protocolMilestones), atomicallyTo: url)
        } catch {}
    }
}
