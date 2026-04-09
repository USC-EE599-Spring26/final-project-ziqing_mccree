//
//  Utility.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKit
import CareKitStore
import ParseCareKit
import ParseSwift
import os.log

// swiftlint:disable type_body_length
class Utility {

    static func defaultSeedStartDate(from currentDate: Date = Date()) -> Date {
        if daysInThePastToGenerateSampleData < 0 {
            return Calendar.current.date(
                byAdding: .day,
                value: daysInThePastToGenerateSampleData,
                to: currentDate
            ) ?? currentDate
        }
        return currentDate
    }

    static func convertNonSendableDictionaryToSendable(_ dictionary: [String: Any]) -> [String: String] {
		let sendableDictionary: [String: String] = dictionary.reduce(into: [:]) {
			$0[$1.key] = $1.value as? String
		}
		return sendableDictionary
	}

    static func prepareSyncMessageForWatch() -> [String: String] {
        var returnMessage = [String: String]()
        returnMessage[Constants.requestSync] = "new messages on Remote"
        return returnMessage
    }

    static func getUserSessionForWatch() async throws -> [String: String] {
        var returnMessage = [String: String]()
        returnMessage[Constants.parseUserSessionTokenKey] = try await User.sessionToken()
        return returnMessage
    }

    static func getRemoteClockUUID() async throws -> UUID {
        guard let user = try? await User.current(),
            let lastUserTypeSelected = user.lastTypeSelected,
            let remoteClockUUID = user.userTypeUUIDs?[lastUserTypeSelected] else {
            throw AppError.remoteClockIDNotAvailable
        }
        return remoteClockUUID
    }

    static func prepareRemoteClockForCurrentSeed() async throws -> (uuid: UUID, didRotateClock: Bool) {
        var user = try await User.current()
        guard let lastUserTypeSelected = user.lastTypeSelected else {
            throw AppError.remoteClockIDNotAvailable
        }

        let defaults = UserDefaults.standard
        let localSeedVersion = defaults.integer(forKey: Constants.hypertensionSeedVersionKey)

        if let existingUUID = user.userTypeUUIDs?[lastUserTypeSelected] {
            if user.hypertensionSeedVersion != Constants.hypertensionSeedVersion {
                user.hypertensionSeedVersion = Constants.hypertensionSeedVersion
                _ = try await user.save()
            }
            if localSeedVersion != Constants.hypertensionSeedVersion {
                defaults.set(
                    Constants.hypertensionSeedVersion,
                    forKey: Constants.hypertensionSeedVersionKey
                )
            }
            return (existingUUID, false)
        }

        let newUUID = UUID()
        if user.userTypeUUIDs == nil {
            user.userTypeUUIDs = [lastUserTypeSelected: newUUID]
        } else {
            user.userTypeUUIDs?[lastUserTypeSelected] = newUUID
        }
        user.hypertensionSeedVersion = Constants.hypertensionSeedVersion
        _ = try await user.save()
        defaults.set(
            Constants.hypertensionSeedVersion,
            forKey: Constants.hypertensionSeedVersionKey
        )
        return (newUUID, true)
    }

    @MainActor
    static func resetStoresForHypertensionSeedRotation() {
        AppDelegateKey.defaultValue?.resetAppToInitialState()

        #if os(watchOS)
        let parseStore = OCKStore(
            name: Constants.watchOSParseCareStoreName,
            type: .onDisk()
        )
        #else
        let parseStore = OCKStore(
            name: Constants.iOSParseCareStoreName,
            type: .onDisk()
        )
        #endif

        do {
            try parseStore.delete()
        } catch {
            Logger.utility.error("Could not reset parse store for seed rotation: \(error)")
        }

        PCKUtility.removeCache()
    }

    static func setDefaultACL() async throws {
        var defaultACL = ParseACL()
        defaultACL.publicRead = false
        defaultACL.publicWrite = false
        _ = try await ParseACL.setDefaultACL(defaultACL, withAccessForCurrentUser: true)
    }

