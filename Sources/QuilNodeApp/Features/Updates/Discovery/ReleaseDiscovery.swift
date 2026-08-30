import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static var gitExecutable: String {
        let homebrewGit = "/opt/homebrew/bin/git"
        return FileManager.default.isExecutableFile(atPath: homebrewGit)
            ? homebrewGit
            : "/usr/bin/git"
    }

    /// GUI applications do not inherit the interactive shell PATH. Git hooks
    /// therefore receive a small, deterministic executable search path that
    /// includes the two standard Homebrew prefixes. Skipping automatic LFS
    /// smudging keeps checkout bounded; the one required seniority object is
    /// fetched and digest-verified explicitly later in the pipeline.
    nonisolated static func sourceControlEnvironment() -> [String: String] {
        [
            "PATH": [
                "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
                "/usr/sbin", "/sbin",
            ].joined(separator: ":"),
            "HOME": "/var/empty",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_ASKPASS": "/usr/bin/false",
            "GIT_LFS_SKIP_SMUDGE": "1",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        ]
    }

    nonisolated static func fetchSignedRelease(endpoint: URL) async throws -> SignedReleaseInfo {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        let (data, response) = try downloadBoundedDataSynchronously(
            request,
            maximumBytes: 128_000,
            timeout: 30
        )
        let http = response
        guard http.statusCode == 200,
            exactReleaseURL(http.url, path: "/release"),
            data.count <= 128_000
        else { throw UpdateCenterError.invalidSignedManifest }

        let manifest = String(decoding: data, as: UTF8.self)
        guard let latest = ReleaseManifestParser.latest(in: manifest) else {
            throw UpdateCenterError.noSignedRelease
        }
        let filename = "node-\(latest.version)-darwin-arm64"
        let lines = manifest.split(whereSeparator: \.isNewline).map(String.init)
        let signatures = lines.compactMap { line -> Int? in
            let prefix = "\(filename).dgst.sig."
            guard line.hasPrefix(prefix) else { return nil }
            return Int(line.dropFirst(prefix.count))
        }.sorted()
        return SignedReleaseInfo(
            version: latest.version,
            binaryFileName: filename,
            digestPublished: lines.contains("\(filename).dgst"),
            signatureIndices: signatures,
            manifestModifiedAt: http.value(forHTTPHeaderField: "Last-Modified").flatMap(httpDate)
        )
    }

    nonisolated static func fetchSignedQClientRelease(
        endpoint: URL
    ) async throws -> OfficialQClientRelease {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        let (data, response) = try downloadBoundedDataSynchronously(
            request,
            maximumBytes: 128_000,
            timeout: 30
        )
        let http = response
        guard http.statusCode == 200,
            exactReleaseURL(http.url, path: "/qclient-release"),
            data.count <= 128_000,
            let release = QClientReleaseManifestParser.latest(in: String(decoding: data, as: UTF8.self)),
            release.digestPublished,
            release.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures
        else { throw UpdateCenterError.invalidQClientManifest }
        return release
    }

    nonisolated static func readQClientUpdateInfo(endpoint: URL) async -> QClientUpdateInfo {
        let installed = PrivilegedServiceClient.readQClientStatus(timeout: 8).status
        do {
            return QClientUpdateInfo(
                available: try await fetchSignedQClientRelease(endpoint: endpoint),
                installed: installed,
                checkedAt: Date(),
                error: nil
            )
        } catch {
            return QClientUpdateInfo(
                available: nil,
                installed: installed,
                checkedAt: Date(),
                error: error.localizedDescription
            )
        }
    }

    nonisolated static func scanOfficialBranches(
        repositoryURL: String,
        cacheURL: URL
    ) throws -> SourceReleaseInfo {
        let fm = FileManager.default
        try fm.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: cacheURL.appendingPathComponent("HEAD").path) {
            try runChecked(gitExecutable, ["init", "--bare", "-q", cacheURL.path])
            try runChecked(gitExecutable, ["-C", cacheURL.path, "remote", "add", "origin", repositoryURL])
        }
        try runGitFetch(
            repository: cacheURL,
            arguments: [
                "--prune", "--depth=1", "--filter=tree:0", "origin",
                "+refs/heads/*:refs/heads/*",
            ],
            timeout: 90
        )
        let output = try runChecked(
            gitExecutable,
            [
                "-C", cacheURL.path, "for-each-ref", "--sort=-committerdate",
                "--format=%(committerdate:unix)%09%(refname:short)%09%(objectname)%09%(subject)",
                "refs/heads",
            ]
        )
        let heads = GitBranchHeadParser.parse(output)
        guard let newest = GitBranchHeadParser.newestAnyBranch(in: heads) else {
            throw UpdateCenterError.noOfficialBranches
        }
        let highestVersionBranch = GitBranchHeadParser.newestVersionBranch(in: heads)
        let approvedDevelopment = try highestVersionBranch.flatMap {
            try resolveApprovedDevelopment(head: $0, cacheURL: cacheURL)
        }
        return SourceReleaseInfo(
            newestAnyBranch: newest,
            highestVersionBranch: highestVersionBranch,
            approvedDevelopment: approvedDevelopment,
            approvalIssue: nil,
            branchCount: heads.count,
            commitsBehind: nil
        )
    }

    nonisolated static func highestCachedVersionHead(cacheURL: URL) throws -> GitBranchHead {
        let output = try runChecked(
            gitExecutable,
            [
                "-C", cacheURL.path, "for-each-ref", "--sort=-committerdate",
                "--format=%(committerdate:unix)%09%(refname:short)%09%(objectname)%09%(subject)",
                "refs/heads",
            ],
            timeout: 10
        )
        let heads = GitBranchHeadParser.parse(output)
        guard let head = GitBranchHeadParser.newestVersionBranch(in: heads) else {
            throw UpdateCenterError.noOfficialBranches
        }
        return head
    }
}
