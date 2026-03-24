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
#if canImport(ResearchKitSwiftUI)
import ResearchKitSwiftUI
#endif
import SwiftUI
import UIKit

@MainActor
final class CareViewController: OCKDailyPageViewController, @unchecked Sendable {

	private var isSyncing = false
	private var isLoading = false
	private var isReloadingView = false
    private let swiftUIPadding: CGFloat = 15
    private var style: Styler {
        CustomStylerKey.defaultValue
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Random Survey",
            style: .plain,
            target: self,
            action: #selector(presentRandomSurvey)
        )
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

			// Give sometime for the user to see 100
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
        // Only one sync at a time; ignore new requests while syncing.
        guard !isSyncing else { return }

        isSyncing = true

        AppDelegateKey.defaultValue?.store.synchronize { [weak self] error in
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

                // Avoid infinite refresh loop: do not post shouldRefreshView from inside CareViewController.
                // NotificationCenter.default.post(
                //     .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
                // )
            }
        }
    }

    @objc private func presentRandomSurvey() {
        Task {
            let today = Date()
            var query = OCKTaskQuery(for: today)
            query.excludesTasksWithNoEvents = false
            query.ids = AppTaskID.surveyTaskIDs

            do {
                let surveyTasks: [OCKTask]
                if let ockStore = store as? OCKStore {
                    surveyTasks = try await ockStore.fetchTasks(query: query)
                } else {
                    let tasks = try await store.fetchAnyTasks(query: query)
                    surveyTasks = tasks.compactMap { $0 as? OCKTask }
                }
                let availableSurveyTasks = surveyTasks.filter { task in
                    guard task.card == .survey else {
                        return false
                    }
#if canImport(ResearchKitSwiftUI)
                    return !(task.surveySteps?.isEmpty ?? true)
#else
                    return true
#endif
                }
                guard let randomSurvey = availableSurveyTasks.randomElement() else {
                    showNoSurveyAlert()
                    return
                }

                let eventQuery = OCKEventQuery(for: today)
                guard let surveyVC = researchSurveyViewController(query: eventQuery, task: randomSurvey) else {
                    showNoSurveyAlert()
                    return
                }
                surveyVC.title = randomSurvey.title ?? "Survey"
                navigationController?.pushViewController(surveyVC, animated: true)
            } catch {
                Logger.feed.error("Failed to load random survey: \(error, privacy: .public)")
                showNoSurveyAlert()
            }
        }
    }

    private func showNoSurveyAlert() {
        let alert = UIAlertController(
            title: "No Survey Available",
            message: "Could not find a survey task for today.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func reloadView(_ notification: Notification? = nil) {
        guard !isReloadingView else { return }
        isReloadingView = true
        defer { isReloadingView = false }
        guard !isLoading else { return }
        self.reload()
    }

    /*
     This will be called each time the selected date changes.
     Use this as an opportunity to rebuild the content shown to the user.
     */
    override func dailyPageViewController(
        _ dailyPageViewController: OCKDailyPageViewController,
        prepare listViewController: OCKListViewController,
        for date: Date
    ) {
        self.isLoading = true

        // Always call this method to ensure dates for
        // queries are correct.
        let date = modifyDateIfNeeded(date)

        fetchAndDisplayTasks(on: listViewController, for: date)
    }

}

