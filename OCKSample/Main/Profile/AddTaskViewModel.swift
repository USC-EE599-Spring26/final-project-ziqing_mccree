//
//  AddTaskViewModel.swift
//  OCKSample
//
//  Created for EE599 midterm – hypertension tasks.
//

import Foundation
import CareKitStore
import os.log

enum AddTaskKind: String, CaseIterable, Identifiable {
    case regular = "Regular Task"
    case healthKit = "HealthKit Task"
    var id: String { rawValue }
}

/// HealthKit quantity type for hypertension app. Steps supported; BP can be added when identifier available.
enum HealthKitQuantityChoice: String, CaseIterable, Identifiable {
    case stepCount = "Steps"
    var id: String { rawValue }
}

@MainActor
final class AddTaskViewModel: ObservableObject {

    // MARK: Inputs bound from the view

    @Published var title: String = ""
    @Published var instructions: String = ""
    @Published var asset: String = ""
    @Published var startDate: Date = Date()
    @Published var selectedCardType: TaskCardType = .instructions
    @Published var taskKind: AddTaskKind = .regular
    @Published var healthKitQuantity: HealthKitQuantityChoice = .stepCount

    // MARK: Output / state

    @Published var isSaving: Bool = false
    @Published var error: AppError?

    // MARK: Dependencies

    private let store: OCKStore
    private let healthKitStore: OCKHealthKitPassthroughStore?

    init(store: OCKStore, healthKitStore: OCKHealthKitPassthroughStore? = nil) {
        self.store = store
        self.healthKitStore = healthKitStore
    }

    // MARK: Intents

    func saveTask() async -> Bool {
        guard validateInputs() else {
            return false
        }

        isSaving = true

        do {
            if taskKind == .healthKit, let healthStore = healthKitStore {
                let healthTask = try buildHealthKitTask()
                _ = try await healthStore.addTasks([healthTask])
                Logger.careKitTask.info("Saved HealthKit task: \(healthTask.id, privacy: .private)")
                Utility.requestHealthKitPermissions()
            } else {
                let task = try buildTask()
                _ = try await store.addTasks([task])
                Logger.careKitTask.info("Saved task: \(task.id, privacy: .private)")
            }
            NotificationCenter.default.post(
                .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
            )
            isSaving = false
            return true
        } catch {
            isSaving = false
            self.error = .error(error)
            return false
        }
    }

    // MARK: Helpers

    private func validateInputs() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            error = .errorString("Title cannot be empty.")
            return false
        }
        if taskKind == .healthKit && healthKitStore == nil {
            error = .errorString("HealthKit store is not available.")
            return false
        }
        return true
    }

    private func buildTask() throws -> OCKTask {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAsset = asset.trimmingCharacters(in: .whitespacesAndNewlines)

        let components = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let schedule = OCKSchedule.dailyAtTime(
            hour: hour,
            minutes: minute,
            start: startDate,
            end: nil,
            text: nil
        )

        let uniqueId = "custom_\(UUID().uuidString)"
        var task = OCKTask(
            id: uniqueId,
            title: trimmedTitle,
            carePlanUUID: nil,
            schedule: schedule
        )

        if !trimmedInstructions.isEmpty {
            task.instructions = trimmedInstructions
        }

        if !trimmedAsset.isEmpty {
            task.asset = trimmedAsset
        }

        task.card = selectedCardType.careKitCard

        return task
    }

    private func buildHealthKitTask() throws -> OCKHealthKitTask {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAsset = asset.trimmingCharacters(in: .whitespacesAndNewlines)

        let components = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let schedule = OCKSchedule.dailyAtTime(
            hour: hour,
            minutes: minute,
            start: startDate,
            end: nil,
            text: nil
        )

        let uniqueId = "custom_hk_\(UUID().uuidString)"
        let linkage = OCKHealthKitLinkage(
            quantityIdentifier: .stepCount,
            quantityType: .cumulative,
            unit: .count()
        )

        var healthTask = OCKHealthKitTask(
            id: uniqueId,
            title: trimmedTitle,
            carePlanUUID: nil,
            schedule: schedule,
            healthKitLinkage: linkage
        )

        if !trimmedInstructions.isEmpty {
            healthTask.instructions = trimmedInstructions
        }

        if !trimmedAsset.isEmpty {
            healthTask.asset = trimmedAsset
        }

        healthTask.card = selectedCardType.careKitCard

        return healthTask
    }
}
