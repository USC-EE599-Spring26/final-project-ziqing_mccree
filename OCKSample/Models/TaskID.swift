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
    static let qualityOfLife = "qualityOfLife"
    static let ovulationTestResult = "ovulationTestResult"

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
        AppTaskID.ordered
    }
}

enum AppTaskID {
    static var ordered: [String] {
        [bpMedicationAM, bpMedicationPM, bpMeasurement, lowSodiumCheck, exercise]
    }
    static let doxylamine = "doxylamine"
    static let nausea = "nausea"
    static let kegels = "kegels"
    static let stretch = "stretch"
    static let steps = "steps" // some sample projects use this

    static let bpMedicationAM = "bp_med_am"
    static let bpMedicationPM = "bp_med_pm"
    static let bpMeasurement  = "bp_measure"
    static let lowSodiumCheck = "low_sodium_check"
    static let exercise = "exercise"

}
