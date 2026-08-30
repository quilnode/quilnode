import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    @ViewBuilder
    func updateProgressCard(_ progress: NodeUpdateProgress) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let displayedFraction = progress.timeWeightedFraction(at: timeline.date)
            let percentage = Int((displayedFraction * 100).rounded())
            // Terminal operations are historical facts. Their elapsed time
            // must freeze at completion instead of continuing to grow while
            // the result card remains visible.
            let elapsedReference = progress.status == .running ? timeline.date : progress.updatedAt
            let elapsed = max(elapsedReference.timeIntervalSince(progress.startedAt), 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    DashboardCircleIcon(
                        systemImage: progress.status == .failed
                            ? "xmark"
                            : (progress.status == .succeeded
                                ? "checkmark"
                                : (progress.status == .ready ? "shippingbox.fill" : progress.step.systemImage)),
                        tint: progress.status == .failed
                            ? theme.colors.danger
                            : (progress.status == .succeeded
                                ? theme.colors.success
                                : (progress.status == .ready ? theme.colors.info : theme.colors.warning)),
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress.phase)
                            .font(.subheadline.weight(.semibold))
                        Text(progress.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(progress.isEstimate ? "About \(percentage)%" : "\(percentage)%")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(progress.status == .failed ? theme.colors.danger : theme.colors.warning)
                            .quilLiveValueTransition(value: percentage)
                        Label(
                            updateContinuityTitle(progress),
                            systemImage: progress.status == .succeeded
                                ? "checkmark.circle.fill"
                                : progress.currentImpact.systemImage
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(updateContinuityTint(progress))
                    }
                }

                ProgressView(value: displayedFraction)
                    .progressViewStyle(.linear)
                    .tint(
                        progress.status == .failed
                            ? theme.colors.danger
                            : (progress.status == .succeeded ? theme.colors.success : theme.colors.warning)
                    )
                    .animation(motion.progress, value: displayedFraction)

                updateStageRail(progress)

                HStack(spacing: 14) {
                    Label(
                        "Step \(progress.currentStepNumber)/\(progress.orderedSteps.count)",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    Label("Elapsed \(durationLabel(elapsed))", systemImage: "clock")
                    if let range = progress.workflowRemainingRange(at: timeline.date) {
                        Label(
                            "ETA \(durationLabel(range.lowerBound))–\(durationLabel(range.upperBound))",
                            systemImage: "hourglass"
                        )
                    }
                    Spacer()
                    if progress.status == .running {
                        ProgressView().controlSize(.small)
                    } else if progress.status == .ready, releaseChecker.stagedUpdate != nil {
                        Button {
                            releaseChecker.requestResumeStagedUpdate()
                        } label: {
                            Label("Install staged update", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else if progress.status == .failed || progress.status == .succeeded {
                        Button("Dismiss") {
                            releaseChecker.dismissOperationResult()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                if progress.isEstimate && progress.status == .running {
                    HStack {
                        Text(
                            "Time progress uses measured stages on this Mac. The active step stays incomplete until its command exits successfully."
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        Spacer()
                        if progress.logURL != nil {
                            Button {
                                withAnimation(motion.disclosure) {
                                    buildLogExpanded.toggle()
                                }
                            } label: {
                                Label(
                                    buildLogExpanded ? "Hide build output" : "Show live build output",
                                    systemImage: buildLogExpanded ? "chevron.up" : "chevron.down"
                                )
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                } else if progress.logURL != nil {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(motion.disclosure) {
                                buildLogExpanded.toggle()
                            }
                        } label: {
                            Label(
                                buildLogExpanded ? "Hide build output" : "Show build output",
                                systemImage: buildLogExpanded ? "chevron.up" : "chevron.down"
                            )
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }

                if progress.status == .running {
                    Label(
                        "You can switch pages or close this window. The menu-bar app owns this operation and keeps it running.",
                        systemImage: "menubar.rectangle"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if buildLogExpanded, let logURL = progress.logURL {
                    InlineBuildLogView(
                        logURL: logURL,
                        isLive: progress.status == .running,
                        privacyModeEnabled: privacyModeEnabled
                    )
                    .transition(motion.revealTransition)
                }
            }
            .padding(16)
            .controlSurface(tint: progress.status == .failed ? theme.colors.danger : theme.colors.warning)
            .onChange(of: progress.status) { _, status in
                if status == .failed {
                    withAnimation(motion.disclosure) {
                        buildLogExpanded = true
                    }
                }
            }
        }
    }

    func updateStageRail(_ progress: NodeUpdateProgress) -> some View {
        let steps = progress.orderedSteps
        let current = max(progress.currentStepNumber - 1, 0)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach([NodeUpdatePlanSection.preparation, .activation], id: \.rawValue) { section in
                let sectionSteps = steps.filter { $0.section == section }
                if !sectionSteps.isEmpty {
                    HStack(spacing: 7) {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                        Text(
                            section == .preparation
                                ? "Node stays online"
                                : progress.workflow.serviceImpactDuringActivation.title
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(section == .preparation ? theme.colors.success : theme.colors.warning)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.16))
                            .frame(height: 1)
                    }

                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 8),
                            count: min(5, sectionSteps.count)
                        ),
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(sectionSteps) { step in
                            let index = steps.firstIndex(of: step) ?? 0
                            let completed = progress.status == .succeeded || index < current
                            let active = progress.status != .succeeded && index == current
                            HStack(spacing: 5) {
                                Image(
                                    systemName: completed
                                        ? "checkmark.circle.fill"
                                        : (active ? "circle.inset.filled" : "circle")
                                )
                                .foregroundStyle(
                                    completed
                                        ? theme.colors.success
                                        : (active
                                            ? (progress.status == .failed ? theme.colors.danger : theme.colors.warning)
                                            : Color.secondary))
                                Text(step.shortTitle)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .font(.caption2.weight(active ? .semibold : .regular))
                            .foregroundStyle(completed || active ? Color.primary : Color.secondary)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Step \(index + 1) of \(steps.count), \(step.title)")
                            .accessibilityValue(completed ? "Complete" : (active ? "Current" : "Pending"))
                        }
                    }
                }
            }
        }
    }

    func updateContinuityTitle(_ progress: NodeUpdateProgress) -> String {
        if progress.status == .succeeded { return "Node online and verified" }
        if progress.status == .failed && progress.step.section == .activation {
            return "Previous runtime restored"
        }
        return progress.currentImpact.title
    }

    func updateContinuityTint(_ progress: NodeUpdateProgress) -> Color {
        if progress.status == .failed { return theme.colors.danger }
        if progress.status == .succeeded || progress.currentImpact != .briefRestart {
            return theme.colors.success
        }
        return theme.colors.warning
    }

    func durationLabel(_ interval: TimeInterval) -> String {
        let seconds = max(Int(interval.rounded()), 0)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

}