private extension CareViewController {
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(
            date,
            inSameDayAs: Date()
        )
    }

    func modifyDateIfNeeded(_ date: Date) -> Date {
        guard date < .now else {
            return date
        }
        guard !isSameDay(as: date) else {
            return .now
        }
        return date.endOfDay
    }

    func fetchAndDisplayTasks(
        on listViewController: OCKListViewController,
        for date: Date
    ) {
        Task {
            let tasks = await self.fetchTasks(on: date)
            appendTasks(tasks, to: listViewController, date: date)
            if let ockStore = store as? OCKStore {
                await ockStore.persistLatestSurveySummariesToCurrentUser()
            }
        }
    }

    func fetchTasks(on date: Date) async -> [any OCKAnyTask] {
        var query = OCKTaskQuery(for: date)
        query.excludesTasksWithNoEvents = false
        do {
            let tasks = try await store.fetchAnyTasks(query: query)
            let filtered = filterOutDemoTasks(tasks)
            return await riskAdjustedTasks(filtered)
        } catch {
            print("❌ fetchTasks error=\(error)")
            Logger.feed.error("Could not fetch tasks: \(error, privacy: .public)")
            return []
        }
    }

    func taskViewControllers(
        _ task: any OCKAnyTask,
        on date: Date
    ) -> [UIViewController]? {

        let query = OCKEventQuery(for: date)

        // Prefer stored card type for OCKTask (custom + hypertension tasks).
        if let ockTask = task as? OCKTask {
            if ockTask.card == .survey,
               let surveyController = researchSurveyViewController(query: query, task: ockTask) {
                return [surveyController]
            }
            if let cards = makeControllersForCardType(task: ockTask, query: query),
               !cards.isEmpty {
                return cards
            }
        }

        switch task.id {
        case TaskID.steps:
            let card = EventQueryView<NumericProgressTaskView>(
                query: query
            )
            .formattedHostingController()

            return [card]

        case TaskID.ovulationTestResult:
            let card = EventQueryView<LabeledValueTaskView>(
                query: query
            )
            .formattedHostingController()

            return [card]

        case TaskID.stretch:
            let card = EventQueryView<InstructionsTaskView>(
                query: query
            )
            .formattedHostingController()

            return [card]

        case TaskID.kegels:
            /*
             Since the kegel task is only scheduled every other day, there will be cases
             where it is not contained in the tasks array returned from the query.
             */
            let card = EventQueryView<SimpleTaskView>(
                query: query
            )
            .formattedHostingController()

            return [card]

        #if os(iOS)
        // Create a card for the doxylamine task if there are events for it on this day.
        case TaskID.doxylamine:

            // This is a UIKit based card.
            let card = OCKChecklistTaskViewController(
                query: query,
                store: self.store
            )

            return [card]
        #endif

        case TaskID.nausea:

        #if os(iOS)
            /*
             Also create a card (UIKit view) that displays a single event.
             The event query passed into the initializer specifies that only
             today's log entries should be displayed by this log task view controller.
             */
            let nauseaCard = OCKButtonLogTaskViewController(
                query: query,
                store: self.store
            )

            return [nauseaCard]

            #else
            return []
            #endif

        default:
            return nil
        }
    }

    func researchSurveyViewController(
        query: OCKEventQuery,
        task: OCKTask
    ) -> UIViewController? {
        #if canImport(ResearchKitSwiftUI)
        guard let steps = task.surveySteps else {
            return nil
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
        .padding(.vertical, swiftUIPadding)
        .formattedHostingController()

        return surveyViewController
        #else
        return nil
        #endif
    }

    func appendTasks(
        _ tasks: [any OCKAnyTask],
        to listViewController: OCKListViewController,
        date: Date
    ) {
        let isCurrentDay = isSameDay(as: date)
        var fallbackTasks: [any OCKAnyTask] = []

        for task in tasks {
            let cards = self.taskViewControllers(
                task,
                on: date
            ) ?? []

            // If no cards were produced for this task, show it in the fallback list.
            guard !cards.isEmpty else {
                fallbackTasks.append(task)
                continue
            }

            cards.forEach { viewController in
                if let carekitView = viewController.view as? OCKView {
                    carekitView.customStyle = style
                }
                viewController.view.isUserInteractionEnabled = isCurrentDay
                viewController.view.alpha = !isCurrentDay ? 0.4 : 1.0
                listViewController.appendViewController(viewController, animated: true)
            }
        }

        #if os(iOS)
        if !fallbackTasks.isEmpty {
            let fallbackVC = DailyTaskListViewController(tasks: fallbackTasks)
            fallbackVC.view.isUserInteractionEnabled = isCurrentDay
            fallbackVC.view.alpha = !isCurrentDay ? 0.4 : 1.0
            fallbackVC.view.layer.cornerRadius = 12
            fallbackVC.view.clipsToBounds = true
            fallbackVC.view.backgroundColor = .clear
            listViewController.appendViewController(fallbackVC, animated: true)

        }
        #endif
        self.isLoading = false
    }

    func riskAdjustedTasks(_ tasks: [any OCKAnyTask]) async -> [any OCKAnyTask] {
        do {
            let user = try await User.current()
            let levelRaw = user.surveyResponseSummaries?["bpRiskLevel"] ?? HypertensionRiskLevel.green.rawValue
            let level = HypertensionRiskLevel(rawValue: levelRaw) ?? .green
            let rank = riskRankMap(for: level)

            return tasks.sorted { left, right in
                let leftRank = rank[left.id] ?? 1000
                let rightRank = rank[right.id] ?? 1000
                if leftRank == rightRank {
                    return left.id < right.id
                }
                return leftRank < rightRank
            }
        } catch {
            return tasks
        }
    }

    func riskRankMap(for level: HypertensionRiskLevel) -> [String: Int] {
        let orderedIDs: [String]
        switch level {
        case .red:
            orderedIDs = [
                AppTaskID.bpMedicationAM,
                AppTaskID.bpMedicationPM,
                AppTaskID.bpMeasurement,
                AppTaskID.bpMedicationCheckinSurvey,
                AppTaskID.bpSymptomsSurvey,
                AppTaskID.bpLifestyleSurvey,
                AppTaskID.lowSodiumCheck,
                AppTaskID.exercise
            ]
        case .yellow:
            orderedIDs = [
                AppTaskID.bpMedicationAM,
                AppTaskID.bpMedicationPM,
                AppTaskID.bpMeasurement,
                AppTaskID.bpMedicationCheckinSurvey,
                AppTaskID.bpSymptomsSurvey,
                AppTaskID.lowSodiumCheck,
                AppTaskID.exercise,
                AppTaskID.bpLifestyleSurvey
            ]
        case .green:
            orderedIDs = [
                AppTaskID.bpMedicationAM,
                AppTaskID.bpMedicationPM,
                AppTaskID.bpMeasurement,
                AppTaskID.lowSodiumCheck,
                AppTaskID.exercise,
                AppTaskID.bpMedicationCheckinSurvey,
                AppTaskID.bpSymptomsSurvey,
                AppTaskID.bpLifestyleSurvey
            ]
        }

        return Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, $0.offset) })
    }
}

private extension View {
    /// Convert SwiftUI view to UIKit view.
    func formattedHostingController() -> UIHostingController<Self> {
        let viewController = UIHostingController(rootView: self)
        viewController.view.backgroundColor = .clear
        return viewController
    }
}
