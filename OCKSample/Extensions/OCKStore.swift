//
//  OCKStore.swift
//  OCKSample
//
//  Created by Corey Baker on 1/5/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitEssentials
import CareKitStore
import Contacts
import os.log
import ParseSwift
import ParseCareKit

private extension OCKTask {
    func needsSeedMetadataUpdate(from expected: OCKTask) -> Bool {
        // 我这里把 schedule 也算进默认任务修正里；不然老用户同 ID 的旧任务可能还在，但今天的 event 出不来。
        if title != expected.title
            || instructions != expected.instructions
            || asset != expected.asset
            || schedule != expected.schedule
            || carePlanUUID != expected.carePlanUUID
            || impactsAdherence != expected.impactsAdherence
            || card != expected.card
            || priority != expected.priority
            || linkURL != expected.linkURL
            || featuredMessage != expected.featuredMessage {
            return true
        }

        #if os(iOS)
        if uiKitSurvey != expected.uiKitSurvey {
            return true
        }
        if expected.surveySteps != nil && !hasSameSurveyQuestionIDs(as: expected) {
            return true
        }
        #endif

        return false
    }

    func applyingSeedMetadata(from expected: OCKTask) -> OCKTask {
        var updated = self
        updated.title = expected.title
        updated.instructions = expected.instructions
        updated.asset = expected.asset
        updated.schedule = expected.schedule
        updated.carePlanUUID = expected.carePlanUUID
        updated.impactsAdherence = expected.impactsAdherence
        updated.card = expected.card
        updated.priority = expected.priority
        updated.linkURL = expected.linkURL
        updated.featuredMessage = expected.featuredMessage

        #if os(iOS)
        updated.uiKitSurvey = expected.uiKitSurvey
        updated.surveySteps = expected.surveySteps
        #endif

        return updated
    }

    #if os(iOS)
    private func hasSameSurveyQuestionIDs(as expected: OCKTask) -> Bool {
        let currentIDs = surveySteps?
            .flatMap(\.questions)
            .map(\.id) ?? []
        let expectedIDs = expected.surveySteps?
            .flatMap(\.questions)
            .map(\.id) ?? []
        return currentIDs == expectedIDs
    }
    #endif
}

extension OCKStore {
#if os(iOS)
    @MainActor
    class func getCarePlanUUIDs() async throws -> [CarePlanID: UUID] {
        var results = [CarePlanID: UUID]()

        guard let store = AppDelegateKey.defaultValue?.store else {
            return results
        }

        var query = OCKCarePlanQuery(for: Date())
        query.ids = [CarePlanID.health.rawValue]

        let foundCarePlans = try await store.fetchCarePlans(query: query)
        CarePlanID.allCases.forEach { carePlanID in
            results[carePlanID] = foundCarePlans
                .first(where: { $0.id == carePlanID.rawValue })?.uuid
        }
        return results
    }

    func addCarePlansIfNotPresent(
        _ carePlans: [OCKAnyCarePlan],
        patientUUID: UUID? = nil
    ) async throws {
        let carePlanIdsToAdd = carePlans.compactMap(\.id)

        var query = OCKCarePlanQuery(for: Date())
        query.ids = carePlanIdsToAdd
        let foundCarePlans = try await fetchAnyCarePlans(query: query)

        var carePlansNotInStore = [OCKAnyCarePlan]()
        carePlans.forEach { potentialCarePlan in
            if foundCarePlans.first(where: { $0.id == potentialCarePlan.id }) != nil {
                return
            }

            guard var mutableCarePlan = potentialCarePlan as? OCKCarePlan else {
                carePlansNotInStore.append(potentialCarePlan)
                return
            }
            mutableCarePlan.patientUUID = patientUUID
            carePlansNotInStore.append(mutableCarePlan)
        }

        if !carePlansNotInStore.isEmpty {
            _ = try await addAnyCarePlans(carePlansNotInStore)
        }
    }

    #endif

