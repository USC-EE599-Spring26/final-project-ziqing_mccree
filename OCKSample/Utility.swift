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

        if let existingUUID = user.userTypeUUIDs?[lastUserTypeSelected] {
            return (existingUUID, false)
        }

        let newUUID = UUID()
        if user.userTypeUUIDs == nil {
            user.userTypeUUIDs = [lastUserTypeSelected: newUUID]
        } else {
            user.userTypeUUIDs?[lastUserTypeSelected] = newUUID
        }
        _ = try await user.save()
        return (newUUID, true)
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
        try await appDelegate.setupRemotes(uuid: remoteClock.uuid)
        if remoteClock.didRotateClock {
            try await seedHypertensionDataInCurrentStores()
        }
        appDelegate.parseRemote.automaticallySynchronizes = true
        return
    }

    @MainActor
    static func synchronizeStoreIfRemoteEnabled() {
        guard isSyncingWithRemote,
              let store = AppDelegateKey.defaultValue?.store else {
            return
        }

        store.synchronize { error in
            let errorString = error?.localizedDescription ?? "Successful sync with remote!"
            Logger.utility.info("\(errorString)")
        }
    }

    @MainActor
    private static func synchronizeStoreIfRemoteEnabledAndWait() async -> Bool {
        guard isSyncingWithRemote,
              let store = AppDelegateKey.defaultValue?.store else {
            return true
        }

        return await withCheckedContinuation { continuation in
            store.synchronize { error in
                let errorString = error?.localizedDescription ?? "Successful sync with remote!"
                Logger.utility.info("\(errorString)")
                continuation.resume(returning: error == nil)
            }
        }
    }

    @MainActor
    static func synchronizeStoreIfPossible() {
        synchronizeStoreIfRemoteEnabled()
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
        var query = OCKOutcomeQuery()
        query.taskIDs = TaskID.onboardingIDs

        guard let store = AppDelegateKey.defaultValue?.store else {
            Logger.utility.error("CareKit store could not be unwrapped")
            return false
        }

        do {
            let outcomes = try await store.fetchAnyOutcomes(query: query)
            return !outcomes.isEmpty
        } catch {
            Logger.utility.error("Could not fetch onboarding outcomes: \(error)")
            return false
        }
    }

    @MainActor
    static func migrateHypertensionTasksIfNeeded() async {
        guard let appDelegate = AppDelegateKey.defaultValue,
              let store = appDelegate.store,
              store.name != Constants.noCareStoreName else {
            return
        }

        do {
            let didSync = await synchronizeStoreIfRemoteEnabledAndWait()
            // 我这里保留老师项目的 populate 方式；弱网时只加一个保护：
            // 老用户如果同步失败且本地完全没有 CareKit 数据，先不 seed，避免离线重装造出第二套默认任务。
            if isSyncingWithRemote,
               !didSync,
               !(try await localStoreHasSeedableData(store)) {
                Logger.utility.info("Skipping seed because remote sync failed and local store is empty.")
                return
            }

            let onboardingWasComplete = await checkIfOnboardingIsComplete()
            let seedStartDate = defaultSeedStartDate()

            try await store.populateDefaultCarePlansTasksContacts(
                startDate: seedStartDate,
                preserveHistoricalWindow: true
            )
            #if os(iOS) || os(visionOS)
            guard let healthKitStore = appDelegate.healthKitStore else {
                return
            }
            try await healthKitStore.populateDefaultHealthKitTasks(startDate: seedStartDate)
            #endif

            if onboardingWasComplete {
                try await markCurrentOnboardingCompleteIfNeeded(in: store)
                UserDefaults.standard.set(true, forKey: Constants.onboardingCompletedKey)
            }

            NotificationCenter.default.post(
                .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
            )
            _ = await synchronizeStoreIfRemoteEnabledAndWait()
        } catch {
            Logger.utility.error("Could not migrate hypertension tasks: \(error)")
        }
    }

    @MainActor
    private static func localStoreHasSeedableData(_ store: OCKStore) async throws -> Bool {
        var query = OCKTaskQuery()
        query.excludesTasksWithNoEvents = false
        let tasks = try await store.fetchAnyTasks(query: query)
        return !tasks.isEmpty
    }

    @MainActor
    private static func markCurrentOnboardingCompleteIfNeeded(
        in store: OCKStore
    ) async throws {
        var query = OCKEventQuery(for: Date())
        query.taskIDs = TaskID.onboardingIDs

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
