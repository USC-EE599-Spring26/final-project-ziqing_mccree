import Foundation
import CareKitStore
import HealthKit
import UIKit
#if canImport(ResearchKit)
import ResearchKit
#endif

struct Onboard: Surveyable {
	static var surveyType: Survey {
		Survey.onboard
	}
}

#if canImport(ResearchKit)
extension Onboard {
	func createSurvey() -> ORKTask {
		let welcomeInstructionStep = ORKInstructionStep(
			identifier: "\(identifier()).welcome"
		)
		welcomeInstructionStep.title = "Welcome to Blood Pressure Care"
		welcomeInstructionStep.detailText = """
		This hypertension program helps you keep up with medication, review
		home blood pressure checks, learn low-sodium habits, and follow
		cardiovascular activity prompts.
		"""
		welcomeInstructionStep.image = UIImage(systemName: "heart.text.square.fill")
		welcomeInstructionStep.imageContentMode = .scaleAspectFit

		let studyOverviewInstructionStep = ORKInstructionStep(
			identifier: "\(identifier()).overview"
		)
		studyOverviewInstructionStep.title = "Before You Join"
		studyOverviewInstructionStep.iconImage = UIImage(systemName: "checkmark.seal.fill")

		let readingsBodyItem = ORKBodyItem(
			text: """
			You will review medication, home blood pressure care tasks,
			and supportive education tailored to hypertension.
			""",
			detailText: nil,
			image: UIImage(systemName: "heart.circle.fill"),
			learnMoreItem: nil,
			bodyItemStyle: .image
		)

		let healthDataBodyItem = ORKBodyItem(
			text: """
			The app may request heart rate, resting heart rate,
			and related Health data used to support blood pressure trends.
			""",
			detailText: nil,
			image: UIImage(systemName: "waveform.path.ecg"),
			learnMoreItem: nil,
			bodyItemStyle: .image
		)

		let signatureBodyItem = ORKBodyItem(
			text: "Before joining, you will review and sign a hypertension consent form.",
			detailText: nil,
			image: UIImage(systemName: "signature"),
			learnMoreItem: nil,
			bodyItemStyle: .image
		)

		let secureDataBodyItem = ORKBodyItem(
			text: "Your blood pressure care information stays private and secure.",
			detailText: nil,
			image: UIImage(systemName: "lock.fill"),
			learnMoreItem: nil,
			bodyItemStyle: .image
		)

		studyOverviewInstructionStep.bodyItems = [
			readingsBodyItem,
			healthDataBodyItem,
			signatureBodyItem,
			secureDataBodyItem
		]

		let webViewStep = ORKWebViewStep(
			identifier: "\(identifier()).signatureCapture",
			html: informedConsentHTML
		)
		webViewStep.showSignatureAfterContent = true

		let healthKitPermissionType = ORKHealthKitPermissionType(
			sampleTypesToWrite: [],
			objectTypesToRead: healthKitReadTypes
		)

		let notificationsPermissionType = ORKNotificationPermissionType(
			authorizationOptions: [.alert, .badge, .sound]
		)

		let motionPermissionType = ORKMotionActivityPermissionType()

		let requestPermissionsStep = ORKRequestPermissionsStep(
			identifier: "\(identifier()).requestPermissionsStep",
			permissionTypes: [
				healthKitPermissionType,
				notificationsPermissionType,
				motionPermissionType
			]
		)
		requestPermissionsStep.title = "Health Data Request"
		requestPermissionsStep.text = """
		Please review the Health and notification access below so the
		app can support your blood pressure care plan.
		"""

		let completionStep = ORKCompletionStep(
			identifier: "\(identifier()).completionStep"
		)
		completionStep.title = "Enrollment Complete"
		completionStep.text = """
		Your hypertension onboarding is complete. Today's blood pressure tasks
		will now appear on the Care tab.
		"""

		return ORKOrderedTask(
			identifier: identifier(),
			steps: [
				welcomeInstructionStep,
				studyOverviewInstructionStep,
				webViewStep,
				requestPermissionsStep,
				completionStep
			]
		)
	}

	func extractAnswers(_ result: ORKTaskResult) -> [OCKOutcomeValue]? {
		UserDefaults.standard.set(true, forKey: Constants.onboardingCompletedKey)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
			Utility.requestHealthKitPermissions()
		}
		DispatchQueue.main.async {
			NotificationCenter.default.post(
				.init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
			)
		}
		return [OCKOutcomeValue(Date())]
	}

	private var healthKitReadTypes: Set<HKObjectType> {
		var reads = Set<HKObjectType>()
		let quantityTypes: [HKQuantityTypeIdentifier] = [
			.heartRate,
			.restingHeartRate,
			.bloodPressureSystolic,
			.bloodPressureDiastolic
		]
		for identifier in quantityTypes {
			if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
				reads.insert(quantityType)
			}
		}
		return reads
	}
}
#endif
