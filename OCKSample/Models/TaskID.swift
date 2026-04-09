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
    static let onboarding = "bp_onboarding"
    static let legacyOnboarding = "onboarding"

    static var onboardingIDs: [String] {
        [onboarding, legacyOnboarding]
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
    static var orderedCare: [String] {
        [
            TaskID.onboarding,
            medicationChecklist,
            bpMeasurement,
            symptomsCheck,
            morningPrep,
            lowSodiumCheck,
            walkAssessment,
            heartRate,
            restingHeartRate
        ]
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

    // Legacy ids retained for compatibility with older code paths / stored data.
    static let bpMedicationAM = "bp_med_am"
    static let bpMedicationPM = "bp_med_pm"
    static let exercise = "exercise"
    static let rangeOfMotion = "range_of_motion"
    static let onboarding = TaskID.onboarding

    static let legacyHeartRate = "heart_rate_monitoring"
    static let legacyRestingHeartRate = "resting_heart_rate_monitoring"
    static let legacyActiveEnergy = "active_energy_monitoring"
    static let legacyEducation = "hypertension_education"
    static let legacyReflectionSurvey = "bp_reflection_survey"
    static let legacyQualityOfLife = "bp_quality_of_life"
    static let legacyWalkAssessment = "walk_assessment"
}
