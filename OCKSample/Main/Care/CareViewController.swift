/*
 Copyright (c) 2019, Apple Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.

 3. Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import os.log
#if canImport(ResearchKit) && canImport(ResearchKitUI)
import ResearchKit
import ResearchKitUI
#endif
import ResearchKitSwiftUI
import SwiftUI
import UIKit

@MainActor
final class CareViewController: OCKDailyPageViewController, @unchecked Sendable {

	private var isSyncing = false
	private var isLoading = false
	private var hasValidatedHypertensionSeed = false
	private var pendingReload = false
	private var taskLoadGeneration = 0
	private let swiftUIPadding: CGFloat = 15
    private var style: Styler {
        CustomStylerKey.defaultValue
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(synchronizeWithRemote)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(synchronizeWithRemote),
            name: Notification.Name(
                rawValue: Constants.requestSync
            ),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSynchronizationProgress(_:)),
            name: Notification.Name(rawValue: Constants.progressUpdate),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadView(_:)),
            name: Notification.Name(rawValue: Constants.finishedAskingForPermission),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadView(_:)),
            name: Notification.Name(rawValue: Constants.shouldRefreshView),
            object: nil
        )
    }

    @objc private func updateSynchronizationProgress(
        _ notification: Notification
    ) {
        guard let receivedInfo = notification.userInfo as? [String: Any],
              let progress = receivedInfo[Constants.progressUpdate] as? Int else {
            return
        }

		switch progress {
		case 100:
			self.navigationItem.rightBarButtonItem = UIBarButtonItem(
				title: "\(progress)",
				style: .plain, target: self,
				action: #selector(self.synchronizeWithRemote)
			)
			self.navigationItem.rightBarButtonItem?.tintColor = self.view.tintColor

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				guard let self else { return }
				self.navigationItem.rightBarButtonItem = UIBarButtonItem(
					barButtonSystemItem: .refresh,
					target: self,
					action: #selector(self.synchronizeWithRemote)
				)
				self.navigationItem.rightBarButtonItem?.tintColor = self.navigationItem.leftBarButtonItem?.tintColor
			}
		default:
			self.navigationItem.rightBarButtonItem = UIBarButtonItem(
				title: "\(progress)",
				style: .plain, target: self,
				action: #selector(self.synchronizeWithRemote)
			)
			self.navigationItem.rightBarButtonItem?.tintColor = self.view.tintColor
		}
    }

    @objc private func synchronizeWithRemote() {
        guard !isSyncing else {
            return
        }
        isSyncing = true
        AppDelegateKey.defaultValue?.store.synchronize { error in
            let errorString = error?.localizedDescription ?? "Successful sync with remote!"
            Logger.feed.info("\(errorString)")
            DispatchQueue.main.async { [weak self] in
				guard let self else { return }
                if error != nil {
                    self.navigationItem.rightBarButtonItem?.tintColor = .red
                } else {
                    self.navigationItem.rightBarButtonItem?.tintColor = self.navigationItem.leftBarButtonItem?.tintColor
                }
                self.isSyncing = false
            }
        }
    }

    @objc private func reloadView(_ notification: Notification? = nil) {
        guard !isLoading else {
            pendingReload = true
            return
        }
        self.reload()
    }

    override func dailyPageViewController(
        _ dailyPageViewController: OCKDailyPageViewController,
        prepare listViewController: OCKListViewController,
        for date: Date
    ) {
        self.isLoading = true
		taskLoadGeneration += 1
		let generation = taskLoadGeneration

		Task {
			let date = modifyDateIfNeeded(date)
			await fetchAndDisplayTasks(on: listViewController, for: date, generation: generation)
		}
    }

    private func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(
            date,
            inSameDayAs: Date()
        )
    }

    private func modifyDateIfNeeded(_ date: Date) -> Date {
        guard date < .now else {
            return date
        }
        guard !isSameDay(as: date) else {
            return .now
        }
        return date.endOfDay
    }

	private func fetchAndDisplayTasks(
		on listViewController: OCKListViewController,
		for date: Date,
		generation: Int
	) async {
		if !hasValidatedHypertensionSeed {
			hasValidatedHypertensionSeed = true
			await Utility.migrateHypertensionTasksIfNeeded()
		}
		let tasks = await self.fetchTasks(on: date)
		guard generation == taskLoadGeneration else {
			return
		}
		appendTasks(tasks, to: listViewController, date: date)
	}
}

private extension CareViewController {
	func fetchTasks(on date: Date) async -> [any OCKAnyTask] {
		var query = OCKTaskQuery(for: date)
		query.excludesTasksWithNoEvents = true
		do {
			let tasks = try await store.fetchAnyTasks(query: query)
			let filteredTasks = normalizeVisibleTasks(
				filterOutDemoTasks(tasks)
			)
			let careTasks = filteredTasks.compactMap { $0 as? CareTask }
			let orderedTasks = careTasks.sortedByPriority().compactMap { orderedTask in
				filteredTasks.first(where: { $0.id == orderedTask.id })
			}
			let unorderedTasks = filteredTasks.filter { task in
				orderedTasks.first(where: { $0.id == task.id }) == nil
			}
			return await applyOnboardingGate(orderedTasks + unorderedTasks)
		} catch {
			Logger.feed.error("Could not fetch tasks: \(error, privacy: .public)")
			return []
		}
	}

	func appendTasks(
		_ tasks: [any OCKAnyTask],
		to listViewController: OCKListViewController,
		date: Date
	) {
		listViewController.clear()
		let isCurrentDay = isSameDay(as: date)
		tasks.compactMap {
			let cards = self.taskViewControllers(
				$0,
				on: date
			)
			cards?.forEach {
				if let carekitView = $0.view as? OCKView {
					carekitView.customStyle = style
				}
				$0.view.isUserInteractionEnabled = isCurrentDay
				$0.view.alpha = !isCurrentDay ? 0.4 : 1.0
			}
			return cards
		}.forEach { (cards: [UIViewController]) in
			cards.forEach {
				listViewController.appendViewController($0, animated: false)
			}
		}
		self.isLoading = false
		if pendingReload {
			pendingReload = false
			reload()
		}
	}

	func filterOutDemoTasks(
		_ tasks: [any OCKAnyTask]
	) -> [any OCKAnyTask] {
		tasks.filter { task in
			let id = task.id.lowercased()
			let title = (
				(task as? OCKTask)?.title
				?? (task as? OCKHealthKitTask)?.title
				?? task.id
			).lowercased()
			if title.contains("benefits of exercising") || title.contains("benefits of exercise") {
				return false
			}
			let keywords = ["pregnancy", "ovulation", "doxylamine", "nausea", "kegels", "stretch"]
			return !keywords.contains(where: { id.contains($0) || title.contains($0) })
		}
	}

	func applyOnboardingGate(
		_ tasks: [any OCKAnyTask]
	) async -> [any OCKAnyTask] {
		let defaults = UserDefaults.standard
		let onboardingIDs = Set(TaskID.onboardingIDs)

		let todayOnboardingEvents = await onboardingEvents(on: Date())
		if !todayOnboardingEvents.isEmpty {
			let hasCompletedToday = todayOnboardingEvents.contains(where: \.isComplete)
			defaults.set(hasCompletedToday, forKey: Constants.onboardingCompletedKey)

			guard hasCompletedToday else {
				return tasks.filter { onboardingIDs.contains($0.id) }
			}
			return tasks
		}

		let completionFlag = defaults.bool(forKey: Constants.onboardingCompletedKey)
		guard completionFlag else {
			return tasks.filter { onboardingIDs.contains($0.id) }
		}
		return tasks
	}

	func normalizeVisibleTasks(
		_ tasks: [any OCKAnyTask]
	) -> [any OCKAnyTask] {
		let visibleTasks = tasks.filter(shouldDisplayTask)
		let groupedTasks = Dictionary(grouping: visibleTasks) { task in
			canonicalTaskID(for: task.id)
		}

		return groupedTasks.values.compactMap { group in
			preferredTask(from: group)
		}
	}

	func shouldDisplayTask(_ task: any OCKAnyTask) -> Bool {
		let id = task.id
		if id.hasPrefix("custom_") || id.hasPrefix("custom_hk_") {
			return true
		}

		let currentTaskIDs = Set(AppTaskID.orderedCare + TaskID.onboardingIDs)
		return currentTaskIDs.contains(id)
	}

	func canonicalTaskID(for id: String) -> String {
		TaskID.onboardingIDs.contains(id) ? TaskID.onboarding : id
	}

	func preferredTask(from tasks: [any OCKAnyTask]) -> (any OCKAnyTask)? {
		tasks.max { lhs, rhs in
			preferenceScore(for: lhs) < preferenceScore(for: rhs)
		}
	}

	func preferenceScore(for task: any OCKAnyTask) -> Double {
		let canonicalID = canonicalTaskID(for: task.id)
		let preferredID = canonicalID
		let expectedTitle = expectedTaskTitle(for: canonicalID)
		let expectedCard = expectedCard(for: canonicalID)
		let expectedInstructions = expectedInstructionSnippet(for: canonicalID)
		let title = taskTitle(for: task)
		var score = task.effectiveDate.timeIntervalSince1970

		if task.id == preferredID {
			score += 1_000_000_000_000
		}

		if title == expectedTitle {
			score += 500_000_000_000
		}

		if taskCard(for: task) == expectedCard {
			score += 250_000_000_000
		}

		if let expectedInstructions,
		   taskInstructions(for: task)?.contains(expectedInstructions) == true {
			score += 125_000_000_000
		}

		if canonicalID == AppTaskID.bpMeasurement,
		   let standardTask = task as? OCKTask,
		   hasExpectedMeasurementSurvey(standardTask) {
			score += 750_000_000_000
		}

		return score
	}

	func expectedCard(for id: String) -> CareKitCard {
		switch id {
		case TaskID.onboarding:
			return .uiKitSurvey
		case AppTaskID.medicationChecklist:
			return .checklist
		case AppTaskID.bpMeasurement:
			return .survey
		case AppTaskID.symptomsCheck:
			return .button
		case AppTaskID.morningPrep:
			return .instruction
		case AppTaskID.lowSodiumCheck:
			return .link
		case AppTaskID.walkAssessment:
			return .featured
		case AppTaskID.heartRate:
			return .numericProgress
		case AppTaskID.restingHeartRate:
			return .labeledValue
		default:
			return .custom
		}
	}

	func expectedTaskTitle(for id: String) -> String {
		switch id {
		case TaskID.onboarding:
			return "Hypertension Onboarding"
		case AppTaskID.medicationChecklist:
			return "Medication Adherence"
		case AppTaskID.bpMeasurement:
			return "Measure Blood Pressure"
		case AppTaskID.symptomsCheck:
			return "Symptoms & Side Effects Check"
		case AppTaskID.morningPrep:
			return "Morning BP Prep"
		case AppTaskID.lowSodiumCheck:
			return "Hypertension Education Link"
		case AppTaskID.walkAssessment:
			return "Daily Walking Check"
		case AppTaskID.heartRate:
			return "Heart Rate Trend"
		case AppTaskID.restingHeartRate:
			return "Resting Heart Rate Review"
		default:
			return id
		}
	}

	func expectedInstructionSnippet(for id: String) -> String? {
		switch id {
		case AppTaskID.bpMeasurement:
			return "systolic and diastolic blood pressure values"
		case AppTaskID.symptomsCheck:
			return "Log whether you noticed headache, dizziness"
		case AppTaskID.morningPrep:
			return "Review the correct morning blood pressure routine"
		default:
			return nil
		}
	}

	func taskTitle(for task: any OCKAnyTask) -> String {
		if let standardTask = task as? OCKTask {
			return standardTask.title ?? standardTask.id
		}
		if let healthTask = task as? OCKHealthKitTask {
			return healthTask.title ?? healthTask.id
		}
		return task.id
	}

	func taskInstructions(for task: any OCKAnyTask) -> String? {
		if let standardTask = task as? OCKTask {
			return standardTask.instructions
		}
		if let healthTask = task as? OCKHealthKitTask {
			return healthTask.instructions
		}
		return nil
	}

	func taskCard(for task: any OCKAnyTask) -> CareKitCard {
		if let standardTask = task as? OCKTask {
			return standardTask.card
		}
		if let healthTask = task as? OCKHealthKitTask {
			return healthTask.card
		}
		return .custom
	}

	func hasExpectedMeasurementSurvey(_ task: OCKTask) -> Bool {
		guard let steps = task.surveySteps else {
			return false
		}
		let questionIDs = steps
			.flatMap(\.questions)
			.map(\.id)
		return questionIDs.contains(MeasurementSurveyKind.systolicValue.rawValue)
			&& questionIDs.contains(MeasurementSurveyKind.diastolicValue.rawValue)
	}

	func onboardingEvents(on date: Date = Date()) async -> [OCKAnyEvent] {
		var query = OCKEventQuery(for: date)
		query.taskIDs = TaskID.onboardingIDs

		do {
			return try await store.fetchAnyEvents(query: query)
		} catch {
			Logger.feed.error("Could not fetch onboarding events: \(error, privacy: .public)")
			return []
		}
	}
}

private extension CareViewController {
	func taskViewControllers(
		_ task: any OCKAnyTask,
		on date: Date
	) -> [UIViewController]? {
		var query = OCKEventQuery(for: date)
		query.taskIDs = [task.id]

		if let standardTask = task as? OCKTask {
			return standardTaskViewControllers(standardTask, query: query)
		}

		if let healthTask = task as? OCKHealthKitTask {
			return healthTaskViewControllers(healthTask, query: query)
		}

		return nil
	}

	func standardTaskViewControllers(
		_ task: OCKTask,
		query: OCKEventQuery
	) -> [UIViewController]? {
		switch task.card {
		#if os(iOS)
		case .button:
			return [OCKButtonLogTaskViewController(query: query, store: self.store)]

		case .checklist:
			return [OCKChecklistTaskViewController(query: query, store: self.store)]
		#endif

		case .featured, .grid, .link, .custom, .labeledValue:
			if task.card == .grid {
				#if os(iOS)
				return [OCKGridTaskViewController(query: query, store: self.store)]
				#else
				return [customCardController(query: query)]
				#endif
			}
			return [customCardController(query: query)]

		case .instruction:
			return [hostedCard(InstructionsTaskView.self, query: query)]

		case .simple:
			return [hostedCard(SimpleTaskView.self, query: query)]

		case .survey:
			return makeResearchSurveyController(query: query, task: task)

		#if canImport(ResearchKit) && canImport(ResearchKitUI)
		case .uiKitSurvey:
			return makeUIKitSurveyController(query: query, task: task)
		#endif

		case .numericProgress:
			return [hostedCard(NumericProgressTaskView.self, query: query)]
		}
	}

	func healthTaskViewControllers(
		_ task: OCKHealthKitTask,
		query: OCKEventQuery
	) -> [UIViewController]? {
		switch task.card {
		case .labeledValue:
			return [hostedCard(LabeledValueStatusCardView.self, query: query)]

		case .numericProgress:
			return [hostedCard(NumericProgressStatusCardView.self, query: query)]

		case .featured, .grid, .link, .custom:
			return [customCardController(query: query)]

		default:
			return nil
		}
	}

	func makeResearchSurveyController(
		query: OCKEventQuery,
		task: OCKTask
	) -> [UIViewController]? {
		guard let card = researchSurveyViewController(
			query: query,
			task: task
		) else {
			Logger.feed.warning("Unable to create research survey view controller")
			return nil
		}
		return [card]
	}

	#if canImport(ResearchKit) && canImport(ResearchKitUI)
	func makeUIKitSurveyController(
		query: OCKEventQuery,
		task: OCKTask
	) -> [UIViewController]? {
		guard let survey = task.uiKitSurvey else {
			Logger.feed.error("Can only use a survey for an \"OCKTask\", not \(task.id)")
			return nil
		}

		let surveyCard = OCKSurveyTaskViewController(
			eventQuery: query,
			store: self.store,
			survey: survey.type().createSurvey(),
			viewSynchronizer: SurveyViewSynchronizer(),
			extractOutcome: survey.type().extractAnswers
		)
		surveyCard.surveyDelegate = self
		return [surveyCard]
	}
	#endif

	func researchSurveyViewController(
		query: OCKEventQuery,
		task: OCKTask
	) -> UIViewController? {
		guard let steps = task.surveySteps else {
			return nil
		}

		if task.id == AppTaskID.bpMeasurement {
			let surveyViewController = EventQueryContentView<ResearchSurveyView>(
				query: query
			) {
				EventQueryContentView<MeasurementResearchCareForm>(
					query: query
				) {
					ForEach(steps) { step in
						ResearchFormStep(
							title: task.title,
							subtitle: task.instructions
						) {
							ForEach(step.questions) { question in
								question.view()
							}
						}
					}
				}
			}
			.environment(\.careStore, store)
			.padding(.vertical, swiftUIPadding)
			.formattedHostingController()

			return surveyViewController
		}

		let surveyViewController = EventQueryContentView<ResearchSurveyView>(
			query: query
		) {
			EventQueryContentView<ResearchCareForm>(
				query: query
			) {
				ForEach(steps) { step in
					ResearchFormStep(
						title: task.title,
						subtitle: task.instructions
					) {
						ForEach(step.questions) { question in
							question.view()
						}
					}
				}
			}
		}
		.environment(\.careStore, store)
		.padding(.vertical, swiftUIPadding)
		.formattedHostingController()

		return surveyViewController
	}

	func hostedCard<Card: EventViewable>(
		_ type: Card.Type,
		query: OCKEventQuery
	) -> UIViewController {
		EventQueryView<Card>(query: query)
			.environment(\.careStore, store)
			.padding(.vertical, swiftUIPadding)
			.formattedHostingController()
	}

	func customCardController(query: OCKEventQuery) -> UIViewController {
		EventQueryView<MyCustomCardView>(
			query: query
		)
		.environment(\.careStore, store)
		.padding(.vertical, swiftUIPadding)
		.formattedHostingController()
	}
}

#if canImport(ResearchKit) && canImport(ResearchKitUI)
extension CareViewController: OCKSurveyTaskViewControllerDelegate {
	nonisolated func surveyTask(
		viewController: OCKSurveyTaskViewController,
		for task: any OCKAnyTask,
		didFinish result: Swift.Result<ORKTaskFinishReason, any Error>
	) {
		if case let .success(reason) = result, reason == .completed {
			Task { @MainActor in
				self.reload()
			}
		}
	}
}
#endif

private extension View {
    func formattedHostingController() -> UIHostingController<Self> {
        let viewController = UIHostingController(rootView: self)
        viewController.view.backgroundColor = .clear
		if #available(iOS 16.0, *) {
			viewController.sizingOptions = [.intrinsicContentSize]
		}
        return viewController
    }
}
