import CareKitStore
import Foundation
#if canImport(ResearchKit) && canImport(ResearchKitActiveTask)
import ResearchKit
import ResearchKitActiveTask
#endif

struct RangeOfMotion: Surveyable {
	static var surveyType: Survey {
		Survey.rangeOfMotion
	}
}

#if canImport(ResearchKit) && canImport(ResearchKitActiveTask)
extension RangeOfMotion {
	func createSurvey() -> ORKTask {
		let walkAssessmentTask = ORKOrderedTask.shortWalk(
			withIdentifier: identifier(),
			intendedUseDescription: """
			This short daily walking check helps you reflect on whether
			today's activity tolerance supports your blood pressure and
			step goals.
			""",
			numberOfStepsPerLeg: 20,
			restDuration: 20,
			options: [.excludeConclusion]
		)

		let completionStep = ORKCompletionStep(
			identifier: "\(identifier()).completion"
		)
		completionStep.title = "Daily Walking Check Complete"
		completionStep.detailText = """
		Great job. Your walking check has been saved for today's blood
		pressure care plan.
		"""
		walkAssessmentTask.addSteps(from: [completionStep])

		return walkAssessmentTask
	}

	func extractAnswers(_ result: ORKTaskResult) -> [OCKOutcomeValue]? {
		[OCKOutcomeValue("Completed daily walking check")]
	}
}
#endif
