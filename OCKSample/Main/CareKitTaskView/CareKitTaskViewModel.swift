//
//  CareKitTaskViewModel.swift
//  OCKSample
//
//  Created by Corey Baker on 2/26/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitEssentials
import CareKitStore
import HealthKit
import os.log

enum TaskCreationKind: String, CaseIterable, Identifiable {
	case task = "Task"
	case healthKitTask = "HealthKitTask"
	var id: Self { self }
}

enum HealthKitQuantityChoice: String, CaseIterable, Identifiable {
	case heartRate = "Heart Rate"
	case restingHeartRate = "Resting Heart Rate"

	var id: Self { self }
}

struct CustomTaskItem: Identifiable {
	let id: String
	let title: String
	let detail: String
	let isHealthKitTask: Bool
}

@MainActor
class CareKitTaskViewModel: ObservableObject {

	@Published var error: AppError?
	@Published var customTasks: [CustomTaskItem] = []

	init() {
		Task {
			await reloadCustomTasks()
		}
	}

	func addTask(
		_ title: String,
		instructions: String,
		cardType: CareKitCard,
		asset: String? = nil,
		startDate: Date = Date(),
		linkURL: String? = nil,
		featuredMessage: String? = nil
	) async {
		guard let appDelegate = AppDelegateKey.defaultValue else {
			error = AppError.couldntBeUnwrapped
			return
		}

		let uniqueId = "custom_\(UUID().uuidString)"
		let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
		var task = OCKTask(
			id: uniqueId,
			title: sanitizedTitle.isEmpty ? "Custom Blood Pressure Task" : sanitizedTitle,
			carePlanUUID: nil,
			schedule: schedule(startDate: startDate)
		)
		task.instructions = sanitizedInstructions(
			instructions,
			fallback: defaultInstructions(for: cardType)
		)
		task.asset = sanitizedAsset(
			asset,
			fallback: defaultAsset(for: cardType)
		)
		task.card = cardType
		task.priority = 100
		task.impactsAdherence = [.button, .checklist, .simple].contains(cardType)

		if cardType == .link {
			task.linkURL = linkURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
				? linkURL
				: "https://www.heart.org/en/health-topics/high-blood-pressure"
		}

		if cardType == .featured {
			task.featuredMessage = sanitizedInstructions(
				featuredMessage,
				fallback: "Launch a guided daily walking check."
			)
#if os(iOS)
			task.uiKitSurvey = .rangeOfMotion
#endif
		}

		if cardType == .uiKitSurvey {
#if os(iOS)
			task.uiKitSurvey = .rangeOfMotion
#endif
		}

		if cardType == .survey {
#if os(iOS)
			task.surveySteps = HypertensionSurveyFactory.measurementSurveySteps(
				taskID: task.id
			)
#else
			task.card = .instruction
#endif
		}

		do {
			_ = try await appDelegate.store.addTasksIfNotPresent([task])
			Utility.synchronizeStoreIfRemoteEnabled()
			await reloadCustomTasks()
			Logger.careKitTask.info("Saved task: \(task.id, privacy: .private)")
			NotificationCenter.default.post(
				.init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
			)
		} catch {
			self.error = AppError.errorString("Could not add task: \(error.localizedDescription)")
		}
	}

	func addHealthKitTask(
		_ title: String,
		instructions: String,
		cardType: CareKitCard,
		asset: String? = nil,
		startDate: Date = Date(),
		quantityChoice: HealthKitQuantityChoice = .heartRate
	) async {
		guard let appDelegate = AppDelegateKey.defaultValue else {
			error = AppError.couldntBeUnwrapped
			return
		}

		let uniqueId = "custom_hk_\(UUID().uuidString)"
		let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
		let bpmUnit = HKUnit.count().unitDivided(by: .minute())
		let linkage: OCKHealthKitLinkage
		switch quantityChoice {
		case .heartRate:
			linkage = OCKHealthKitLinkage(
				quantityIdentifier: .heartRate,
				quantityType: .discrete,
				unit: bpmUnit
			)
		case .restingHeartRate:
			linkage = OCKHealthKitLinkage(
				quantityIdentifier: .restingHeartRate,
				quantityType: .discrete,
				unit: bpmUnit
			)
		}

		var healthKitTask = OCKHealthKitTask(
			id: uniqueId,
			title: sanitizedTitle.isEmpty ? "Custom HealthKit Task" : sanitizedTitle,
			carePlanUUID: nil,
			schedule: schedule(startDate: startDate),
			healthKitLinkage: linkage
		)
		healthKitTask.instructions = sanitizedInstructions(
			instructions,
			fallback: defaultHealthKitInstructions(for: quantityChoice)
		)
		healthKitTask.asset = sanitizedAsset(
			asset,
			fallback: defaultHealthKitAsset(for: quantityChoice)
		)
		healthKitTask.card = cardType
		healthKitTask.priority = 100
		healthKitTask.impactsAdherence = false

		do {
			_ = try await appDelegate.healthKitStore.addTasksIfNotPresent([healthKitTask])
			Utility.synchronizeStoreIfRemoteEnabled()
			await reloadCustomTasks()
			Logger.careKitTask.info("Saved HealthKitTask: \(healthKitTask.id, privacy: .private)")
			NotificationCenter.default.post(
				.init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
			)
			Utility.requestHealthKitPermissions()
		} catch {
			self.error = AppError.errorString("Could not add task: \(error.localizedDescription)")
		}
	}

