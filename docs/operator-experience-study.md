# QuilNode operator experience study

Study date: 26 October 2026. Baseline: alpha.6 (116). Scope: native macOS application, local node observations, information hierarchy and presentation accuracy.

## Decision

Make Overview answer four questions: Is the process running? What needs attention? What has the local node observed? What rewards or coins can it report? Keep network exploration, exact values, identities and diagnostic evidence available through clearly named destinations and disclosures.

An assignment is not execution; execution is not proof production; claimable rewards are not spendable coins. These distinctions control the design, including color and wording.

## Research and comparison

| Reference | Evidence reviewed | Application to QuilNode |
| --- | --- | --- |
| [Quilscan dashboard](https://quilscan.com/) | Live dashboard and shard coverage pages, captured during this study. It separates membership coverage from production measured over an explicit GLOBAL-frame window. | Label scope and observation time. Never turn membership counts into a production or earnings claim. |
| [Quilscan shard coverage](https://quilscan.com/rings) | Live coverage summary, lifecycle counts, searchable shard rows and abbreviated identifiers. | Keep overview counts small, with the full shard inspector and search in Network. Public explorer totals are not local connectivity totals. |
| [Quilscan Node Console](https://quilscan.com/node-console) and [agent source](https://github.com/quilscan-com/quilscan-agent) | Public connection screen and documented agent capabilities. Authenticated console was not accessed; no agent installed. | Keep read-only observations distinct from operations. QuilNode continues to use its existing local service; this study adds no remote monitoring connection. |
| [Etherscan site settings](https://info.etherscan.com/site-settings/) and [transaction guide](https://info.etherscan.com/viewing-transactions-on-etherscan/) | Official documentation on advanced details and transaction inspection. Main explorer access was blocked by its verification page. | Important values stay visible; less frequent technical details are explicitly expandable. This is a documented-pattern comparison, not a completed live Etherscan transaction audit. |
| [Q1 Wallet](https://github.com/lamat1111/Q1-Wallet) | Community project's README, menu categories and wallet-management scope; not executed. | Balances deserve an obvious destination. Custody and transaction operations remain separate from inspecting balances. Its legacy command assumptions are not treated as current qclient specifications. |
| [Apple: Charts](https://developer.apple.com/design/human-interface-guidelines/charts) | Official guidance on hierarchy, descriptive content, accessible charts, units and interaction. | Explain chart scope, retain text summaries, avoid color-only meaning and never require interaction to see essential status. Missing samples appear as gaps. |
| [Nielsen Norman Group: Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) | Guidance on prioritizing common tasks and revealing advanced functionality. | Short overview; explicit exact-value, identity, epoch and log disclosures. No hidden critical errors. |
| [Grafana dashboard best practices](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/) | Official guidance on consistent dashboard structure and operational monitoring. | Put status and resources together; provide paths from symptoms to detailed evidence. Avoid decorative visuals competing with operational signals. |

## Protocol and source cross-check

The official [qclient command list](https://docs.quilibrium.com/docs/run-node/qclient/commands/command-list/) and [node command documentation](https://docs.quilibrium.com/docs/run-node/qclient/commands/node/) describe the command families, but their example output does not capture all current fields. Parsing decisions were checked against the installed source revisions instead of copying documentation examples.

- Node: [`74e82f9fad34`](https://github.com/QuilibriumNetwork/monorepo/tree/74e82f9fad34), including `protobufs/node.proto` and `crates/quil-engine/src/coverage.rs`.
- qclient: [`8e80d12faa68`](https://github.com/QuilibriumNetwork/monorepo/tree/8e80d12faa68), especially `crates/quil-client/src/commands/node/prover/status.rs`, `local_execution.rs` and `commands/token/wallet.rs`.
- The installed node's mainnet coverage target is six memberships. It is a coverage threshold, not the explorer's ring tier or a proof-production test. The UI now calls this “Coverage at target.”

| Available evidence | Meaning / limit | Placement |
| --- | --- | --- |
| Local service and process check | Running or stopped on this Mac; does not establish chain synchronization | Overview heading and persistent footer |
| GLOBAL head and received frame | Distinct local observations; a received frame need not be materialized at the head | Overview progress card, Activity and Network |
| Peer count, socket and listener inspection | This node's connections and inbound evidence; not network-wide population | Overview count, Connectivity details |
| Prover registry assignments | Active, joining, leaving and other lifecycle states; not proof production | Overview and Network |
| Worker execution | Host state, app frame, last advance, observation age, recovery phase/failures and seal recording | Worker cards and a direct Workers tab with expandable details |
| Worker storage | Reported available and total storage; a zero total can mean not reported | Network worker details |
| Shard table | Locally returned memberships, rings, storage and estimates; source may be cached | Network, with provenance and coverage wording |
| Epoch and boundary | Node-supplied epoch parameters; ETA depends on local observed pace | Overview disclosure and Network |
| Claimable rewards | Requires a mint operation before becoming coins | Wallet and overview; never added to coin balances |
| Confidential and legacy coins | Independent read results; missing is not zero; local unspent read is not a finality guarantee | Separate wallet cards and exact details |
| Coin counts and reported reward frame | Supporting wallet read evidence, when returned | Exact-value disclosure |
| Seniority and public identities | Consensus observation and distinct identity roles | Wallet & identity detail workspace |
| CPU, resident memory, process elapsed time | Node-process resource readings; CPU share of total Mac capacity; memory uses GiB | Overview and menu bar |
| Local log warnings | Bounded evidence requiring interpretation, not automatic repair instructions | Diagnostics summaries with full evidence on expansion |
| Local history | Sampled while the app runs, not a complete chain ledger or uptime SLA | Activity, with observation gaps and sample-based labels |

Additional RPC surfaces (remote fee quotes, token submission, global production analytics and gossip payload-byte counters) are not promoted to Overview. They do not answer its primary questions, and payload counters are not measured network-interface bandwidth. This change does not add transfers, minting, explorer-based private balances, estimated daily income or remote telemetry.

## Screen audit and implemented response

Severity: P1 = misleading operational meaning; P2 = material discoverability or readability issue; P3 = refinement. This is an expert inspection with live local observations, not a user-testing study.

| Step | Screen / baseline health | Finding | Implemented response |
| --- | --- | --- | --- |
| 1 | Overview — needs improvement | P1: active assignments visually resemble healthy execution. P2: large illustration and absent-credit headline dominate; CPU/memory/uptime are difficult to find. | Compact process status, four operational cards, visible resources, real execution observations, and optional protocol/map details. |
| 2 | Activity — useful but misleading gaps | P1: missing peer reads can become zero and create false mesh events. Lines connect across long observation gaps. | Preserve whether peers were observed; suppress invented zero/events; separate chart segments across gaps, resets and stops. Label “Running samples” rather than implying measured uptime. |
| 3 | Network — useful, terminology needs precision | P1: “Healthy” membership coverage may imply production. Worker inspector omits available execution data. | “Coverage at target,” explicit threshold/scope, missing-data placeholders, worker execution/recovery detail, a direct Workers tab and focused overview links. |
| 4 | Wallet & identity — wrong priority | P2: available rewards are subordinate to identity artwork and a single unavailable balance summary. Long fractional values are difficult to scan. | Balances first, separate components, compact decimal strings, exact amounts/copy actions and independent wallet observation time. Public identities remain expandable. |
| 5 | Recovery — retain | Existing separate custody workflow clearly distinguishes local rollback and separate backup. | Preserve safeguards and workflows. Make the wallet's recovery link a secondary action. No custody operation performed during the study. |
| 6 | Updates — useful, unnecessarily dense at rest | P3: six-step idle explanation competes with available updates and policy. | Collapse the idle explanation under “How node updates work.” Active progress and failures remain directly visible. |
| 7 | Diagnostics — evidence too dense | P2: full structured log payloads obscure the human-readable subject. | Readable message first; timestamp and full sanitized evidence on expansion. No repair is inferred or executed from log text. |
| 8 | Settings — retain | Startup explains boot vs login and sleep/FileVault boundaries. Privacy explains its display-only scope. | Retain existing settings and consent flows. No new permissions or administrator interaction required by these presentation changes. |

## Value rules

1. Unknown is an em dash or “Unavailable,” never an invented zero. Explicitly observed zero remains zero.
2. QUIL amounts remain decimal strings. Compact display uses up to six fractional digits, marks truncation with `≈`, and shows `<0.000001` for smaller nonzero amounts. Exact copy uses the unrounded decimal value, with a dot separator.
3. Do not add rewards, confidential coins and legacy coins into a synthetic total.
4. Give independently refreshed values their own observation timestamps. A current process check does not freshen a cached wallet or worker reading.
5. Preserve complete, privacy-protected identities and evidence in detail views. Abbreviation is for scanning, not the underlying value.
6. Local GLOBAL head, received frame and worker app frame are separately named. No “fully synced” claim is derived from a fresh local sample alone.
7. Running a host is not proof of producing frames. The worker parser honors qclient's stale-source state and ages cached reads after two normal polling intervals.
8. CPU is explicitly scoped to Mac capacity; RSS is labeled GiB; process uptime is distinct from the share of running samples in local history.

## Validation and limits

Parser tests cover current worker output, old cache decoding, independent execution versus assignment, source age, unavailable observations and bounded parsing. Presentation tests cover tiny and very large exact amounts, locale decimal marks, outdated reads, worker attention, bootstrap states, process uptime and binary memory units. Activity tests cover missing peers versus observed zero and disconnected chart segments.

The local quality gate covers architecture, strict formatting, tests, helper composition, repository security and metadata privacy. Signed app builds are checked separately. Visual evidence is retained privately because live screenshots can contain wallet amounts and local identifiers; it is not committed to this public repository.

Verification on 26 October 2026:

- 291 Swift tests passed, including the new parser, precision, freshness, event-age and chart-gap cases. The release-evidence suite passed 28 tests.
- Architecture and strict formatting checks passed. The repository security checks and configured Semgrep rules reported no findings; this is a bounded scan, not an independent security audit.
- The native release build passed its signed-code, hardened-runtime, entitlement, dependency and metadata checks. The separate release-verifier tests passed signature, digest, tamper-rejection and file-boundary cases.
- Visual review covered all seven destinations and the four settings tabs. Checks included dark/light appearance, 994 × 759 and 1264 × 907 windows, keyboard navigation, exact-value disclosures, diagnostic evidence, direct worker navigation and Privacy Mode in visible text and accessibility labels.
- Compact overview cards were corrected from an uneven wrap to a two-column grid. The small illustrative map uses fewer, spaced labels. Worker details expose recovery phase, failures and seal evidence independently; frame-advance age is separate from read freshness.
- A live Privacy Mode toggle exposed reused placeholder rows in the new lazy worker grid. Its identity now changes with the masking state, preventing placeholder IDs and real core IDs from retaining one another's rows or disclosure state.
- Dashboard replacements retained a rollback copy and left the existing node process running. No administrator or firewall prompt appeared during these presentation-build relaunches. This observation does not certify behavior on every Mac or a cold reboot.

Current upstream limitations remain visible: an unavailable confidential-balance read is reported separately from successful reward reads, and worker recovery warnings reflect the node's returned evidence. Presentation changes neither create missing chain data nor prove that rewards are accruing. The development build is installed locally; publishing an update requires a separately versioned release.

The comparison does not certify accessibility, prove consensus correctness or substitute for an independent security audit. No paid or authenticated explorer workspace was inspected. Changes preserve the existing local custody, trust and update boundaries.
