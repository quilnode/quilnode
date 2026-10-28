# Node discovery and listener audit — 28 October 2026

## Findings and fixes

### Frequent automatic checks could stop permanently

Rescheduling cancelled the in-flight signal task and changed its generation, but retained its task handle. The old task correctly refused to clear a newer generation's state. Unfortunately, the next probe also refused to start while that obsolete handle remained non-nil. The timer expired without scheduling a successor. Authorization synchronization and policy changes both exercise this lifecycle.

Cancel-and-replace now detaches the obsolete handles before replacing the generation. Late completions cannot overwrite a replacement. Probe cancellation reaches its worker. Successful probes clear transport backoff; full reconciliation retains its separate failure backoff. Explicit retries clear candidate suppression only when an operation can actually start. Status text distinguishes retries and overdue checks from readiness.

The six-hour fallback now preserves the remaining interval across relaunches. Reopening the app no longer adds another six hours to a pending reconciliation.

The observed installation had continued receiving approved updates through its fallback check. Its `.109` installation completed on 28 October at 02:45:54 UTC; the frequent signal baseline had remained at 26 October, 15:15 UTC. These were two different discovery paths, not evidence that every automatic update had failed.

### Healthy listeners were reported missing

On the audited macOS 27 installation, `netstat -anv -p tcp` returned the expected listeners in Terminal, but returned zero bytes and exit status zero when launched by a compiled Swift process. This reproduced outside QuilNode's bounded command runner. Empty output was incorrectly accepted as a complete socket inspection.

Apple documents [privacy hardening for network topology observation](https://developer.apple.com/forums/thread/841958) and [successful calls whose results are scrubbed](https://developer.apple.com/forums/thread/822025?page=2). The fix does not depend on broad network-topology access. It inspects one process's descriptors with `proc_pidinfo` and `proc_pidfdinfo`. For the isolated node account, the existing authenticated service chooses the managed launchd PID itself. The request accepts no caller-selected PID or executable, and the response contains only PID, observation time, and TCP/UDP port sets. Descriptor enumeration and execution time are bounded.

Unavailable inspection is distinct from missing ports. Node-reported inbound traffic remains valid independent evidence. Results from a previous node PID cannot validate or blame its replacement. A complete current-process inspection that finds a required port absent still reports a real configuration issue.

### A reconnect could make an installed qclient look absent

Release discovery discarded local-service errors, and the UI treated a nil response as “Not managed,” offering installation. The client model already distinguishes an observed missing installation from an unavailable read. Discovery now preserves the error; unavailable reads show “Unavailable” with a read-only recheck. Installation requires an actual status observation. Missing, invalid, and verified clients have distinct labels.

## Official `.108–.109` notes and remaining upstream state

The official [`subpatch` marker](https://github.com/QuilibriumNetwork/monorepo/blob/v2.1.0.25/subpatch) was `109`, last changed by [`1fddb85171a41d539df4cf86f9a497df86741664`](https://github.com/QuilibriumNetwork/monorepo/commit/1fddb85171a41d539df4cf86f9a497df86741664). The running node matched that exact approved commit. Nine subsequent unapproved commits were correctly excluded by Approved Development policy.

- [#1007](https://github.com/QuilibriumNetwork/monorepo/pull/1007) adds backoff for a shard frame unavailable from archives. The audited node logged missing shard frame `29239` and `retry_in_secs: 600`, matching this behavior. Some workers remained blocked waiting for predecessor state. Healthy listeners do not establish successful worker production.
- [#1008](https://github.com/QuilibriumNetwork/monorepo/pull/1008) waits for consensus hosts and storage jobs on shutdown. Repeated restarts are not a remedy for unavailable archive data.
- [#1009](https://github.com/QuilibriumNetwork/monorepo/pull/1009) restores archive-sourced shard sizes for regular nodes.
- [#1010](https://github.com/QuilibriumNetwork/monorepo/pull/1010) retries other archives when a frame copy fails verification. Recovery can depend on archive operators upgrading; the desktop app cannot repair an upstream archive's data.

The [official port documentation](https://docs.quilibrium.com/docs/run-node/quick-start/) confirms the residential TCP profile's master ports, 8336 and 8340. Both were verified after the fix. No router or firewall change was required.

## Validation and delivery

Regression tests cover rescheduling during a probe, obsolete completion, manual-policy cancellation, failure backoff, relaunch timing, explicit retries, unavailable qclient reads, actual native TCP/UDP sockets, and PID changes. The native socket tests also pass Address Sanitizer. Repository validation includes architecture, formatting, test suites, helper composition, security boundaries, release-evidence tests, metadata privacy, and Semgrep.

The signed local build was installed and visually checked. The service upgraded to build 125 through its existing signed self-upgrade path, with no new administrator or firewall prompt. The node PID stayed unchanged. A real signal cycle advanced from 07:38:32 UTC to 07:43:54 UTC and scheduled its successor, while the UI verified both required listeners. Private before/after screenshots and logs are retained outside the repository.

These fixes are included in the alpha.8/build 118 release candidate. The local validation above was performed before the version bump. Public distribution requires the separate signed release pipeline, verification of the uploaded artifacts, and publication of the signed update feeds.
