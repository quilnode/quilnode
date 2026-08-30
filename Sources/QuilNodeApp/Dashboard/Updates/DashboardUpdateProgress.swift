import SwiftUI

extension DashboardView {
    @ViewBuilder
    func updateProgressCard(_ progress: NodeUpdateProgress) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let displayedFraction = progress.timeWeightedFraction(at: timeline.date)
            let percentage = Int((displayedFraction * 100).rounded())
            let elapsedReference = progress.status == .running ? timeline.date : progress.updatedAt
            let elapsed = max(elapsedReference.timeIntervalSince(progress.startedAt), 0)
            let currentStage = UpdateFlightStage.current(for: progress.step)

            VStack(alignment: .leading, spacing: 12) {
                updateOperationHeader(progress, percentage: percentage)
                updateFlightSectionLabels
                updateFlightStageGrid(
                    current: progress.status == .succeeded ? nil : currentStage,
                    completed: completedFlightStages(progress, current: currentStage)
                )
                updateOperationProgress(
                    progress,
                    percentage: percentage,
                    fraction: displayedFraction,
                    elapsed: elapsed,
                    now: timeline.date
                )
                updateOperationControls(progress)

                if buildLogExpanded, let logURL = progress.logURL {
                    InlineBuildLogView(
                        logURL: logURL,
                        isLive: progress.status == .running,
                        privacyModeEnabled: privacyModeEnabled
                    )
                    .transition(motion.revealTransition)
                }
            }
            .padding(14)
            .controlSurface(tint: operationTint(progress))
            .onChange(of: progress.status) { _, status in
                if status == .failed {
                    withAnimation(motion.disclosure) {
                        buildLogExpanded = true
                    }
                }
            }
        }
    }

    private func updateOperationHeader(_ progress: NodeUpdateProgress, percentage: Int) -> some View {
        HStack(spacing: 12) {
            DashboardCircleIcon(
                systemImage: operationIcon(progress),
                tint: operationTint(progress),
                size: 38
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("Update flight plan")
                    .font(.headline)
                Text(progress.phase)
                    .font(.subheadline.weight(.semibold))
                Text(progress.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(progress.isEstimate ? "About \(percentage)%" : "\(percentage)%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(operationTint(progress))
                    .quilLiveValueTransition(value: percentage)
                Label(updateContinuityTitle(progress), systemImage: continuityIcon(progress))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(updateContinuityTint(progress))
            }
        }
    }

    private func updateOperationProgress(
        _ progress: NodeUpdateProgress,
        percentage: Int,
        fraction: Double,
        elapsed: TimeInterval,
        now: Date
    ) -> some View {
        HStack(spacing: 12) {
            Text("Step \(progress.currentStepNumber)/\(progress.orderedSteps.count)")
                .font(.caption.weight(.semibold).monospacedDigit())
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(operationTint(progress))
                .animation(motion.progress, value: fraction)
            Text("\(percentage)%")
                .font(.caption.weight(.semibold).monospacedDigit())
            Text("Elapsed \(durationLabel(elapsed))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if let range = progress.workflowRemainingRange(at: now) {
                Text("ETA \(durationLabel(range.lowerBound))–\(durationLabel(range.upperBound))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Update progress")
        .accessibilityValue(
            "Step \(progress.currentStepNumber) of \(progress.orderedSteps.count), \(percentage) percent")
    }

    private func updateOperationControls(_ progress: NodeUpdateProgress) -> some View {
        HStack(spacing: 12) {
            if progress.status == .running {
                Label(
                    "This operation continues when you change pages or close the window.",
                    systemImage: "menubar.rectangle"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else if progress.status == .ready, releaseChecker.stagedUpdate != nil {
                Label("Candidate is verified and resumable.", systemImage: "shippingbox.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.info)
            }
            Spacer()
            if progress.logURL != nil {
                Button {
                    withAnimation(motion.disclosure) {
                        buildLogExpanded.toggle()
                    }
                } label: {
                    Label(
                        buildLogExpanded
                            ? "Hide output" : (progress.status == .running ? "Live output" : "Build output"),
                        systemImage: buildLogExpanded ? "chevron.up" : "chevron.down"
                    )
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            if progress.status == .ready, releaseChecker.stagedUpdate != nil {
                Button("Install staged update") {
                    releaseChecker.requestResumeStagedUpdate()
                }
                .buttonStyle(.borderedProminent)
            } else if progress.status == .failed || progress.status == .succeeded {
                Button("Dismiss") {
                    releaseChecker.dismissOperationResult()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func completedFlightStages(
        _ progress: NodeUpdateProgress,
        current: UpdateFlightStage
    ) -> Set<UpdateFlightStage> {
        if progress.status == .succeeded { return Set(UpdateFlightStage.allCases) }
        guard let index = UpdateFlightStage.allCases.firstIndex(of: current) else { return [] }
        var completed = Set(UpdateFlightStage.allCases.prefix(index))
        if progress.step.section == .activation || progress.status == .failed {
            completed.insert(.rollback)
        }
        return completed
    }

    private func operationIcon(_ progress: NodeUpdateProgress) -> String {
        switch progress.status {
        case .failed: "xmark.circle.fill"
        case .ready: "shippingbox.fill"
        case .succeeded: "checkmark.circle.fill"
        case .running: progress.step.systemImage
        }
    }

    private func operationTint(_ progress: NodeUpdateProgress) -> Color {
        switch progress.status {
        case .failed: theme.colors.danger
        case .ready: theme.colors.info
        case .succeeded: theme.colors.success
        case .running: progress.step.section == .preparation ? theme.colors.info : theme.colors.warning
        }
    }

    private func continuityIcon(_ progress: NodeUpdateProgress) -> String {
        if progress.status == .succeeded { return "checkmark.circle.fill" }
        if progress.status == .failed { return "arrow.uturn.backward.circle.fill" }
        return progress.currentImpact.systemImage
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
