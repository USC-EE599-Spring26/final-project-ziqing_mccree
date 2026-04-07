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
import SwiftUI
import UIKit
@preconcurrency import ResearchKit
@preconcurrency import ResearchKitUI

@MainActor
final class CareViewController: OCKDailyPageViewController, @unchecked Sendable {

    var appStore: OCKAnyStoreProtocol { AppDelegateKey.defaultValue!.store }

	private var isSyncing = false
	private var isLoading = false
	private var isReloadingView = false
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

        AppDelegateKey.defaultValue?.store.synchronize { [weak self] (error: Error?) in
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

    private func fetchAndDisplayTasks(
        on listViewController: OCKListViewController,
        for date: Date
    ) {
        Task {
            let tasks = await self.fetchTasks(on: date)
			appendTasks(tasks, to: listViewController, date: date)
        }
    }

    private func fetchTasks(on date: Date) async -> [any OCKAnyTask] {
        var query = OCKTaskQuery(for: date)
        let onboardingDone = UserDefaults.standard.bool(forKey: Constants.onboardingCompletedKey)
        // Until onboarding is finished, include tasks without events so the gate task always appears.
        query.excludesTasksWithNoEvents = onboardingDone
        do {
            let tasks = try await appStore.fetchAnyTasks(query: query)
            let filtered = filterOutDemoTasks(tasks)
            return applyOnboardingGate(filtered)
        } catch {
            print("❌ fetchTasks error=\(error)")
            Logger.feed.error("Could not fetch tasks: \(error, privacy: .public)")
            return []
        }
    }

    private func taskViewControllers(
        _ task: any OCKAnyTask,
        on date: Date
    ) -> [UIViewController]? {

        let query = OCKEventQuery(for: date)

        #if os(iOS)
        if task.id == TaskID.onboarding {
            var taskQuery = query
            taskQuery.taskIDs = [TaskID.onboarding]
            return [OnboardingGateViewController(store: appStore, eventQuery: taskQuery)]
        }
        if task.id == AppTaskID.rangeOfMotion {
            var taskQuery = query
            taskQuery.taskIDs = [AppTaskID.rangeOfMotion]
            return [RaiseArmGateViewController(store: appStore, eventQuery: taskQuery)]
        }
        #endif

        // Prefer stored card type for OCKTask (custom + hypertension tasks).
        if let ockTask = task as? OCKTask,
           let cards = makeControllersForCardType(task: ockTask, query: query),
           !cards.isEmpty {
            return cards
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
                store: appStore
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
                store: appStore
            )

            return [nauseaCard]

            #else
            return []
            #endif

        default:
            return nil
        }
    }

    private func appendTasks(
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
}

/// Hypertension onboarding CareKit card; completing the card (or tapping the card) launches ResearchKit onboarding.
final class OnboardingGateViewController: OCKInstructionsTaskViewController {

    private var isResearchKitPresented = false

    init(store: OCKAnyStoreProtocol, eventQuery: OCKEventQuery) {
        var onboardingQuery = eventQuery
        onboardingQuery.taskIDs = [TaskID.onboarding]
        super.init(query: onboardingQuery, store: store)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func taskView(
        _ taskView: UIView & OCKTaskDisplayable,
        didCompleteEvent isComplete: Bool,
        at indexPath: IndexPath,
        sender: Any?
    ) {
        presentResearchKitFlowIfNeeded()
    }

    override func didSelectTaskView(_ taskView: UIView & OCKTaskDisplayable, eventIndexPath: IndexPath) {
        presentResearchKitFlowIfNeeded()
    }

    private func presentResearchKitFlowIfNeeded() {
        guard !isResearchKitPresented else { return }
        isResearchKitPresented = true
        let taskVC = ORKTaskViewController(task: Onboarding.task, taskRun: UUID())
        taskVC.delegate = self
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(taskVC, animated: true)
    }
}

/// Presents ResearchKit “Raise Arm 4 Times” and records completion on the CareKit event when finished.
final class RaiseArmGateViewController: OCKInstructionsTaskViewController {

    private var isResearchKitPresented = false
    /// Retained because `OCKTaskViewController`’s `store` is `internal` to CareKit and not visible to subclasses.
    private let eventStore: OCKAnyStoreProtocol

    init(store: OCKAnyStoreProtocol, eventQuery: OCKEventQuery) {
        self.eventStore = store
        var raiseArmQuery = eventQuery
        raiseArmQuery.taskIDs = [AppTaskID.rangeOfMotion]
        super.init(query: raiseArmQuery, store: store)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func taskView(
        _ taskView: UIView & OCKTaskDisplayable,
        didCompleteEvent isComplete: Bool,
        at indexPath: IndexPath,
        sender: Any?
    ) {
        presentRaiseArmFlowIfNeeded()
    }

    override func didSelectTaskView(_ taskView: UIView & OCKTaskDisplayable, eventIndexPath: IndexPath) {
        presentRaiseArmFlowIfNeeded()
    }

    private func presentRaiseArmFlowIfNeeded() {
        guard !isResearchKitPresented else { return }
        isResearchKitPresented = true
        let taskVC = ORKTaskViewController(task: RaiseArmExercise.task, taskRun: UUID())
        taskVC.delegate = self
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(taskVC, animated: true)
    }

    private func firstEventInViewModel() -> OCKAnyEvent? {
        for section in viewModel {
            if let event = section.first {
                return event
            }
        }
        return nil
    }

    private func markTodaysEventCompletedIfNeeded() {
        guard let event = firstEventInViewModel() else {
            postCareRefresh()
            return
        }
        if event.outcome != nil {
            postCareRefresh()
            return
        }
        eventStore.fetchAnyEvent(
            forTask: event.task,
            occurrence: event.scheduleEvent.occurrence,
            callbackQueue: .main
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .failure:
                Task { @MainActor [weak self] in self?.postCareRefresh() }
            case .success(let fresh):
                if let outcome = fresh.outcome {
                    self.eventStore.deleteAnyOutcome(outcome) { _ in
                        Task { @MainActor [weak self] in self?.postCareRefresh() }
                    }
                } else {
                    let newOutcome = OCKOutcome(
                        taskUUID: fresh.task.uuid,
                        taskOccurrenceIndex: fresh.scheduleEvent.occurrence,
                        values: [OCKOutcomeValue(true)]
                    )
                    self.eventStore.addAnyOutcome(newOutcome) { _ in
                        Task { @MainActor [weak self] in self?.postCareRefresh() }
                    }
                }
            }
        }
    }

    private func postCareRefresh() {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: Constants.shouldRefreshView),
            object: nil
        )
    }
}

extension RaiseArmGateViewController: ORKTaskViewControllerDelegate {

    nonisolated func taskViewController(
        _ taskViewController: ORKTaskViewController,
        didFinishWith reason: ORKTaskFinishReason,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.isResearchKitPresented = false
            if reason == .completed {
                self?.markTodaysEventCompletedIfNeeded()
            }
            taskViewController.dismiss(animated: true, completion: nil)
        }
    }
}

extension OnboardingGateViewController: ORKTaskViewControllerDelegate {

    nonisolated func taskViewController(
        _ taskViewController: ORKTaskViewController,
        didFinishWith reason: ORKTaskFinishReason,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.isResearchKitPresented = false
            if reason == .completed {
                UserDefaults.standard.set(true, forKey: Constants.onboardingCompletedKey)
                Utility.requestHealthKitPermissions()
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: Constants.shouldRefreshView),
                    object: nil
                )
            }
            taskViewController.dismiss(animated: true, completion: nil)
        }
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