    func addContactsIfNotPresent(_ contacts: [OCKContact]) async throws -> [OCKContact] {
        let contactIdsToAdd = contacts.compactMap { $0.id }

        // Prepare query to see if contacts are already added
        var query = OCKContactQuery(for: Date())
        query.ids = contactIdsToAdd

        let foundContacts = try await fetchContacts(query: query)

        // Find all missing tasks.
        let contactsNotInStore = contacts.filter { potentialContact -> Bool in
            guard foundContacts.first(where: { $0.id == potentialContact.id }) == nil else {
                return false
            }
            return true
        }

        // Only add if there's a new task
        guard contactsNotInStore.count > 0 else {
            return []
        }

        let addedContacts = try await addContacts(contactsNotInStore)
        return addedContacts
    }

    #if os(iOS)
    func populateCarePlans(patientUUID: UUID? = nil) async throws {
        let healthCarePlan = OCKCarePlan(
            id: CarePlanID.health.rawValue,
            title: "Hypertension Care Plan",
            patientUUID: patientUUID
        )
        try await addCarePlansIfNotPresent(
            [healthCarePlan],
            patientUUID: patientUUID
        )
    }

    func createQualityOfLifeSurveyTask(
        carePlanUUID: UUID?,
        startDate: Date = Date()
    ) -> OCKTask {
        let surveySchedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 30,
            start: startDate,
            end: nil,
            text: nil,
            duration: .allDay
        )

        var qualityOfLife = OCKTask(
            id: AppTaskID.bpMeasurement,
            title: "Measure Blood Pressure",
            carePlanUUID: carePlanUUID,
            schedule: surveySchedule
        )
        qualityOfLife.instructions = """
        Enter today's systolic and diastolic blood pressure values from your
        home reading and save both measurements in mmHg.
        """
        qualityOfLife.asset = "drop.circle"
        qualityOfLife.card = .survey
        qualityOfLife.surveySteps = HypertensionSurveyFactory.measurementSurveySteps(
            taskID: AppTaskID.bpMeasurement
        )
        qualityOfLife.priority = 20
        qualityOfLife.impactsAdherence = true
        return qualityOfLife
    }

    func addOnboardingTask(
        _ carePlanUUID: UUID? = nil,
        startDate: Date = Date()
    ) async throws -> [OCKTask] {
        try await addTasksIfNotPresent([
            makeOnboardingTask(carePlanUUID: carePlanUUID, startDate: startDate)
        ])
    }

    func addUIKitSurveyTasks(
        _ carePlanUUID: UUID? = nil,
        startDate: Date = Date()
    ) async throws -> [OCKTask] {
        try await addTasksIfNotPresent([
            makeWalkAssessmentTask(carePlanUUID: carePlanUUID, startDate: startDate)
        ])
    }
#endif

    // Adds tasks and contacts into the store
    func populateDefaultCarePlansTasksContacts(
        _ patientUUID: UUID? = nil,
        startDate: Date = Date(),
        preserveHistoricalWindow: Bool = true
    ) async throws {
#if os(iOS)
        try await populateCarePlans(patientUUID: patientUUID)
        let carePlanUUIDs = try await Self.getCarePlanUUIDs()
        let healthCarePlanUUID = carePlanUUIDs[.health]
#else
        let healthCarePlanUUID: UUID? = nil
#endif
        let today = Date()
        let anchorDate = Calendar.current.startOfDay(for: startDate)
        let taskStartDate = preserveHistoricalWindow
            ? Calendar.current.date(byAdding: .day, value: -6, to: anchorDate)!
            : anchorDate
        let educationStartDate = preserveHistoricalWindow
            ? Calendar.current.date(byAdding: .day, value: -7, to: anchorDate)!
            : anchorDate

        let medicationSchedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 0,
            start: taskStartDate,
            end: nil,
            text: nil
        )

        var medicationChecklist = OCKTask(
            id: AppTaskID.medicationChecklist,
            title: "Medication Adherence",
            carePlanUUID: healthCarePlanUUID,
            schedule: medicationSchedule
        )
        medicationChecklist.instructions = """
        Confirm that you took your blood pressure medication and followed
        today's treatment routine.
        """
        medicationChecklist.asset = "pills.fill"
        medicationChecklist.card = .checklist
        medicationChecklist.priority = 10
        medicationChecklist.impactsAdherence = true

#if os(iOS)
        let measurementTask = createQualityOfLifeSurveyTask(
            carePlanUUID: healthCarePlanUUID,
            startDate: taskStartDate
        )
