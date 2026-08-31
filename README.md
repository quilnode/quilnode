<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="112" alt="QuilNode application icon">
</p>

<h1 align="center">QuilNode</h1>

<p align="center">
  A native, local-first macOS console for operating a Quilibrium node.
</p>

> [!WARNING]
> **Alpha software — not production-ready.** Bugs, security issues, and breaking
> changes are possible. QuilNode manages a privileged local service and can
> change node software and identity files. Failures can cause downtime, data
> loss, loss of access to an identity, or missed rewards.
>
> **Review before use and keep independent, tested recovery backups.** Do not
> rely on this alpha for critical infrastructure or use an identity whose loss
> or compromise you cannot accept.

QuilNode is an independent, unofficial community project. It is not affiliated
with, endorsed by, audited by, or supported by Quilibrium Inc. or the Quilibrium
protocol maintainers. See [NOTICE.md](NOTICE.md) for the project statement and
license warranty terms.

## Before you run it

- **Review the risks.** Read the source and [security model](SECURITY.md), or ask
  a qualified reviewer you trust to assess them. Review feedback is welcome,
  including from contributors who cannot run macOS.
- **Start with a test identity.** Evaluate installation, updates, and recovery
  in an isolated test environment before adopting an existing node.
- **Keep your own recovery path.** Back up identity material and essential node
  configuration independently of QuilNode. Verify restoration in an isolated
  environment before importing, migrating, or switching a valuable identity.
  An app-managed backup is not a substitute for an independent recovery copy.
