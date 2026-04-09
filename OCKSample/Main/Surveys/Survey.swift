//
//  Survey.swift
//  OCKSample
//

import Foundation
import CareKitEssentials
import ResearchKitSwiftUI

enum MeasurementSurveyKind: String {
	case systolicValue
	case diastolicValue
}

struct MeasurementSurveyResponse {
	var systolic: Double
	var diastolic: Double

	static let empty = MeasurementSurveyResponse(
		systolic: 120,
		diastolic: 80
	)
}

enum Survey: String, CaseIterable, Identifiable {
	var id: Self { self }
	case onboard = "Onboard"
	case rangeOfMotion = "Range of Motion"

	func type() -> any Surveyable {
		switch self {
		case .onboard:
			return Onboard()
		case .rangeOfMotion:
			return RangeOfMotion()
		}
	}
}

enum HypertensionSurveyFactory {
	static func measurementSurveySteps(taskID: String) -> [SurveyStep] {
		let questions = [
			SurveyQuestion(
				id: MeasurementSurveyKind.systolicValue.rawValue,
				type: .numericQuestion,
				required: true,
				title: "Enter today's systolic blood pressure",
				detail: "Save the top number from your home blood pressure reading in mmHg.",
				prompt: "Systolic (mmHg)"
			),
			SurveyQuestion(
				id: MeasurementSurveyKind.diastolicValue.rawValue,
				type: .numericQuestion,
				required: true,
				title: "Enter today's diastolic blood pressure",
				detail: "Save the bottom number from your home blood pressure reading in mmHg.",
				prompt: "Diastolic (mmHg)"
			)
		]

		return [SurveyStep(id: "\(taskID).step", questions: questions)]
	}
}