    @MainActor
    static func setupRemoteAfterLogin() async throws {
        let remoteClock = try await Utility.prepareRemoteClockForCurrentSeed()
        do {
            try await setDefaultACL()
        } catch {
            Logger.utility.error("Could not set defaultACL: \(error)")
        }

        guard let appDelegate = AppDelegateKey.defaultValue else {
            Logger.utility.error("Could not setup remotes, AppDelegate is nil")
            return
        }
        if remoteClock.didRotateClock {
            resetStoresForHypertensionSeedRotation()
        }
        try await appDelegate.setupRemotes(uuid: remoteClock.uuid)
        if remoteClock.didRotateClock {
            try await seedHypertensionDataInCurrentStores()
        }
        appDelegate.parseRemote.automaticallySynchronizes = true
        return
    }

    @MainActor
    static func seedHypertensionDataInCurrentStores(
        currentDate: Date = Date()
    ) async throws {
        guard let appDelegate = AppDelegateKey.defaultValue,
              let store = appDelegate.store,
              store.name != Constants.noCareStoreName else {
            return
        }

        let startDate = defaultSeedStartDate(from: currentDate)
        UserDefaults.standard.set(false, forKey: Constants.onboardingCompletedKey)
        UserDefaults.standard.set(
            Constants.hypertensionSeedVersion,
            forKey: Constants.hypertensionSeedVersionKey
        )
        try await store.populateDefaultCarePlansTasksContacts(startDate: startDate)
        #if os(iOS) || os(visionOS)
        guard let healthKitStore = appDelegate.healthKitStore else {
            return
        }
        try await healthKitStore.populateDefaultHealthKitTasks(startDate: startDate)
        #endif
        if startDate < currentDate {
            try await store.populateSampleOutcomes(startDate: startDate)
        }
    }

    static func updateInstallationWithDeviceToken(_ deviceToken: Data? = nil) async {
        guard let keychainInstallation = try? await Installation.current() else {
            Logger.utility.debug("""
                Attempted to update installation,
                but no current installation is available
            """)
            return
        }
        var isUpdatingInstallationMutable = true
        var currentInstallation = Installation()
        if keychainInstallation.objectId != nil {
            currentInstallation = keychainInstallation.mergeable
            if let deviceToken = deviceToken {
                currentInstallation.setDeviceToken(deviceToken)
            }
        } else {
            currentInstallation = keychainInstallation
            currentInstallation.user = try? await User.current()
            currentInstallation.channels = [InstallationChannel.global.rawValue]
            isUpdatingInstallationMutable = false
        }
        let installation = currentInstallation
        let isUpdatingInstallation = isUpdatingInstallationMutable
		do {
			if isUpdatingInstallation {
				let updatedInstallation = try await installation.save()
				Logger.utility.info("""
					Updated installation: \(updatedInstallation, privacy: .private)
				""")
			} else {
				let updatedInstallation = try await installation.create()
				Logger.utility.info("""
					Created installation: \(updatedInstallation, privacy: .private)
				""")
			}
		} catch {
			Logger.utility.error("""
				Could not update installation: \(error)
			""")
		}
    }

    static func createPreviewStore() -> OCKStore {
        let store = OCKStore(name: Constants.noCareStoreName, type: .inMemory)
        let patientId = "preview"
        Task {
            do {
                // If patient exists, assume store is already populated
                _ = try await store.fetchPatient(withID: patientId)
            } catch {
                var patient = OCKPatient(
					id: patientId,
					givenName: "Preview",
					familyName: "Patient"
				)
                patient.birthday = Calendar.current.date(
					byAdding: .year,
					value: -20,
					to: Date()
				)
                _ = try? await store.addPatient(patient)
				let startDate = Calendar.current.date(
					byAdding: .day,
					value: -30,
					to: Date()
				)!
                try? await store.populateDefaultCarePlansTasksContacts(
					startDate: startDate
				)
				try? await store.populateSampleOutcomes(
					startDate: startDate
				)
            }
        }
        return store
    }