- **Verify what you install.** Use this repository's
  [published releases](https://github.com/quilnode/quilnode/releases), check the
  release notes, and verify the published checksums and signatures. A signature
  establishes integrity and signing authority, not freedom from vulnerabilities.

Automated tests, static analysis, and AI-assisted reviews are useful checks;
they are not an independent security audit or certification. Public source
allows inspection, but neither source availability nor any review can guarantee
safety. Operator review complements—not replaces—maintainer testing and fixes.

## Operator guide

Use the [operator guide](https://quilnode.com/guide/) for step-by-step instructions:

- [Download and verify](https://quilnode.com/guide/#download-and-verify), then
  [install and handle macOS first-open prompts](https://quilnode.com/guide/#first-open).
- [Set up the node and authorize its local service](https://quilnode.com/guide/#node-setup),
  then [check firewall and router readiness](https://quilnode.com/guide/#network).
- [Update the app or node](https://quilnode.com/guide/#updates)—they are separate
  update systems with different approval policies.
- [Create an independent backup and restore an identity](https://quilnode.com/guide/#recovery).
  Verified recovery exports are not encrypted by QuilNode; use encrypted storage
  you control and test restoration before relying on it.
- [Understand security and privacy](https://quilnode.com/guide/#security) and
  [troubleshoot or report a problem](https://quilnode.com/guide/#troubleshooting).

The DMG installs the app by dragging it into Applications. The app then guides
node setup; users do not need to clone this repository or compile the app.
Closing or quitting QuilNode does not stop the separate background node service.

## What QuilNode does

QuilNode brings node operation into one native macOS application:

- live local status, frames, peers, archives, allocations, shards, CPU, memory,
  uptime, balance, seniority, epoch progress, and reward evidence;
- start, stop, restart, update, rollback, firewall, and network-readiness flows;
- signed Stable, approved development, and exact-source update channels;
- first-install automation for the official node and matching `qclient`;
- identity creation, legacy migration, switching, recovery, and verified backup;
- a menu-bar controller, dashboard, local alerts, diagnostics, and Privacy Mode;
- theme families with light/dark variants and safe data-only customization.

Operational data comes from the installed node, its loopback interfaces, and
its locally managed matching `qclient`. QuilNode does not use an explorer or a
hosted monitoring service to populate the dashboard.

## Local self-custody model

The graphical application never opens, parses, hashes, copies, modifies,
displays, or transmits private-key bytes.

Sensitive operations are handled by a narrowly scoped local service that:

1. authenticates the controlling macOS account and the exact signed app;
2. accepts only a fixed, typed operation vocabulary—never arbitrary shell
   commands or unconstrained paths;
3. validates ownership, file type, permissions, links, sizes, and permitted
   roots before touching identity material;
4. performs transactional backup, activation, health validation, and rollback;
5. returns only public metadata or sanitized status to the interface.

Routine monitoring remains local. There is no account, telemetry collector,
analytics SDK, hosted key service, or remote-command endpoint. See
[PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Verified installation and updates

Official node and `qclient` artifacts are not bundled with the app. QuilNode
downloads them from the official release channel and verifies their published
SHA3-256 digests and Ed448 signature quorum twice: once while staging and again
inside the privileged boundary immediately before installation.

Source builds are an explicit advanced channel. They use an immutable upstream
commit, bounded downloads, exact Git LFS objects, a deny-by-default build
sandbox, and a network-denied version probe. Selecting a source channel never
silently weakens the signed-release path.

QuilNode application updates use a separate Ed25519 update identity and a
signed Sparkle feed. Automatic installation is disabled; an operator approves
each application replacement. The application-signing identity, update key,
node identity, and GitHub identity are separate trust domains.

Community-signed QuilNode releases use the project's certificate, not Apple
Developer ID, and are not notarized by Apple. macOS may block the first open.
Read [Apple's guidance](https://support.apple.com/en-us/102445) before deciding
whether to allow the app. Never disable Gatekeeper globally or bypass a warning
that software is damaged or will harm your Mac.

## Privacy Mode

Privacy Mode hides only values that can identify or fingerprint an operator:
peer and prover identities, wallet addresses and totals, seniority, active
allocations and shards, local process details, and active network ports. Labels,
health states, controls, and public protocol context remain useful.

Privacy Mode reduces accidental disclosure in screenshots, recordings,
presentations, support sessions, and ordinary use around other people. It is a
presentation boundary—not encryption or network anonymity.

## Requirements

To run a downloaded release:

- Apple Silicon Mac
- macOS 14 or later

To build the application from source, also install Xcode 16 or later and
XcodeGen for the signed application bundle. These developer tools are not
required to run the DMG release.

The official node-install path does not require Homebrew, Rust, Cargo, CMake,
`protoc`, or a compiler toolchain. Development/source-node channels may require
those tools and always explain the requirement before changing the system.

## Build and verify

Clone the repository, then run the complete local gate:

```bash
scripts/quality-gate.sh
```

The gate enforces source layout, formatting, tests, key-boundary invariants,
static security rules, secret exclusions, and release-metadata privacy.

Build the signed local candidate only when the project release identity is
available in its dedicated keychain:

```bash
scripts/release/build-openssl-toolchain.sh
APP_PATH="$(scripts/build-app.sh | tail -1)"
open "$APP_PATH"
```

Build products, signing material, release evidence, local node state, and
operator documentation live outside the repository. No private credential or
node identity is required to compile and test the Swift packages.

Run the read-only JSON probe:

```bash
swift run quilnode-probe
```

## Source layout

```text
Sources/
├── QuilNodeApp/        SwiftUI shell, features, presentation, coordination
│   ├── Application/    process entry points and app-level commands
│   ├── Dashboard/      window shell, shared chrome, and overview composition
│   ├── DesignSystem/   reusable components, theme, layout, motion, and copy
│   ├── Features/       operator workflows grouped by responsibility
│   └── Infrastructure/ local adapters for node, network, and persistence
├── QuilNodeCore/       deterministic domain rules and local observation
├── QuilNodeShared/     IPC, release, filesystem, and theme contracts
├── QuilNodeHelperKit/  privileged implementation behind one narrow facade
├── QuilNodeHelperCLI/  minimal privileged-service entry point
├── QuilNodeProbe/      read-only diagnostics executable
└── QuilNodeReleaseVerifier/  small static SHA3-256 and Ed448 verifier

Tests/
├── QuilNodeAppTests/
├── QuilNodeCoreTests/
├── QuilNodeSharedTests/
└── QuilNodeHelperKitTests/
```

Larger feature folders separate `Coordination`, `Infrastructure`, `Models`,
`Persistence`, `Presentation`, `Staging`, `Views`, and `PreviewSupport` where
those roles exist. The app and privileged helper consume one versioned wallet
wire schema from `QuilNodeShared`; neither side redeclares it. Source updates
flow through named checkout, compilation, matching-client, and sealing phases,
with a small facade preserving their order.

Feature tests mirror the corresponding feature name. Swift files cannot sit
loose at a feature root, and the dashboard cannot retain a computed view with
no reachable caller. Non-UI modules cannot import presentation frameworks,
and production files have a 375-line review budget. These rules, dependency
direction, case-safe filenames, wallet schema ownership, update-pipeline shape,
and test limits are enforced by
`scripts/architecture-audit.sh`; `scripts/architecture-report.sh` prints the
current target, feature-responsibility, and test inventory without modifying
the repository.

Release artifacts are built locally by a fail-closed pipeline; this project
does not depend on GitHub Actions.

### Release packaging

`scripts/release/prepare-release.sh` builds the drag-to-Applications DMG,
generates the Sparkle feed and artifact inventory, and signs the release
report. It requires clean source, the exact signed version tag, an independently
approved tag-signer fingerprint (`QUILNODE_RELEASE_TAG_SIGNER`), and the separate
update-signing capability (`QUILNODE_UPDATE_KEY_PASSWORD_FILE`). It never tags,
pushes, uploads, or publishes anything.

Use `--rehearsal` to test packaging from clean committed source without a release
tag. Rehearsal reports and feeds are explicitly marked and are rejected by
normal release verification. They do not qualify a public release.

`scripts/release/verify-release.sh /path/to/release` verifies the report, feed
and archive with public keys before mounting the DMG, then checks the exact
delivered bundle, licenses and inventory. Verification needs no private key.
Rehearsal verification also requires `--rehearsal`. Run
`scripts/release/test-evidence.sh` for the disposable-fixture regression tests.

## Contributing and security

Code reviews, usability feedback, and reproducible bug reports are welcome.
For non-security bugs, open an [issue](https://github.com/quilnode/quilnode/issues)
with the app version, macOS version, reproduction steps, and expected versus
actual behavior. Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change.
Never attach real identities, keysets, node configuration, wallet exports,
stores, logs, or unredacted diagnostics to a public issue.

Suspected vulnerabilities must be reported privately as described in
[SECURITY.md](SECURITY.md), not in public bug reports or pull requests.

## License

QuilNode is released under
[GNU Affero General Public License v3.0 only](LICENSE). Third-party notices,
warranty limits, and the independent-project statement are in
[NOTICE.md](NOTICE.md).
