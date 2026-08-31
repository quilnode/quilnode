# Security policy

QuilNode controls a local node that may hold valuable self-custodied identity
material. Do not post vulnerability details in public issues or pull requests.

## Supported versions

Only the latest published QuilNode release is supported. Security fixes are not
backported unless a release announcement explicitly says otherwise.

Application updates require both the Ed25519 archive signature and a signed
Sparkle appcast. The code-signing identity used by the privileged local service
is a separate project key. Node identity, application signing, update signing,
and source-hosting credentials are independent trust domains.

Sparkle permits application-certificate rotation when authorized by the update
signing key; it does not require the previous application certificate as a
second signer. Release packaging separately rejects an unexpected certificate
or bundle identifier. The privileged service continues to require its pinned
application identity, so certificate migration requires explicit qualification
and service authorization. Protect the update-signing key as an executable
code distribution capability, not merely a metadata-signing key.

## Reporting a vulnerability

Use **Report a vulnerability** under
[Security → Advisories](https://github.com/quilnode/quilnode/security/advisories)
when the private reporting form is enabled. Include the affected version,
macOS version, reproduction steps using disposable test data, and impact.
Do not include real `config.yml`, `keys.yml`, private keys, passwords, wallet
exports, or unredacted diagnostic bundles, even in a private report.

If the form is unavailable, open a contact-only
[issue](https://github.com/quilnode/quilnode/issues) titled **Security contact
request**, asking for a private reporting channel. Include no vulnerability
description, reproduction steps, logs, screenshots, or attachments. Wait for a
private channel before sharing the report. This follows
[GitHub's private-reporting guidance](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately);
a public contact request is not a public vulnerability report.

## Security boundary

- The SwiftUI interface never opens, parses, hashes, copies, modifies, displays,
  or transmits private-key bytes.
- A root-owned local service performs only a fixed operation vocabulary. It
  returns public identity metadata, status, or a sanitized result—not key bytes.
- Official release digest and Ed448 quorum checks run once before authorization
  and independently again inside the privileged boundary.
- Downloaded executables never run in the interface process. Root-owned copies
  are re-verified before a restricted, network-denied runtime version probe.
- The service authenticates both the controlling Unix account and the exact
  code-signed app before accepting a request.
- Operator-selected import/export folders are path capabilities. The service
  validates their permitted roots, ownership, type, symbolic links, hard links,
  permissions, exact filenames, and size limits.
- Key mutations are local, transactional, backed up before activation, and
  rolled back when validation fails. Stores are outside wallet transactions.
- Recovery exports use descriptor-relative exclusive creation and byte-for-byte
  read-back verification; subprocess and network inputs have explicit time and
  size limits.
- Interface journals and log paths are untrusted after relaunch. Recovery reads
  are confined to private app-owned roots, and state writes atomically replace
  destinations without following links.
- Unauthenticated local clients receive no PID, service-account, capability,
  or build metadata.
- QuilNode has no telemetry, remote command endpoint, or hosted key service.

Security review reduces risk; it does not establish that software has “zero
vulnerabilities.” Public releases require the local preflight, clean-machine
matrix, and independent review recorded in the release checklist.

## Distribution security profiles

Community-signed builds use a documented Hardened Runtime library-validation
exception so the exact-pinned Sparkle framework can load. Every nested
executable is sealed with the same project certificate, update archives and
feeds are signed, and the app accepts no arbitrary plug-in path.

Developer ID builds must keep library validation enabled and complete Apple's
notarization flow. Release verification rejects a build whose entitlements do
not match its declared distribution profile.

The complete working threat model and release evidence are maintained outside
the public source tree so machine-local context cannot enter repository history.
