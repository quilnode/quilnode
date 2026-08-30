import SwiftUI

extension DashboardView {
    @ViewBuilder
    func updateProgressCard(_ progress: NodeUpdateProgress) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsedReference = progress.status == .running ? timeline.date : progress.updatedAt
            let elapsed = max(elapsedReference.timeIntervalSince(progress.startedAt), 0)
            let currentStage = UpdateFlightStage.current(for: progress.step)

            VStack(alignment: .leading, spacing: 12) {
                updateOperationHeader(progress)
                updateFlightSectionLabels
                updateFlightStageGrid(
                    current: progress.status == .succeeded ? nil : currentStage,
                    completed: completedFlightStages(progress, current: currentStage)
                )
                updateDetailedStepRail(progress)
                updateOperationProgress(
                    progress,
                    elapsed: elapsed
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
            .onAppear {
                if progress.shouldAutomaticallyRevealLog {
                    buildLogExpanded = true
                }
            }
            .onChange(of: progress.status) { _, status in
                if status == .failed, progress.logURL != nil {
                    withAnimation(motion.disclosure) {
                        buildLogExpanded = true
                    }
                }
            }
            .onChange(of: progress.logURL) { _, logURL in
                if logURL != nil, progress.status == .running {
                    withAnimation(motion.disclosure) {
                        buildLogExpanded = true
                    }
                }
            }
        }
    }

    private func updateOperationHeader(_ progress: NodeUpdateProgress) -> some View {
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
                Text(updateOperationStatusTitle(progress))
                    .font(.subheadline.bold())
                    .foregroundStyle(operationTint(progress))
                    .quilLiveValueTransition(value: progress.currentStepNumber)
                Label(updateContinuityTitle(progress), systemImage: continuityIcon(progress))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(updateContinuityTint(progress))
            }
        }
    }

    private func updateOperationProgress(
        _ progress: NodeUpdateProgress,
        elapsed: TimeInterval
    ) -> some View {
        HStack(spacing: 12) {
            Text("Step \(progress.currentStepNumber) of \(progress.orderedSteps.count)")
                .font(.caption.weight(.semibold).monospacedDigit())
            if progress.status == .running {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(operationTint(progress))
            } else {
                ProgressView(
                    value: Double(progress.completedStepCount),
                    total: Double(progress.orderedSteps.count)
                )
                .progressViewStyle(.linear)
                .tint(operationTint(progress))
            }
            Text("Elapsed \(durationLabel(elapsed))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Update progress")
        .accessibilityValue(
            "Step \(progress.currentStepNumber) of \(progress.orderedSteps.count), \(updateOperationStatusTitle(progress))"
        )
    }

    private func updateOperationControls(_ progress: NodeUpdateProgress) -> some View {
        HStack(spacing: 12) {
            if progress.status == .running {
                Label(
                    "Pages and windows are safe to close; quitting opens a safety confirmation.",
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
        return Set(UpdateFlightStage.allCases.prefix(index))
    }

    private func operationIcon(_ progress: NodeUpdateProgress) -> String {
        switch progress.status {
        case .failed: "xmark.circle.fill"
        case .ready: "shippingbox.fill"
        case .succeeded: "checkmark.circle.fill"
        case .running: progress.step.systemImage
        }
    }

    func operationTint(_ progress: NodeUpdateProgress) -> Color {
        switch progress.status {
        case .failed: theme.colors.danger
        case .ready: theme.colors.info
        case .succeeded: theme.colors.success
        case .running: progress.step.section == .preparation ? theme.colors.info : theme.colors.warning
        }
    }

    private func continuityIcon(_ progress: NodeUpdateProgress) -> String {
        if progress.status == .succeeded { return "checkmark.circle.fill" }
        if progress.status == .failed {
            return progress.step.section == .preparation
                ? "bolt.horizontal.circle.fill" : "exclamationmark.triangle.fill"
        }
        if progress.status == .ready { return "shippingbox.fill" }
        return progress.currentImpact.systemImage
    }

    func updateContinuityTitle(_ progress: NodeUpdateProgress) -> String {
        if progress.status == .succeeded { return "Node online and verified" }
        if progress.status == .ready { return "Verified candidate retained" }
        if progress.status == .failed {
            return progress.step.section == .preparation
                ? "Running node was not changed" : "Runtime outcome needs review"
        }
        return progress.currentImpact.title
    }

    private func updateOperationStatusTitle(_ progress: NodeUpdateProgress) -> String {
        switch progress.status {
        case .running: "In progress"
        case .ready: "Ready to install"
        case .succeeded: "Complete"
        case .failed: "Stopped"
        }
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
