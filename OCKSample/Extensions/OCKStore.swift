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
import ResearchKitSwiftUI
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
        doxylamine.card = .instruction
        doxylamine.priority = 2

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
        nausea.card = .button
        nausea.priority = 5

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
        kegels.card = .instruction
        kegels.priority = 3

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
        stretch.card= .simple
        stretch.priority = 4
        let qualityOfLife = createQualityOfLifeSurveyTask(carePlanUUID: nil)
        
        
        _ = try await addTasksIfNotPresent(
            [
                nausea,
                doxylamine,
                kegels,
                stretch,
                qualityOfLife
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

        let medicationCheckinSurvey = createMedicationCheckinSurveyTask(carePlanUUID: nil)
        let symptomsSurvey = createSymptomsSurveyTask(carePlanUUID: nil)
        let lifestyleSurvey = createLifestyleSurveyTask(carePlanUUID: nil)

        _ = try await addTasksIfNotPresent(
            [
                medAM,
                medPM,
                measureBP,
                lowSodium,
                exercise,
                medicationCheckinSurvey,
                symptomsSurvey,
                lifestyleSurvey
            ]
        )

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
    func createQualityOfLifeSurveyTask(carePlanUUID: UUID?) -> OCKTask {
            let qualityOfLifeTaskId = TaskID.qualityOfLife
            let thisMorning = Calendar.current.startOfDay(for: Date())
            let aFewDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: thisMorning)!
            let beforeBreakfast = Calendar.current.date(byAdding: .hour, value: 8, to: aFewDaysAgo)!
            let qualityOfLifeElement = OCKScheduleElement(
                start: beforeBreakfast,
                end: nil,
                interval: DateComponents(day: 1)
            )
            let qualityOfLifeSchedule = OCKSchedule(
                composing: [qualityOfLifeElement]
            )
            let textChoiceYesText = String(localized: "ANSWER_YES")
            let textChoiceNoText = String(localized: "ANSWER_NO")
            let yesValue = "Yes"
            let noValue = "No"
            let choices: [TextChoice] = [
                .init(
                    id: "\(qualityOfLifeTaskId)_0",
                    choiceText: textChoiceYesText,
                    value: yesValue
                ),
                .init(
                    id: "\(qualityOfLifeTaskId)_1",
                    choiceText: textChoiceNoText,
                    value: noValue
                )

            ]
            let questionOne = SurveyQuestion(
                id: "\(qualityOfLifeTaskId)-managing-time",
                type: .multipleChoice,
                required: true,
                title: String(localized: "QUALITY_OF_LIFE_TIME"),
                textChoices: choices,
                choiceSelectionLimit: .single
            )
            let questionTwo = SurveyQuestion(
                id: qualityOfLifeTaskId,
                type: .slider,
                required: false,
                title: String(localized: "QUALITY_OF_LIFE_STRESS"),
                detail: String(localized: "QUALITY_OF_LIFE_STRESS_DETAIL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )
            let questions = [questionOne, questionTwo]
            let stepOne = SurveyStep(
                id: "\(qualityOfLifeTaskId)-step-1",
                questions: questions
            )
            var qualityOfLife = OCKTask(
                id: "\(qualityOfLifeTaskId)-stress",
                title: String(localized: "QUALITY_OF_LIFE"),
                carePlanUUID: carePlanUUID,
                schedule: qualityOfLifeSchedule
            )
            qualityOfLife.impactsAdherence = true
            qualityOfLife.asset = "brain.head.profile"
            qualityOfLife.card = .survey
            qualityOfLife.surveySteps = [stepOne]
            qualityOfLife.priority = 1

            return qualityOfLife
        }

    func createMedicationCheckinSurveyTask(carePlanUUID: UUID?) -> OCKTask {
        let taskID = AppTaskID.bpMedicationCheckinSurvey
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: startOfToday) ?? startOfToday

        let schedule = OCKSchedule(composing: [
            OCKScheduleElement(
                start: startDate,
                end: nil,
                interval: DateComponents(day: 1),
                text: "Complete before bedtime",
                targetValues: [],
                duration: .allDay
            )
        ])

        let adherenceChoices: [TextChoice] = [
            .init(id: "\(taskID)-adherence-0", choiceText: "Yes, all doses", value: "all"),
            .init(id: "\(taskID)-adherence-1", choiceText: "Missed 1 dose", value: "missed_one"),
            .init(id: "\(taskID)-adherence-2", choiceText: "Missed 2+ doses", value: "missed_multiple")
        ]
        let sideEffectChoices: [TextChoice] = [
            .init(id: "\(taskID)-effect-0", choiceText: "None", value: "none"),
            .init(id: "\(taskID)-effect-1", choiceText: "Mild", value: "mild"),
            .init(id: "\(taskID)-effect-2", choiceText: "Moderate", value: "moderate"),
            .init(id: "\(taskID)-effect-3", choiceText: "Severe", value: "severe")
        ]

        let adherenceQuestion = SurveyQuestion(
            id: "\(taskID)-adherence",
            type: .multipleChoice,
            required: true,
            title: "Did you take your blood pressure medicine as prescribed today?",
            textChoices: adherenceChoices,
            choiceSelectionLimit: .single
        )
        let sideEffectsQuestion = SurveyQuestion(
            id: "\(taskID)-side-effects",
            type: .multipleChoice,
            required: true,
            title: "Any medication side effects today?",
            textChoices: sideEffectChoices,
            choiceSelectionLimit: .single
        )
        let confidenceQuestion = SurveyQuestion(
            id: "\(taskID)-confidence",
            type: .slider,
            required: false,
            title: "How confident are you about following tomorrow's medication plan?",
            detail: "0 = not confident, 10 = very confident",
            integerRange: 0...10,
            sliderStepValue: 1
        )

        let step = SurveyStep(
            id: "\(taskID)-step-1",
            questions: [adherenceQuestion, sideEffectsQuestion, confidenceQuestion]
        )

        var task = OCKTask(
            id: taskID,
            title: "Medication Check-In Survey",
            carePlanUUID: carePlanUUID,
            schedule: schedule
        )
        task.instructions = "Daily medication adherence and side effect check-in."
        task.asset = "pills.circle"
        task.card = .survey
        task.surveySteps = [step]
        task.impactsAdherence = true
        return task
    }

    func createSymptomsSurveyTask(carePlanUUID: UUID?) -> OCKTask {
        let taskID = AppTaskID.bpSymptomsSurvey
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: startOfToday) ?? startOfToday

        let schedule = OCKSchedule(composing: [
            OCKScheduleElement(
                start: startDate,
                end: nil,
                interval: DateComponents(day: 1),
                text: "Record evening symptoms",
                targetValues: [],
                duration: .allDay
            )
        ])

        let headacheQuestion = SurveyQuestion(
            id: "\(taskID)-headache",
            type: .slider,
            required: true,
            title: "How severe was your headache today?",
            detail: "0 = none, 10 = severe",
            integerRange: 0...10,
            sliderStepValue: 1
        )
        let dizzinessQuestion = SurveyQuestion(
            id: "\(taskID)-dizziness",
            type: .slider,
            required: true,
            title: "How severe was your dizziness today?",
            detail: "0 = none, 10 = severe",
            integerRange: 0...10,
            sliderStepValue: 1
        )
        let chestPainChoices: [TextChoice] = [
            .init(id: "\(taskID)-chest-0", choiceText: "No", value: "no"),
            .init(id: "\(taskID)-chest-1", choiceText: "Yes", value: "yes")
        ]
        let chestPainQuestion = SurveyQuestion(
            id: "\(taskID)-chest-pain",
            type: .multipleChoice,
            required: true,
            title: "Did you experience chest discomfort or shortness of breath?",
            textChoices: chestPainChoices,
            choiceSelectionLimit: .single
        )

        let step = SurveyStep(
            id: "\(taskID)-step-1",
            questions: [headacheQuestion, dizzinessQuestion, chestPainQuestion]
        )

        var task = OCKTask(
            id: taskID,
            title: "Blood Pressure Symptom Survey",
            carePlanUUID: carePlanUUID,
            schedule: schedule
        )
        task.instructions = "Track key symptoms to support treatment adjustments."
        task.asset = "heart.text.square"
        task.card = .survey
        task.surveySteps = [step]
        task.impactsAdherence = true
        return task
    }

    func createLifestyleSurveyTask(carePlanUUID: UUID?) -> OCKTask {
        let taskID = AppTaskID.bpLifestyleSurvey
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: startOfToday) ?? startOfToday

        let schedule = OCKSchedule(composing: [
            OCKScheduleElement(
                start: startDate,
                end: nil,
                interval: DateComponents(day: 1),
                text: "End-of-day lifestyle review",
                targetValues: [],
                duration: .allDay
            )
        ])

        let sodiumChoices: [TextChoice] = [
            .init(id: "\(taskID)-sodium-0", choiceText: "Low sodium most of the day", value: "good"),
            .init(id: "\(taskID)-sodium-1", choiceText: "Some high-sodium meals", value: "mixed"),
            .init(id: "\(taskID)-sodium-2", choiceText: "Mostly high-sodium food", value: "high")
        ]
        let activityQuestion = SurveyQuestion(
            id: "\(taskID)-activity-minutes",
            type: .slider,
            required: false,
            title: "How many minutes of activity did you complete today?",
            detail: "Move the slider to nearest 10 minutes",
            integerRange: 0...120,
            sliderStepValue: 10
        )
        let stressQuestion = SurveyQuestion(
            id: "\(taskID)-stress",
            type: .slider,
            required: true,
            title: "How stressed did you feel today?",
            detail: "0 = calm, 10 = very stressed",
            integerRange: 0...10,
            sliderStepValue: 1
        )
        let sodiumQuestion = SurveyQuestion(
            id: "\(taskID)-sodium",
            type: .multipleChoice,
            required: true,
            title: "How well did you follow a low-sodium plan today?",
            textChoices: sodiumChoices,
            choiceSelectionLimit: .single
        )

        let step = SurveyStep(
            id: "\(taskID)-step-1",
            questions: [activityQuestion, stressQuestion, sodiumQuestion]
        )

        var task = OCKTask(
            id: taskID,
            title: "Lifestyle & Stress Survey",
            carePlanUUID: carePlanUUID,
            schedule: schedule
        )
        task.instructions = "Capture daily activity, stress, and dietary pattern."
        task.asset = "figure.walk.circle"
        task.card = .survey
        task.surveySteps = [step]
        task.impactsAdherence = false
        return task
    }

    func persistLatestSurveySummariesToCurrentUser() async {
        do {
            var user = try await User.current()
            let rangeStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let interval = DateInterval(start: rangeStart, end: Date())
            var eventQuery = OCKEventQuery(dateInterval: interval)
            eventQuery.taskIDs = AppTaskID.surveyTaskIDs

            let events = try await fetchEvents(query: eventQuery)
            var latestByTaskID: [String: (date: Date, summary: String)] = [:]

            for event in events {
                guard let outcome = event.outcome, !outcome.values.isEmpty else {
                    continue
                }
                let valueSummary = outcome.values
                    .map { String(describing: $0) }
                    .joined(separator: " | ")
                let effectiveDate = outcome.effectiveDate
                let summary = "\(effectiveDate.ISO8601Format()): \(valueSummary)"

                if let existing = latestByTaskID[event.task.id] {
                    if effectiveDate > existing.date {
                        latestByTaskID[event.task.id] = (effectiveDate, summary)
                    }
                } else {
                    latestByTaskID[event.task.id] = (effectiveDate, summary)
                }
            }

            var summaries = latestByTaskID.mapValues(\.summary)
            let riskLevel = computeRiskLevel(from: summaries)
            summaries["bpRiskLevel"] = riskLevel.rawValue
            summaries["bpPlanRecommendation"] = recommendationText(for: riskLevel)
            summaries["bpRiskUpdatedAt"] = Date().ISO8601Format()

            user.surveyResponseSummaries = summaries
            _ = try await user.save()
        } catch {
            Logger.ockStore.error("Failed persisting survey summaries to user: \(error)")
        }
    }

    private func computeRiskLevel(from summaries: [String: String]) -> HypertensionRiskLevel {
        let text = summaries
            .values
            .joined(separator: " ")
            .lowercased()

        var score = 0
        score += scoreIfContains(text, anyOf: ["missed_multiple"], points: 4)
        score += scoreIfContains(text, anyOf: ["missed_one"], points: 2)
        score += scoreIfContains(text, anyOf: ["severe"], points: 3)
        score += scoreIfContains(text, anyOf: ["moderate"], points: 2)
        score += scoreIfContains(text, anyOf: ["chest", "shortness of breath", "\"yes\""], points: 2)
        score += scoreIfContains(text, anyOf: ["high-sodium", "\"high\""], points: 1)

        if score >= 6 {
            return .red
        }
        if score >= 3 {
            return .yellow
        }
        return .green
    }

    private func scoreIfContains(_ text: String, anyOf candidates: [String], points: Int) -> Int {
        candidates.contains(where: { text.contains($0) }) ? points : 0
    }

    private func recommendationText(for level: HypertensionRiskLevel) -> String {
        switch level {
        case .green:
            return "Continue current medication and monitoring plan."
        case .yellow:
            return "Reinforce medication reminders, review sodium intake, and monitor symptoms closely."
        case .red:
            return "Escalate follow-up: prioritize medication adherence, daily BP checks, and contact care team."
        }
    }
}

enum HypertensionRiskLevel: String {
    case green
    case yellow
    case red
}
