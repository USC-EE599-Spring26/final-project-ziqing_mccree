//
//  Onboarding.swift
//  OCKSample
//
//  Hypertension onboarding: gate → instructions → consent/signature → HealthKit permissions → completion.
//

import Foundation
import ResearchKit
#if canImport(HealthKit)
import HealthKit
#endif

struct Onboarding {
    private init() {}

    static var task: ORKOrderedTask {
        let gateStep = ORKQuestionStep(
            identifier: "gateParticipation",
            title: "Blood Pressure Care Program",
            question:
                "Do you want to join this hypertension (high blood pressure) care program "
                + "and use this app for blood pressure self-management?",
            answer: ORKBooleanAnswerFormat(
                yesString: "Yes, join blood pressure program",
                noString: "Not now"
            )
        )

        let introStep = ORKInstructionStep(identifier: "presentInstructions")
        introStep.title = "Blood Pressure & Hypertension Setup"
        introStep.text = """
        These steps set up hypertension (high blood pressure) care in this app: home blood pressure monitoring, \
        blood pressure–related medication reminders, sodium-aware eating, and activity that supports blood pressure \
        goals.

        Next you will review and sign a blood pressure program consent, then choose Health data access for tracking \
        systolic/diastolic blood pressure and related vitals.
        """

        let consentDocument = ORKConsentDocument()
        consentDocument.title = "Blood Pressure / Hypertension Program Consent"

        let overview = ORKConsentSection(type: .overview)
        overview.summary = "Hypertension & blood pressure care"
        overview.content = """
        This blood pressure program helps you manage hypertension with medication adherence, home cuff readings, \
        low-sodium diet logging, and exercise suited to your blood pressure plan. Information you provide may be \
        used to personalize hypertension-related tasks shown in the app.
        """

        let privacy = ORKConsentSection(type: .privacy)
        privacy.summary = "Blood pressure data & privacy"
        privacy.content = """
        Blood pressure readings, related HealthKit vitals, and hypertension care notes you enter are used to support \
        high blood pressure tracking in this app. Use clinical guidance from your care team for treatment decisions.
        """

        consentDocument.sections = [overview, privacy]

        let signature = ORKConsentSignature(
            forPersonWithTitle: nil,
            dateFormatString: nil,
            identifier: "hypertensionConsentSignature"
        )
        consentDocument.addSignature(signature)

        let reviewStep = ORKConsentReviewStep(
            identifier: "requireSignature",
            signature: signature,
            in: consentDocument
        )
        reviewStep.title = "Review & Sign (Blood Pressure Program)"
        reviewStep.text = """
        Read the hypertension / blood pressure program summary above, then sign to confirm you understand how blood \
        pressure–related data may be used in this app.
        """
        reviewStep.reasonForConsent =
            "I agree to participate in this hypertension and home blood pressure monitoring program."

        var steps: [ORKStep] = [gateStep, introStep, reviewStep]

        if let permissionStep = Self.makeHealthKitPermissionStep() {
            steps.append(permissionStep)
        } else {
            steps.append(Self.fallbackPermissionInstructionStep())
        }

        let completionStep = ORKCompletionStep(identifier: "completion")
        completionStep.title = "Hypertension / Blood Pressure Onboarding Complete"
        completionStep.text = """
        You finished the blood pressure onboarding flow. Close this screen to return to Care—your hypertension tasks \
        (medications, blood pressure checks, diet, exercise) will appear for today.
        """
        steps.append(completionStep)

        return ORKOrderedTask(
            identifier: TaskID.onboarding,
            steps: steps
        )
    }

    private static func fallbackPermissionInstructionStep() -> ORKInstructionStep {
        let step = ORKInstructionStep(identifier: "requestPermissionsInfo")
        step.title = "Blood Pressure & Hypertension Health Access"
        step.text = """
        iOS may next ask to share blood pressure–related Health data (for example cuff readings, heart rate, activity) \
        so this hypertension app can show trends alongside your blood pressure goals.

        You can change blood pressure data access later in Settings › Privacy › Health.
        """
        return step
    }

    /// Real HealthKit authorization UI when ResearchKit provides `ORKRequestPermissionsStep`.
    private static func makeHealthKitPermissionStep() -> ORKStep? {
        #if canImport(HealthKit)
        var reads = Set<HKObjectType>()

        let quantityIds: [HKQuantityTypeIdentifier] = [
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .heartRate,
            .stepCount,
            .activeEnergyBurned
        ]
        for identifier in quantityIds {
            if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
                reads.insert(quantityType)
            }
        }

        guard !reads.isEmpty else { return nil }

        let permission = ORKHealthKitPermissionType(
            sampleTypesToWrite: [],
            objectTypesToRead: reads
        )
        let step = ORKRequestPermissionsStep(
            identifier: "requestPermissions",
            permissionTypes: [permission]
        )
        step.title = "Blood Pressure & Related Health Data"
        step.text = """
        Allow Health to share blood pressure, heart rate, and activity data needed for hypertension monitoring \
        and trends in this app.
        """
        return step
        #else
        return nil
        #endif
    }
}

/// Guided arm raises for hypertension prevention (ResearchKit instruction flow; no motion sensors).
struct RaiseArmExercise {
    private init() {}

    static var task: ORKOrderedTask {
        let instruction = ORKInstructionStep(identifier: "raiseArmInstruction")
        instruction.title = "Raise Arm 4 Times"
        instruction.text = """
        Slowly raise your arm and lower it back down. Repeat 4 times.

        This gentle movement supports relaxation and healthy blood pressure prevention.
        """
        let completion = ORKCompletionStep(identifier: "raiseArmCompletion")
        completion.title = "Raise Arm 4 Times"
        completion.text = "Tap Done to save this activity for today."
        return ORKOrderedTask(identifier: AppTaskID.rangeOfMotion, steps: [instruction, completion])
    }
}
