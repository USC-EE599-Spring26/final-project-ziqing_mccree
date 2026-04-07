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

extension OCKStore {

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

    // Adds tasks and contacts into the store
    func populateDefaultCarePlansTasksContacts(
		startDate: Date = Date()
	) async throws {

        let today = Date()
        let thisMorning = Calendar.current.startOfDay(for: today)
        let aFewDaysAgo = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: thisMorning
        )!
        // let beforeBreakfast = Calendar.current.date(byAdding: .hour, value: 8, to: aFewDaysAgo)!
        // let afterLunch = Calendar.current.date(byAdding: .hour, value: 14, to: aFewDaysAgo)!

        /*let schedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: beforeBreakfast,
                    end: nil,
                    interval: DateComponents(day: 1)
                ),
                OCKScheduleElement(
                    start: afterLunch,
                    end: nil,
                    interval: DateComponents(day: 2)
                )
            ]
        )*/

       /* var doxylamine = OCKTask(
            id: TaskID.doxylamine,
            title: String(localized: "TAKE_DOXYLAMINE"),
            carePlanUUID: nil,
            schedule: schedule
        )
        doxylamine.instructions = String(localized: "DOXYLAMINE_INSTRUCTIONS")
        doxylamine.asset = "pills.fill"
        doxylamine.card = .button

        let nauseaSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: beforeBreakfast,
                    end: nil,
                    interval: DateComponents(day: 1),
                    text: String(localized: "ANYTIME_DURING_DAY"),
                    targetValues: [],
                    duration: .allDay
                )
            ]
        )

        var nausea = OCKTask(
            id: TaskID.nausea,
            title: String(localized: "TRACK_NAUSEA"),
            carePlanUUID: nil,
            schedule: nauseaSchedule
        )
        nausea.impactsAdherence = false
        nausea.instructions = String(localized: "NAUSEA_INSTRUCTIONS")
        nausea.asset = "bed.double"
        nausea.card = .grid

        let kegelElement = OCKScheduleElement(
            start: beforeBreakfast,
            end: nil,
            interval: DateComponents(day: 2)
        )
        let kegelSchedule = OCKSchedule(
            composing: [kegelElement]
        )
        var kegels = OCKTask(
            id: TaskID.kegels,
            title: String(localized: "KEGEL_EXERCISES"),
            carePlanUUID: nil,
            schedule: kegelSchedule
        )
        kegels.impactsAdherence = true
        kegels.instructions = String(localized: "KEGEL_INSTRUCTIONS")

        let stretchElement = OCKScheduleElement(
            start: beforeBreakfast,
            end: nil,
            interval: DateComponents(day: 1)
        )
        let stretchSchedule = OCKSchedule(
            composing: [stretchElement]
        )
        var stretch = OCKTask(
            id: TaskID.stretch,
            title: String(localized: "STRETCH"),
            carePlanUUID: nil,
            schedule: stretchSchedule
        )
        stretch.impactsAdherence = true
        stretch.asset = "figure.walk"

        _ = try await addTasksIfNotPresent(
            [
                nausea,
                doxylamine,
                kegels,
                stretch
            ]
        )*/
        // ===== Hypertension default tasks =====

