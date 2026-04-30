//
//  TaskID.swift
//  OCKSample
//
//  Created by Corey Baker on 4/14/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

enum TaskID {
    static let doxylamine = "doxylamine"
    static let nausea = "nausea"
    static let stretch = "stretch"
    static let kegels = "kegels"
    static let steps = "steps"
    static let ovulationTestResult = "ovulationTestResult"
    static let onboarding = "onboarding"

    static var onboardingIDs: [String] {
        [onboarding]
    }

    static var ordered: [String] {
        orderedObjective + orderedSubjective
    }

    static var orderedObjective: [String] {
        [ Self.steps, Self.ovulationTestResult ]
    }

    static var orderedSubjective: [String] {
        [ Self.doxylamine, Self.kegels, Self.stretch, Self.nausea]
    }

    static var orderedWatchOS: [String] {
        [ Self.doxylamine, Self.kegels, Self.stretch ]
    }

    /// Hypertension task IDs for Insights tab (matches OCKStore.populateDefaultCarePlansTasksContacts).
    static var orderedHypertension: [String] {
        AppTaskID.orderedInsights
    }
}

enum AppTaskID {
    static var orderedStandardCare: [String] {
        [
            TaskID.onboarding,
            medicationChecklist,
            bpMeasurement,
            symptomsCheck,
            morningPrep,
            lowSodiumCheck,
            walkAssessment
        ]
    }

    static var orderedHealthKitCare: [String] {
        [
            heartRate,
            restingHeartRate
        ]
    }

    static var orderedCare: [String] {
        orderedStandardCare + orderedHealthKitCare
    }

    static var currentDefaultTaskIDs: [String] {
        orderedStandardCare
    }

    static var currentDefaultHealthKitTaskIDs: [String] {
        orderedHealthKitCare
    }

    static var orderedInsights: [String] {
        [bpMeasurement, heartRate, restingHeartRate]
    }

    static let doxylamine = "doxylamine"
    static let nausea = "nausea"
    static let kegels = "kegels"
    static let stretch = "stretch"
    static let steps = "steps" // some sample projects use this

    static let medicationChecklist = "bp_medication_checklist"
    static let bpMeasurement  = "bp_measure"
    static let symptomsCheck = "bp_symptoms_check"
    static let morningPrep = "bp_morning_prep"
    static let lowSodiumCheck = "low_sodium_check"
    static let reflection = "bp_reflection"
    static let walkAssessment = "bp_walk_assessment"
    static let heartRate = "bp_heart_rate"
    static let restingHeartRate = "bp_resting_heart_rate"

    static let onboarding = TaskID.onboarding
}
