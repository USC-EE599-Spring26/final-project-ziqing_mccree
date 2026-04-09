//
//  OCKHealthKitPassthroughStore.swift
//  OCKSample
//
//  Created by Corey Baker on 1/5/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitEssentials
import CareKitStore
import HealthKit
import os.log

extension OCKHealthKitPassthroughStore {

    func populateDefaultHealthKitTasks(
		startDate: Date = Date()
	) async throws {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRateTarget = OCKOutcomeValue(78.0, units: bpmUnit.unitString)
        let restingTarget = OCKOutcomeValue(68.0, units: bpmUnit.unitString)

        let heartRateSchedule = OCKSchedule.dailyAtTime(
            hour: 9,
            minutes: 0,
            start: startDate,
            end: nil,
            text: nil,
            duration: .allDay,
            targetValues: [heartRateTarget]
        )

        var heartRate = OCKHealthKitTask(
            id: AppTaskID.heartRate,
            title: "Heart Rate Trend",
            carePlanUUID: nil,
            schedule: heartRateSchedule,
            healthKitLinkage: OCKHealthKitLinkage(
                quantityIdentifier: .heartRate,
                quantityType: .discrete,
                unit: bpmUnit
            )
        )
        heartRate.instructions = """
        Review your heart rate trend to understand daily cardiovascular strain
        related to hypertension.
        """
        heartRate.asset = "heart.fill"
        heartRate.card = .numericProgress
        heartRate.priority = 50
        heartRate.impactsAdherence = false

        let restingHeartRateSchedule = OCKSchedule.dailyAtTime(
            hour: 21,
            minutes: 0,
            start: startDate,
            end: nil,
            text: nil,
            duration: .allDay,
            targetValues: [restingTarget]
        )

        var restingHeartRate = OCKHealthKitTask(
            id: AppTaskID.restingHeartRate,
            title: "Resting Heart Rate Review",
            carePlanUUID: nil,
            schedule: restingHeartRateSchedule,
            healthKitLinkage: OCKHealthKitLinkage(
                quantityIdentifier: .restingHeartRate,
                quantityType: .discrete,
                unit: bpmUnit
            )
        )
        restingHeartRate.instructions = """
        Compare your resting heart rate with your usual range to spot trends
        that matter for blood pressure care.
        """
        restingHeartRate.asset = "waveform.path.ecg"
        restingHeartRate.card = .labeledValue
        restingHeartRate.priority = 60
        restingHeartRate.impactsAdherence = false

        try await replaceSeededHealthKitTasks(
            with: [heartRate, restingHeartRate],
            legacyIDs: [
                TaskID.steps,
                TaskID.ovulationTestResult,
                AppTaskID.legacyHeartRate,
                AppTaskID.legacyRestingHeartRate,
                AppTaskID.legacyActiveEnergy
            ]
        )
    }

    private func replaceSeededHealthKitTasks(
        with tasks: [OCKHealthKitTask],
        legacyIDs: [String]
    ) async throws {
        let idsToReplace = Array(Set(tasks.map(\.id) + legacyIDs))
        var query = OCKTaskQuery()
        query.ids = idsToReplace

        while true {
            let existingTasks = try await fetchTasks(query: query)
            guard !existingTasks.isEmpty else {
                break
            }
            _ = try await deleteTasks(existingTasks)
        }

        _ = try await addTasks(tasks)
    }
}
