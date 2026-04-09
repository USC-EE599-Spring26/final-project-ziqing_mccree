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

private struct CustomTaskRecord: Codable, Identifiable {
	let id: String
	let title: String
	let detail: String
	let isHealthKitTask: Bool
}

@MainActor
class CareKitTaskViewModel: ObservableObject {

	@Published var error: AppError?
	@Published var customTasks: [CustomTaskItem] = []

	private let customTaskRecordsKey = "CareKitTaskViewModel.CustomTaskRecords"

	init() {
		customTasks = loadCustomTaskItems()
	}

	func addTask(
		_ title: String,
		instructions: String,
		cardType: CareKitCard,
		asset: String? = nil,
		startDate: Date = Date(),
		linkURL: String? = nil,
		featuredMessage: String? = nil,
		survey: Survey? = nil
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
				task.uiKitSurvey = survey ?? .rangeOfMotion
			}

			if cardType == .uiKitSurvey {
				task.uiKitSurvey = survey ?? .rangeOfMotion
			}

			if cardType == .survey {
				task.surveySteps = HypertensionSurveyFactory.measurementSurveySteps(
					taskID: task.id
				)
			}

		do {
			_ = try await appDelegate.store.addTasksIfNotPresent([task])
			appendCustomTaskRecord(
				.init(
					id: task.id,
					title: task.title ?? task.id,
					detail: "Task • \(task.card.rawValue)",
					isHealthKitTask: false
				)
			)
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
		healthKitTask.impactsAdherence = false

		do {
			_ = try await appDelegate.healthKitStore.addTasksIfNotPresent([healthKitTask])
			appendCustomTaskRecord(
				.init(
					id: healthKitTask.id,
					title: healthKitTask.title ?? healthKitTask.id,
					detail: "HealthKitTask • \(healthKitTask.card.rawValue)",
					isHealthKitTask: true
				)
			)
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
		customTasks = loadCustomTaskItems()
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
			removeCustomTaskRecord(id: item.id)
			NotificationCenter.default.post(
				.init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
			)
			await reloadCustomTasks()
		} catch {
			self.error = AppError.errorString("Could not delete task: \(error.localizedDescription)")
		}
	}

	private func loadCustomTaskItems() -> [CustomTaskItem] {
		loadCustomTaskRecords().map {
			CustomTaskItem(
				id: $0.id,
				title: $0.title,
				detail: $0.detail,
				isHealthKitTask: $0.isHealthKitTask
			)
		}
	}

	private func appendCustomTaskRecord(_ record: CustomTaskRecord) {
		var records = loadCustomTaskRecords()
		records.removeAll { $0.id == record.id }
		records.append(record)
		saveCustomTaskRecords(records)
		customTasks = loadCustomTaskItems()
	}

	private func removeCustomTaskRecord(id: String) {
		let records = loadCustomTaskRecords().filter { $0.id != id }
		saveCustomTaskRecords(records)
		customTasks = loadCustomTaskItems()
	}

	private func loadCustomTaskRecords() -> [CustomTaskRecord] {
		guard let data = UserDefaults.standard.data(forKey: customTaskRecordsKey) else {
			return []
		}
		return (try? JSONDecoder().decode([CustomTaskRecord].self, from: data)) ?? []
	}

	private func saveCustomTaskRecords(_ records: [CustomTaskRecord]) {
		guard let data = try? JSONEncoder().encode(records) else {
			return
		}
		UserDefaults.standard.set(data, forKey: customTaskRecordsKey)
	}
}
