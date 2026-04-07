//
//  RangeOfMotionDemoFlowViewController.swift
//  OCKSample
//
//  Mock CoreMotion-style ROM: instruction → simulated tracking → results → ResearchKit survey.
//  Swap `runMockTracking` / `MockROMResult.sensorReadyDemo` for `CMMotionManager` when adding real sensors.
//

import SwiftUI
import UIKit
@preconcurrency import ResearchKit
@preconcurrency import ResearchKitUI

// MARK: - SwiftUI state

final class ROMDemoFlowModel: ObservableObject {
    enum Phase: Equatable {
        case instruction
        case tracking
        case results
    }

    @Published var phase: Phase = .instruction
    @Published var trackingProgress: CGFloat = 0
    @Published var trackingMessageIndex = 0
    @Published var displayedElevationDegrees: Int = 0
    @Published var displayedMovementCompleted = false
    @Published var displayedRepetitionCount = 0
}

private struct ROMDemoRootView: View {
    @ObservedObject var model: ROMDemoFlowModel
    let onStartTracking: () -> Void
    let onContinueAfterResults: () -> Void

    private let trackingMessages = [
        "Tracking motion...",
        "Measuring lower-body movement...",
        "Simulating knee bend motion input..."
    ]

    var body: some View {
        Group {
            switch model.phase {
            case .instruction:
                instructionContent
            case .tracking:
                trackingContent
            case .results:
                resultsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var instructionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Prepare", systemImage: "figure.stand")
                .font(.title2.bold())
            Text("Follow these steps before tracking begins:")
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                bullet("Stand near a stable surface or wall for balance.")
                bullet("Slowly bend your knees into a shallow squat.")
                bullet("Lower only to a comfortable range.")
                bullet("Return to standing.")
                bullet("Repeat 3 times.")
            }
            Spacer()
            Button(action: onStartTracking) {
                Text("Start motion tracking")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 6)
            Text(text)
        }
    }

    private var trackingContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.walk")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text("Lower-body motion capture (demo)")
                .font(.headline)
            Text(trackingMessages[model.trackingMessageIndex % trackingMessages.count])
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            ProgressView(value: Double(model.trackingProgress))
                .progressViewStyle(.linear)
                .tint(.accentColor)
            Text("\(Int(model.trackingProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Motion estimate", systemImage: "waveform.path.ecg")
                .font(.title2.bold())
            Text("Sensor-ready readout (mock values for Simulator)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                metricRow(
                    title: "Knee bend depth estimate",
                    value: "\(model.displayedElevationDegrees)°",
                    icon: "arrow.down.circle"
                )
                metricRow(
                    title: "Movement completed",
                    value: model.displayedMovementCompleted ? "Yes" : "No",
                    icon: "checkmark.circle"
                )
                metricRow(
                    title: "Repetition count",
                    value: "\(model.displayedRepetitionCount)",
                    icon: "repeat"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            Spacer()
            Button(action: onContinueAfterResults) {
                Text("Continue to questionnaire")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

// MARK: - UIKit container + mock pipeline

@MainActor
final class RangeOfMotionDemoFlowViewController: UIViewController {

    var onFinished: ((Bool) -> Void)?

    private let mockResult = RaiseArmExercise.MockROMResult.sensorReadyDemo
    private var hosting: UIHostingController<ROMDemoRootView>?
    /// Bumps to cancel in-flight mock tracking ticks (replaces `Timer.invalidate()`).
    private var trackingTickGeneration: UInt64 = 0
    /// Owned here so SwiftUI bindings stay stable for the lifetime of this screen.
    private var flowModel: ROMDemoFlowModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lower-Body Range of Motion"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        let model = ROMDemoFlowModel()
        flowModel = model
        let root = ROMDemoRootView(
            model: model,
            onStartTracking: { [weak self] in
                self?.runMockTracking()
            },
            onContinueAfterResults: { [weak self] in
                self?.presentPostMotionSurvey()
            }
        )
        let host = UIHostingController(rootView: root)
        embed(host)
        hosting = host
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            trackingTickGeneration &+= 1
        }
    }

    private func embed(_ host: UIHostingController<ROMDemoRootView>) {
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    /// Main-queue async ticks stand in for `CMMotionManager` callbacks; replace with motion queue updates later.
    private func runMockTracking() {
        guard let model = flowModel else { return }
        trackingTickGeneration &+= 1
        let generation = trackingTickGeneration

        model.phase = .tracking
        model.trackingProgress = 0
        model.trackingMessageIndex = 0

        let duration: TimeInterval = 2.5
        let start = Date()
        let interval: TimeInterval = 0.05
        scheduleMockTrackingTick(start: start, duration: duration, interval: interval, generation: generation)
    }

    private func scheduleMockTrackingTick(
        start: Date,
        duration: TimeInterval,
        interval: TimeInterval,
        generation: UInt64
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self else { return }
            guard generation == self.trackingTickGeneration else { return }
            guard let model = self.flowModel else { return }
            let elapsed = Date().timeIntervalSince(start)
            model.trackingProgress = CGFloat(min(1, elapsed / duration))
            model.trackingMessageIndex = Int(elapsed / 0.85) % 3
            if elapsed >= duration {
                let mockRomResult = self.mockResult
                model.displayedElevationDegrees = mockRomResult.armElevationEstimateDegrees
                model.displayedMovementCompleted = mockRomResult.movementCompleted
                model.displayedRepetitionCount = mockRomResult.repetitionCount
                model.phase = .results
                return
            }
            self.scheduleMockTrackingTick(start: start, duration: duration, interval: interval, generation: generation)
        }
    }

    private func presentPostMotionSurvey() {
        let taskVC = ORKTaskViewController(task: RaiseArmExercise.postMotionSurveyTask, taskRun: UUID())
        taskVC.delegate = self
        present(taskVC, animated: true)
    }

    @objc private func cancelTapped() {
        trackingTickGeneration &+= 1
        dismiss(animated: true) {
            self.onFinished?(false)
        }
    }
}

extension RangeOfMotionDemoFlowViewController: ORKTaskViewControllerDelegate {

    nonisolated func taskViewController(
        _ taskViewController: ORKTaskViewController,
        didFinishWith reason: ORKTaskFinishReason,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let completed = (reason == .completed)
            taskViewController.dismiss(animated: true) {
                self.dismiss(animated: true) {
                    self.onFinished?(completed)
                }
            }
        }
    }
}
