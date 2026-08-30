# Contributing

Run the complete local gate before opening a change:

```bash
scripts/quality-gate.sh
scripts/test-release-verifier.sh
```

The automated architecture audit enforces dependency direction, source
placement, file-size tripwires, and retirement of legacy source trees. Keep UI
and coordination in `QuilNodeApp`, deterministic policy in `QuilNodeCore`, wire
and filesystem contracts in `QuilNodeShared`, and privileged implementation in
`QuilNodeHelperKit`. Run `scripts/architecture-report.sh` for a compact source
inventory. Xcode's bundled `swift-format` is the formatting authority; run
`xcrun swift-format format --in-place --recursive --configuration .swift-format
Sources Tests` before the gate when needed.

Tests follow their production module: presentation policy lives in
`QuilNodeAppTests`, shared contracts and bounded files in `QuilNodeSharedTests`,
deterministic observation policy in `QuilNodeCoreTests`, and privileged
command/service behavior in `QuilNodeHelperKitTests`.

Do not add real keysets, node configuration, wallet exports, database stores,
logs, screenshots with live identifiers, signing material, or bundled binaries.
Changes to the privileged protocol must update the threat model and include
negative tests for authentication, paths, links, ownership, permissions, input
size, interruption, and rollback.

Production first-install changes must preserve the signed-release default. A
source checkout is an advanced channel and may not silently replace a signed
artifact.
