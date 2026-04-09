//
//  SurveyViewSynchronizer.swift
//  OCKSample
//

#if canImport(ResearchKit)

import CareKit
import CareKitStore
import CareKitUI
import Foundation
import ResearchKit
import UIKit

@MainActor
final class SurveyViewSynchronizer: OCKSurveyTaskViewSynchronizer {
    override func updateView(
        _ view: OCKInstructionsTaskView,
        context: OCKSynchronizationContext<OCKTaskEvents>
    ) {
        super.updateView(view, context: context)

        guard let event = context.viewModel.first?.first else {
            view.instructionsLabel.isHidden = true
            return
        }

        if event.outcome != nil {
            view.instructionsLabel.isHidden = false

            if TaskID.onboardingIDs.contains(event.task.id) {
                view.instructionsLabel.text = "Completed blood pressure onboarding."
            } else if !event.outcomeStrings.isEmpty {
                view.instructionsLabel.text = event.outcomeStrings.joined(separator: "\n")
            } else {
                view.instructionsLabel.text = "Completed today."
            }
        } else {
            view.instructionsLabel.isHidden = true
        }
    }
}

#endif
