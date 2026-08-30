<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="112" alt="QuilNode application icon">
</p>

<h1 align="center">QuilNode</h1>

<p align="center">
  A native, local-first macOS console for operating a Quilibrium node.
</p>

> [!WARNING]
> QuilNode is an independent, unofficial community project. It is not
> affiliated with, endorsed by, audited by, or supported by Quilibrium Inc. or
> the Quilibrium protocol maintainers. It cannot guarantee protocol
> eligibility, seniority, uptime, rewards, token value, or fitness for valuable
> infrastructure.

## Status

QuilNode is under active development. Install it only from this repository's
official releases, verify the published checksums and signatures, and keep an
independent recovery copy of every node identity before operating the node.

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

## Self-custody by construction

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

## Privacy Mode

Privacy Mode hides only values that can identify or fingerprint an operator:
peer and prover identities, wallet addresses and totals, seniority, active
allocations and shards, local process details, and active network ports. Labels,
health states, controls, and public protocol context remain useful.

Privacy Mode reduces accidental disclosure in screenshots, recordings,
presentations, support sessions, and ordinary use around other people. It is a
presentation boundary—not encryption or network anonymity.

## Requirements

- Apple Silicon Mac
- macOS 14 or later
- Xcode 16 or later for source builds
- XcodeGen for the signed application bundle

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

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Never attach
real identities, keysets, node configuration, wallet exports, stores, logs, or
unredacted diagnostics to a public issue.

Suspected vulnerabilities must be reported privately as described in
[SECURITY.md](SECURITY.md). Security review reduces risk; no software can make a
credible promise of zero vulnerabilities.

## License

QuilNode is released under
[GNU Affero General Public License v3.0 only](LICENSE). Third-party notices,
warranty limits, and the independent-project statement are in
[NOTICE.md](NOTICE.md).