    static func clearDeviceOnFirstRun(storeName: String? = nil) async {
        // Clear items out of the Keychain on app first run.
        if UserDefaults.standard.object(forKey: Constants.appName) == nil {

            if let storeName = storeName {
                let store = OCKStore(name: storeName, type: .onDisk())
                do {
                    try store.delete()
                } catch {
                    Logger.utility.error("""
                        Could not delete OCKStore with name \"\(storeName)\" because of error: \(error)
                    """)
                }
            } else {
                let localStore: OCKStore!
                let parseStore: OCKStore!

                #if os(watchOS)
                localStore = OCKStore(name: Constants.watchOSLocalCareStoreName,
                                      type: .onDisk())
                parseStore = OCKStore(name: Constants.watchOSParseCareStoreName,
                                      type: .onDisk())
                #else
                localStore = OCKStore(name: Constants.iOSLocalCareStoreName,
                                      type: .onDisk())
                parseStore = OCKStore(name: Constants.iOSParseCareStoreName,
                                      type: .onDisk())
                #endif

                do {
                    try localStore.delete()
                } catch {
                    Logger.utility.error("Could not delete local OCKStore because of error: \(error)")
                }
                do {
                    try parseStore.delete()
                } catch {
                    Logger.utility.error("Could not delete parse OCKStore because of error: \(error)")
                }
            }

            // This is no longer the first run
            UserDefaults.standard.setValue(String(Constants.appName),
                                           forKey: Constants.appName)
            UserDefaults.standard.synchronize()
            if isSyncingWithRemote {
                try? await User.logout()
            }
        }
    }

	@MainActor
	static func logoutAndResetAppState() async {
		do {
			try await User.logout()
		} catch {
			Logger.utility.error("Error logging out: \(error)")
		}
		AppDelegateKey.defaultValue?.resetAppToInitialState()
		PCKUtility.removeCache()
	}

    @MainActor
    class func checkIfOnboardingIsComplete() async -> Bool {
        UserDefaults.standard.bool(forKey: Constants.onboardingCompletedKey)
    }