	private func schedule(startDate: Date) -> OCKSchedule {
		let components = Calendar.current.dateComponents([.hour, .minute], from: startDate)
		return .dailyAtTime(
			hour: components.hour ?? 0,
			minutes: components.minute ?? 0,
			start: startDate,
			end: nil,
			text: nil
		)
	}

	private func sanitizedInstructions(_ value: String?, fallback: String) -> String {
		let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return trimmed.isEmpty ? fallback : trimmed
	}

	private func sanitizedAsset(_ value: String?, fallback: String) -> String {
		let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return trimmed.isEmpty ? fallback : trimmed
	}

	private func defaultInstructions(for cardType: CareKitCard) -> String {
		let instructionsByCard: [CareKitCard: String] = [
			.button: "Log today's blood pressure care check-in.",
			.checklist: "Mark each blood pressure care step when you finish it.",
			.featured: "Review this featured blood pressure care activity.",
			.grid: "Review today's blood pressure summary and save your response.",
			.instruction: "Read today's blood pressure care instructions.",
			.link: "Open a trusted blood pressure education resource.",
			.simple: "Complete this simple blood pressure care task.",
			.custom: "Start this custom blood pressure care task.",
			.survey: "Enter today's systolic and diastolic blood pressure values.",
			.uiKitSurvey: "Complete today's guided blood pressure care activity.",
			.numericProgress: "Review today's blood pressure care data.",
			.labeledValue: "Review today's blood pressure care data."
		]
		return instructionsByCard[cardType] ?? "Review today's blood pressure care task."
	}

	private func defaultAsset(for cardType: CareKitCard) -> String {
		switch cardType {
		case .button:
			return "checkmark.circle"
		case .checklist:
			return "checklist"
		case .featured:
			return "figure.walk.motion"
		case .grid:
			return "drop.circle"
		case .instruction:
			return "list.bullet.clipboard"
		case .link:
			return "link.circle"
		case .simple:
			return "heart.text.square"
		case .custom:
			return "heart"
		case .survey, .uiKitSurvey:
			return "doc.text.fill"
		case .numericProgress, .labeledValue:
			return "waveform.path.ecg"
		}
	}

	private func defaultHealthKitInstructions(for choice: HealthKitQuantityChoice) -> String {
		switch choice {
		case .heartRate:
			return "Review your heart rate trend as part of blood pressure care."
		case .restingHeartRate:
			return "Review your resting heart rate trend as part of blood pressure care."
		}
	}

	private func defaultHealthKitAsset(for choice: HealthKitQuantityChoice) -> String {
		switch choice {
		case .heartRate:
			return "heart.fill"
		case .restingHeartRate:
			return "waveform.path.ecg"
		}
	}

}

@MainActor
extension CareKitTaskViewModel {
	func reloadCustomTasks() async {
		guard let appDelegate = AppDelegateKey.defaultValue else {
			customTasks = []
			return
		}

		do {
			var taskQuery = OCKTaskQuery()
			taskQuery.excludesTasksWithNoEvents = false

			let standardTasks = try await appDelegate.store.fetchTasks(query: taskQuery)
			let healthKitTasks = try await appDelegate.healthKitStore.fetchTasks(query: taskQuery)

			let standardItems = standardTasks
				.filter { $0.id.hasPrefix("custom_") }
				.filter { !$0.id.hasPrefix("custom_hk_") }
				.map {
					CustomTaskItem(
						id: $0.id,
						title: $0.title ?? $0.id,
						detail: "Task • \($0.card.rawValue)",
						isHealthKitTask: false
					)
				}

			let healthKitItems = healthKitTasks
				.filter { $0.id.hasPrefix("custom_hk_") }
				.map {
					CustomTaskItem(
						id: $0.id,
						title: $0.title ?? $0.id,
						detail: "HealthKitTask • \($0.card.rawValue)",
						isHealthKitTask: true
					)
				}

			customTasks = (standardItems + healthKitItems)
				.sorted { $0.title < $1.title }
		} catch {
			self.error = AppError.errorString("Could not load tasks: \(error.localizedDescription)")
			customTasks = []
		}
	}

	func deleteTask(_ item: CustomTaskItem) async {
		guard let appDelegate = AppDelegateKey.defaultValue else {
			error = AppError.couldntBeUnwrapped
			return
		}

		do {
			var query = OCKTaskQuery()
			query.ids = [item.id]
			if item.isHealthKitTask {
				let matchingTasks = try await appDelegate.healthKitStore.fetchTasks(query: query)
				if let taskToDelete = matchingTasks.max(by: { $0.effectiveDate < $1.effectiveDate }) {
					_ = try await appDelegate.healthKitStore.deleteTasks([taskToDelete])
				}
			} else {
				let matchingTasks = try await appDelegate.store.fetchTasks(query: query)
				if let taskToDelete = matchingTasks.max(by: { $0.effectiveDate < $1.effectiveDate }) {
					_ = try await appDelegate.store.deleteTasks([taskToDelete])
				}
			}
			Utility.synchronizeStoreIfRemoteEnabled()
			NotificationCenter.default.post(
				.init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
			)
			await reloadCustomTasks()
		} catch {
			self.error = AppError.errorString("Could not delete task: \(error.localizedDescription)")
		}
	}

}
