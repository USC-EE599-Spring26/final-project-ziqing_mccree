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

private extension OCKHealthKitTask {
    func needsSeedMetadataUpdate(from expected: OCKHealthKitTask) -> Bool {
        // 我这里和普通 task 保持一致，也把 schedule 修正进来，避免老用户已有任务今天没有 event。
        title != expected.title
            || instructions != expected.instructions
            || asset != expected.asset
            || schedule != expected.schedule
            || impactsAdherence != expected.impactsAdherence
            || card != expected.card
            || priority != expected.priority
    }

    func applyingSeedMetadata(from expected: OCKHealthKitTask) -> OCKHealthKitTask {
        var updated = self
        updated.title = expected.title
        updated.instructions = expected.instructions
        updated.asset = expected.asset
        updated.schedule = expected.schedule
        updated.impactsAdherence = expected.impactsAdherence
        updated.card = expected.card
        updated.priority = expected.priority
        return updated
    }
}

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

        try await addOrUpdateSeededHealthKitTasksIfNeeded([heartRate, restingHeartRate])
    }

    private func addOrUpdateSeededHealthKitTasksIfNeeded(_ tasks: [OCKHealthKitTask]) async throws {
        // 我这里和普通 task 一样，只补齐/更新当前版本 metadata，不主动清理 outcome。
        let taskIDs = tasks.map(\.id)
        var query = OCKTaskQuery()
        query.ids = taskIDs

        let existingTasks = try await fetchTasks(query: query)
        var tasksToAdd = [OCKHealthKitTask]()
        var tasksToUpdate = [OCKHealthKitTask]()

        tasks.forEach { task in
            guard let existingTask = existingTasks.first(where: { $0.id == task.id }) else {
                tasksToAdd.append(task)
                return
            }

            guard existingTask.needsSeedMetadataUpdate(from: task) else {
                return
            }
            tasksToUpdate.append(existingTask.applyingSeedMetadata(from: task))
        }

        if !tasksToAdd.isEmpty {
            _ = try await addTasks(tasksToAdd)
        }

        if !tasksToUpdate.isEmpty {
            _ = try await updateTasks(tasksToUpdate)
        }
    }
}