    @MainActor
    static func migrateHypertensionTasksIfNeeded() async {
        guard let appDelegate = AppDelegateKey.defaultValue,
              let store = appDelegate.store,
              store.name != Constants.noCareStoreName else {
            return
        }

        let defaults = UserDefaults.standard

        let currentTaskIDs = [
            TaskID.onboarding,
            AppTaskID.medicationChecklist,
            AppTaskID.bpMeasurement,
            AppTaskID.symptomsCheck,
            AppTaskID.morningPrep,
            AppTaskID.lowSodiumCheck,
            AppTaskID.walkAssessment
        ]
        let legacyTaskIDs = [
            TaskID.legacyOnboarding,
            AppTaskID.reflection,
            AppTaskID.bpMedicationAM,
            AppTaskID.bpMedicationPM,
            AppTaskID.exercise,
            AppTaskID.rangeOfMotion,
            AppTaskID.legacyEducation,
            AppTaskID.legacyReflectionSurvey,
            AppTaskID.legacyQualityOfLife,
            AppTaskID.legacyWalkAssessment
        ]
        do {
            var taskQuery = OCKTaskQuery()
            taskQuery.ids = Array(Set(currentTaskIDs + legacyTaskIDs))
            let tasks = try await store.fetchTasks(query: taskQuery)
            let taskIDs = Set(tasks.map(\.id))
            let hasCurrentTasks = currentTaskIDs.allSatisfy(taskIDs.contains)
            let hasCurrentMeasurementSurvey = tasks.contains { task in
                task.id == AppTaskID.bpMeasurement
                    && task.card == .survey
                    && (task.instructions?.contains("systolic and diastolic") ?? false)
            }
            let hasLegacyTasks = legacyTaskIDs.contains(where: taskIDs.contains)
            let hasDuplicateTaskVersions = tasks.count > taskIDs.count

            #if os(iOS) || os(visionOS)
            guard let healthKitStore = appDelegate.healthKitStore else {
                return
            }
            let currentHealthKitTaskIDs = [
                AppTaskID.heartRate,
                AppTaskID.restingHeartRate
            ]
            let legacyHealthKitTaskIDs = [
                TaskID.steps,
                TaskID.ovulationTestResult,
                AppTaskID.legacyHeartRate,
                AppTaskID.legacyRestingHeartRate,
                AppTaskID.legacyActiveEnergy
            ]

            var healthKitQuery = OCKTaskQuery()
            healthKitQuery.ids = Array(Set(currentHealthKitTaskIDs + legacyHealthKitTaskIDs))
            let healthKitTasks = try await healthKitStore.fetchTasks(query: healthKitQuery)
            let healthKitIDs = Set(healthKitTasks.map(\.id))

            let hasCurrentHealthKitTasks = currentHealthKitTaskIDs.allSatisfy(healthKitIDs.contains)
            let hasLegacyHealthKitTasks = legacyHealthKitTaskIDs.contains(where: healthKitIDs.contains)
            let hasDuplicateHealthKitTaskVersions = healthKitTasks.count > healthKitIDs.count
            #else
            let hasCurrentHealthKitTasks = true
            let hasLegacyHealthKitTasks = false
            let hasDuplicateHealthKitTaskVersions = false
            #endif

            let needsSeedVersionUpdate =
                defaults.integer(forKey: Constants.hypertensionSeedVersionKey)
                != Constants.hypertensionSeedVersion

            let hasDirtySeededTasks =
                hasLegacyTasks
                || hasLegacyHealthKitTasks
                || hasDuplicateTaskVersions
                || hasDuplicateHealthKitTaskVersions
                || !hasCurrentMeasurementSurvey

            guard needsSeedVersionUpdate
                    || !hasCurrentTasks
                    || !hasCurrentHealthKitTasks
                    || hasDirtySeededTasks else {
                return
            }

            let onboardingWasComplete = await checkIfOnboardingIsComplete()
            let seedStartDate = hasDirtySeededTasks ? Date() : defaultSeedStartDate()

            try await store.populateDefaultCarePlansTasksContacts(
                startDate: seedStartDate,
                preserveHistoricalWindow: !hasDirtySeededTasks
            )
            #if os(iOS) || os(visionOS)
            try await healthKitStore.populateDefaultHealthKitTasks(startDate: seedStartDate)
            #endif

            if onboardingWasComplete {
                try await markCurrentOnboardingCompleteIfNeeded(in: store)
                defaults.set(true, forKey: Constants.onboardingCompletedKey)
            }

            defaults.set(
                Constants.hypertensionSeedVersion,
                forKey: Constants.hypertensionSeedVersionKey
            )

            NotificationCenter.default.post(
                .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
            )
        } catch {
            Logger.utility.error("Could not migrate hypertension tasks: \(error)")
        }
    }

    @MainActor
    private static func markCurrentOnboardingCompleteIfNeeded(
        in store: OCKStore
    ) async throws {
        var query = OCKEventQuery(for: Date())
        query.taskIDs = [TaskID.onboarding]

        let events = try await store.fetchEvents(query: query)
        guard let event = events.first, event.outcome == nil else {
            return
        }

        let outcome = OCKOutcome(
            taskUUID: event.task.uuid,
            taskOccurrenceIndex: event.scheduleEvent.occurrence,
            values: [OCKOutcomeValue(Date())]
        )
        _ = try await store.addOutcomes([outcome])
    }

    #if os(iOS) || os(visionOS)
	@MainActor
	static func requestHealthKitPermissions() {
		UserDefaults.standard.set(true, forKey: Constants.healthPermissionsRequestedKey)
		AppDelegateKey.defaultValue?.healthKitStore.requestHealthKitPermissionsForAllTasksInStore { error in
	            guard let error = error else {
	                DispatchQueue.main.async {
	                    // swiftlint:disable:next line_length
                    NotificationCenter.default.post(.init(name: Notification.Name(rawValue: Constants.finishedAskingForPermission)))
                }
                return
            }
            Logger.utility.error("Error requesting HealthKit permissions: \(error)")
        }
    }
    #endif
}
// swiftlint:enable type_body_length