        // Times
        let medAMTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: aFewDaysAgo)!
        let medPMTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: aFewDaysAgo)!
        let bpTime    = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: aFewDaysAgo)!
        let exerciseTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: aFewDaysAgo)!

        let scheduleMedAM = OCKSchedule(composing: [
            OCKScheduleElement(start: medAMTime, end: nil, interval: DateComponents(day: 1))
        ])

        let scheduleMedPM = OCKSchedule(composing: [
            OCKScheduleElement(start: medPMTime, end: nil, interval: DateComponents(day: 1))
        ])

        let scheduleBP = OCKSchedule(composing: [
            OCKScheduleElement(start: bpTime, end: nil, interval: DateComponents(day: 1))
        ])

        let scheduleExercise = OCKSchedule(composing: [
            OCKScheduleElement(start: exerciseTime, end: nil, interval: DateComponents(day: 2))
        ])

        let scheduleAnytime = OCKSchedule(composing: [
            OCKScheduleElement(
                start: aFewDaysAgo,
                end: nil,
                interval: DateComponents(day: 1),
                text: String(localized: "ANYTIME_DURING_DAY"),
                targetValues: [],
                duration: .allDay
            )
        ])

        var medAM = OCKTask(
            id: AppTaskID.bpMedicationAM,
            title: "Take Blood Pressure Medication (AM)",
            carePlanUUID: nil,
            schedule: scheduleMedAM
        )
        medAM.instructions = "Take your morning blood pressure medication as prescribed."
        medAM.asset = "pills.fill"
        medAM.card = .button
        medAM.impactsAdherence = true

        var medPM = OCKTask(
            id: AppTaskID.bpMedicationPM,
            title: "Take Blood Pressure Medication (PM)",
            carePlanUUID: nil,
            schedule: scheduleMedPM
        )
        medPM.instructions = "Take your evening blood pressure medication as prescribed."
        medPM.asset = "pills.fill"
        medPM.card = .button
        medPM.impactsAdherence = true

        var measureBP = OCKTask(
            id: AppTaskID.bpMeasurement,
            title: "Measure Blood Pressure",
            carePlanUUID: nil,
            schedule: scheduleBP
        )
        measureBP.instructions = "Measure your blood pressure and record the systolic/diastolic values."
        measureBP.asset = "heart.text.square"
        // 如果这里报错，就用 Xcode 自动补全选一个你项目里存在的 card case
        measureBP.card = .numericProgress
        measureBP.impactsAdherence = true

        var lowSodium = OCKTask(
            id: AppTaskID.lowSodiumCheck,
            title: "Low-Sodium Diet Check",
            carePlanUUID: nil,
            schedule: scheduleAnytime
        )
        lowSodium.instructions = "Did you follow a low-sodium diet today? Tap to log."
        lowSodium.asset = "fork.knife"
        lowSodium.card = .grid
        lowSodium.impactsAdherence = false

        var exercise = OCKTask(
            id: AppTaskID.exercise,
            title: "Hypertension Exercise Session",
            carePlanUUID: nil,
            schedule: scheduleExercise
        )
        exercise.instructions = "Walk briskly for 20 minutes or do light cardio."
        exercise.asset = "figure.walk"
        exercise.card = .button
        exercise.impactsAdherence = true

        var rangeOfMotion = OCKTask(
            id: AppTaskID.rangeOfMotion,
            title: "Raise Arm 4 Times",
            carePlanUUID: nil,
            schedule: scheduleAnytime
        )
        rangeOfMotion.instructions = """
        Tap the card to open guided steps. Slowly raise your arm and lower it back down; repeat 4 times. This \
        supports relaxation and healthy blood pressure prevention. Stop if you feel dizzy or uncomfortable.
        """
        rangeOfMotion.asset = "figure.flexibility"
        rangeOfMotion.card = .instruction
        rangeOfMotion.impactsAdherence = false

        let onboardSchedule = OCKSchedule.dailyAtTime(
            hour: 0,
            minutes: 0,
            start: aFewDaysAgo,
            end: nil,
            text: "Task Due!",
            duration: .allDay
        )

        var onboardTask = OCKTask(
            id: TaskID.onboarding,
            title: "Hypertension Onboarding",
            carePlanUUID: nil,
            schedule: onboardSchedule
        )

        onboardTask.instructions = """
        Tap this card or use Complete to start hypertension onboarding: program enrollment, instructions, \
        consent signature, and blood pressure–related Health permissions. Until you finish, other daily tasks \
        stay hidden.
        """
        onboardTask.asset = "heart.text.square.fill"
        onboardTask.card = .instruction
        onboardTask.impactsAdherence = false
        _ = try await addTasksIfNotPresent(
            [
                medAM,
                medPM,
                measureBP,
                lowSodium,
                exercise,
                rangeOfMotion,
                onboardTask
            ]
        )
        medAM.instructions = "Take your morning blood pressure medication as prescribed."
        medAM.asset = "pills.fill"
        medAM.card = .button
        medAM.impactsAdherence = true

        var medPM = OCKTask(
            id: AppTaskID.bpMedicationPM,
            title: "Take Blood Pressure Medication (PM)",
            carePlanUUID: nil,
            schedule: scheduleMedPM
        )
        medPM.instructions = "Take your evening blood pressure medication as prescribed."
        medPM.asset = "pills.fill"
        medPM.card = .button
        medPM.impactsAdherence = true

        var measureBP = OCKTask(
            id: AppTaskID.bpMeasurement,
            title: "Measure Blood Pressure",
            carePlanUUID: nil,
            schedule: scheduleBP
        )
        measureBP.instructions = "Measure your blood pressure and record the systolic/diastolic values."
        measureBP.asset = "heart.text.square"
        // 如果这里报错，就用 Xcode 自动补全选一个你项目里存在的 card case
        measureBP.card = .numericProgress
        measureBP.impactsAdherence = true

        var lowSodium = OCKTask(
            id: AppTaskID.lowSodiumCheck,
            title: "Low-Sodium Diet Check",
            carePlanUUID: nil,
            schedule: scheduleAnytime
        )
        lowSodium.instructions = "Did you follow a low-sodium diet today? Tap to log."
        lowSodium.asset = "fork.knife"
        lowSodium.card = .grid
        lowSodium.impactsAdherence = false

        var exercise = OCKTask(
            id: AppTaskID.exercise,
            title: "Hypertension Exercise Session",
            carePlanUUID: nil,
            schedule: scheduleExercise
        )
        exercise.instructions = "Walk briskly for 20 minutes or do light cardio."
        exercise.asset = "figure.walk"
        exercise.card = .button
        exercise.impactsAdherence = true

        _ = try await addTasksIfNotPresent(
            [
                medAM,
                medPM,
                measureBP,
                lowSodium,
                exercise
            ]
        )

        var todayQuery = OCKTaskQuery(for: today)
        todayQuery.excludesTasksWithNoEvents = false
        let todayTasks = try await fetchAnyTasks(query: todayQuery)
        Logger.ockStore.info("Hypertension seeding complete. Tasks available for today: \(todayTasks.count)")

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
}