#else
        var measurementTask = OCKTask(
            id: AppTaskID.bpMeasurement,
            title: "Measure Blood Pressure",
            carePlanUUID: healthCarePlanUUID,
            schedule: medicationSchedule
        )
        measurementTask.instructions = """
        Enter today's systolic and diastolic blood pressure values from your
        home reading and save both measurements in mmHg.
        """
        measurementTask.asset = "drop.circle"
        measurementTask.card = .simple
        measurementTask.priority = 20
        measurementTask.impactsAdherence = true
#endif

        let morningPrepSchedule = OCKSchedule.dailyAtTime(
            hour: 7,
            minutes: 0,
            start: taskStartDate,
            end: nil,
            text: "Review before your morning reading",
            duration: .allDay
        )

        var morningPrep = OCKTask(
            id: AppTaskID.morningPrep,
            title: "Morning BP Prep",
            carePlanUUID: healthCarePlanUUID,
            schedule: morningPrepSchedule
        )
        morningPrep.instructions = """
        Review the correct morning blood pressure routine: sit quietly for five
        minutes, keep both feet on the floor, and place the cuff at heart level.
        """
        morningPrep.asset = "list.bullet.clipboard"
        morningPrep.card = .instruction
        morningPrep.priority = 25
        morningPrep.impactsAdherence = false

        let symptomsSchedule = OCKSchedule.dailyAtTime(
            hour: 18,
            minutes: 0,
            start: taskStartDate,
            end: nil,
            text: "Check in this evening",
            duration: .hours(1)
        )

        var symptomsCheck = OCKTask(
            id: AppTaskID.symptomsCheck,
            title: "Symptoms & Side Effects Check",
            carePlanUUID: healthCarePlanUUID,
            schedule: symptomsSchedule
        )
        symptomsCheck.instructions = """
        Log whether you noticed headache, dizziness, fatigue, or any other
        symptoms that matter for today's blood pressure care.
        """
        symptomsCheck.asset = "exclamationmark.bubble"
        symptomsCheck.card = .button
        symptomsCheck.priority = 35
        symptomsCheck.impactsAdherence = false

        let lowSodiumSchedule = OCKSchedule(composing: [
            OCKScheduleElement(
                start: Calendar.current.date(
                    bySettingHour: 12,
                    minute: 0,
                    second: 0,
                    of: educationStartDate
                )!,
                end: nil,
                interval: DateComponents(day: 7),
                text: "Review once this week",
                targetValues: [],
                duration: .allDay
            )
        ])

        var lowSodium = OCKTask(
            id: AppTaskID.lowSodiumCheck,
            title: "Hypertension Education Link",
            carePlanUUID: healthCarePlanUUID,
            schedule: lowSodiumSchedule
        )
        lowSodium.instructions = """
        Review this week's low-sodium guide to support healthier blood
        pressure habits.
        """
        lowSodium.asset = "fork.knife.circle"
        lowSodium.card = .link
        lowSodium.linkURL =
            "https://www.heart.org/en/health-topics/high-blood-pressure/"
            + "changes-you-can-make-to-manage-high-blood-pressure/"
            + "eating-a-diet-that-is-low-in-salt"
        lowSodium.priority = 45
        lowSodium.impactsAdherence = false

        let onboardingTask = makeOnboardingTask(
            carePlanUUID: healthCarePlanUUID,
            startDate: taskStartDate
        )
        let walkAssessment = makeWalkAssessmentTask(
            carePlanUUID: healthCarePlanUUID,
            startDate: taskStartDate
        )

        let seededTasks = [
            onboardingTask,
            medicationChecklist,
            measurementTask,
            morningPrep,
            symptomsCheck,
            lowSodium,
            walkAssessment
        ]

        try await addOrUpdateSeededTasksIfNeeded(seededTasks)

        var todayQuery = OCKTaskQuery(for: today)
        todayQuery.excludesTasksWithNoEvents = false
        let todayTasks = try await fetchAnyTasks(query: todayQuery)
        Logger.ockStore.info("Hypertension seeding complete. Tasks available for today: \(todayTasks.count)")

        var contact1 = OCKContact(
            id: "sarah-thompson",
            givenName: "Sarah",
            familyName: "Thompson",
            carePlanUUID: nil
        )
        contact1.title = "Primary Care Physician"
        contact1.role = "Dr. Thompson is a primary care physician supporting medication adherence, "
            + "lifestyle coaching, and home blood pressure monitoring."
        contact1.emailAddresses = [OCKLabeledValue(label: CNLabelEmailiCloud, value: "janedaniels@uky.edu")]
        contact1.phoneNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 257-2000")]
        contact1.messagingNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 357-2040")]
        contact1.address = {
            let address = OCKPostalAddress(
				street: "1500 San Pablo St",
				city: "Los Angeles",
				state: "CA",
				postalCode: "90033",
				country: "US"
			)
            return address
        }()

        var contact2 = OCKContact(
            id: "michael-chen",
            givenName: "Michael",
            familyName: "Chen",
            carePlanUUID: nil
        )
        contact2.title = "Cardiologist"
        contact2.role = "Dr. Chen is a cardiologist specializing in hypertension management "
            + "and cardiovascular risk reduction."
        contact2.phoneNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 257-1000")]
        contact2.messagingNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 257-1234")]
        contact2.address = {
			let address = OCKPostalAddress(
				street: "1500 San Pablo St",
				city: "Los Angeles",
				state: "CA",
				postalCode: "90033",
				country: "US"
			)
            return address
        }()

        _ = try await addContactsIfNotPresent(
            [
                contact1,
                contact2
            ]
        )
    }

    private func addOrUpdateSeededTasksIfNeeded(_ tasks: [OCKTask]) async throws {
        // 我这里只补齐或更新默认任务的 metadata，不删除 outcome，避免升级时误伤用户数据。
        let taskIDs = tasks.map(\.id)
        var query = OCKTaskQuery()
        query.ids = taskIDs

        let existingTasks = try await fetchTasks(query: query)
        var tasksToAdd = [OCKTask]()
        var tasksToUpdate = [OCKTask]()

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

    private func makeOnboardingTask(
        carePlanUUID: UUID?,
        startDate: Date
    ) -> OCKTask {
        let onboardSchedule = OCKSchedule.dailyAtTime(
            hour: 0,
            minutes: 0,
            start: startDate,
            end: nil,
            text: String(localized: "ANYTIME_DURING_DAY"),
            duration: .allDay
        )

        var onboardTask = OCKTask(
            id: TaskID.onboarding,
            title: "Hypertension Onboarding",
            carePlanUUID: carePlanUUID,
            schedule: onboardSchedule
        )
        onboardTask.instructions = """
        Join the blood pressure program, review consent, and unlock today's
        hypertension tasks.
        """
        onboardTask.asset = "heart.text.square.fill"
        onboardTask.impactsAdherence = false
#if os(iOS)
        onboardTask.card = .uiKitSurvey
        onboardTask.uiKitSurvey = .onboard
#else
        onboardTask.card = .instruction
#endif
        onboardTask.priority = 0
        return onboardTask
    }

    private func makeWalkAssessmentTask(
        carePlanUUID: UUID?,
        startDate: Date
    ) -> OCKTask {
        let walkStart = Calendar.current.date(
            bySettingHour: 17,
            minute: 30,
            second: 0,
            of: startDate
        )!
        let walkAssessmentSchedule = OCKSchedule(composing: [
            OCKScheduleElement(
                start: walkStart,
                end: nil,
                interval: DateComponents(day: 2)
            )
        ])

        var walkAssessment = OCKTask(
            id: AppTaskID.walkAssessment,
            title: "Daily Walking Check",
            carePlanUUID: carePlanUUID,
            schedule: walkAssessmentSchedule
        )
        walkAssessment.instructions = """
        Complete a guided short walking check to see whether today's
        activity tolerance supports your blood pressure goals.
        """
        walkAssessment.asset = "figure.walk.motion"
        walkAssessment.featuredMessage = """
        Start a guided walking check and save whether your daily activity felt
        comfortable or limited today.
        """
        walkAssessment.impactsAdherence = false
        walkAssessment.card = .featured
#if os(iOS)
        walkAssessment.uiKitSurvey = .rangeOfMotion
#endif
        walkAssessment.priority = 55
        return walkAssessment
    }

}
