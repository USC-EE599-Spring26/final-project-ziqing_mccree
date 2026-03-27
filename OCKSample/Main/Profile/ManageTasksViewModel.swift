//
//  ManageTasksViewModel.swift
//  OCKSample
//
//  MVVM view model for listing and deleting tasks (OCKTask and OCKHealthKitTask).
//

import Foundation
import CareKitStore
import os.log

@MainActor
final class ManageTasksViewModel: ObservableObject {

    @Published private(set) var tasks: [OCKAnyTask] = []
    @Published private(set) var isLoading = false
    @Published var error: AppError?
    @Published var taskToConfirmDelete: OCKAnyTask?

    private let store: OCKStore
    private let healthKitStore: OCKHealthKitPassthroughStore?

    init(store: OCKStore, healthKitStore: OCKHealthKitPassthroughStore? = nil) {
        self.store = store
        self.healthKitStore = healthKitStore
    }

    func loadTasks() async {
        isLoading = true
        error = nil
        do {
            var query = OCKTaskQuery(for: Date())
            query.excludesTasksWithNoEvents = false
            let calendar = Calendar.current
            let distantPast = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            let distantFuture = calendar.date(byAdding: .year, value: 10, to: Date()) ?? Date()
            query.dateInterval = DateInterval(start: distantPast, end: distantFuture)
            var fetched = try await store.fetchAnyTasks(query: query)
            if let healthStore = healthKitStore {
                let healthTasks = try await healthStore.fetchAnyTasks(query: query)
                fetched += healthTasks
            }
            tasks = fetched
        } catch let err {
            self.error = .error(err)
            Logger.careKitTask.error("ManageTasks load failed: \(err.localizedDescription)")
        }
        isLoading = false
    }

    func deleteTask(_ task: OCKAnyTask) async {
        do {
            if let ockTask = task as? OCKTask {
                try await store.deleteTasks([ockTask])
            } else if let healthTask = task as? OCKHealthKitTask, let healthStore = healthKitStore {
                try await healthStore.deleteTasks([healthTask])
            } else {
                error = .errorString("HealthKit tasks require HealthKit store to delete.")
                return
            }
            tasks.removeAll { $0.id == task.id }
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: Constants.shouldRefreshView),
                object: nil
            )
        } catch let err {
            self.error = .error(err)
            Logger.careKitTask.error("ManageTasks delete failed: \(err.localizedDescription)")
        }
    }

    func confirmDelete(_ task: OCKAnyTask) {
        taskToConfirmDelete = task
    }

    func clearDeleteConfirmation() {
        taskToConfirmDelete = nil
    }

    func clearError() {
        error = nil
    }
}
