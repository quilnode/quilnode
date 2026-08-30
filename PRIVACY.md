# Privacy

QuilNode is local-first. It has no analytics SDK, telemetry collector, account,
hosted backend, or remote-control channel.

The app contacts only:

- `releases.quilibrium.com` for official release metadata and signed artifacts;
- `github.com/QuilibriumNetwork/monorepo` when the operator uses source-update
  channels or protocol-milestone discovery.
- `raw.githubusercontent.com/quilnode/quilnode` for the signed QuilNode
  application-update feed, and `github.com/quilnode/quilnode/releases` only
  after an operator accepts an available application update.

Quilscan links are opened in the operator's browser only after an explicit
click. QuilNode does not query Quilscan to populate the dashboard.

Node monitoring, balances, identity metadata, logs, and history come from the
local node and its separately managed matching qclient (signed release for a
signed node, exact pinned source commit for a source node). Private-key bytes are never returned to
the interface, clipboard, logs, widgets, notifications, update manifests, or
network clients.

Privacy Mode redacts sensitive and public-but-correlatable operational values
throughout the local interface. It reduces unintended disclosure during normal
use around other people as well as screenshots, recordings, presentations,
support sessions, and screen sharing. This includes active listener and
forwarded port numbers:
they are not credentials, but together with addresses and runtime details they
can reveal a node's service fingerprint. Labels, transports, health state, and
controls remain visible; only the classified values are masked. Editable port
fields require a deliberate local reveal before editing or copying. Privacy
Mode is a presentation feature, not encryption, network anonymity, or a change
to the underlying node data.
