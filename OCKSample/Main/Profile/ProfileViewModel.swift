//
//  Profile.swift
//  OCKSample
//
//  Created by Corey Baker on 11/25/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitEssentials
import CareKitStore
import ParseSwift
import SwiftUI
import os.log
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ProfileViewModel: ObservableObject { // swiftlint:disable:this type_body_length

    @Published var firstName = ""
    @Published var lastName = ""
    @Published var birthday = Date()
    @Published var allergies = ""
    @Published var street = ""
    @Published var city = ""
    @Published var state = ""
    @Published var zipcode = ""
    @Published var country = ""
    @Published var emailAddress = ""
    @Published var messagingNumber = ""
    @Published var phoneNumber = ""
    @Published var otherContactInfo = ""
    @Published var isShowingSaveAlert = false
    @Published var isPresentingAddTask = false
    @Published var isPresentingContact = false
    @Published var isPresentingImagePicker = false
    @Published private(set) var error: Error?
#if canImport(UIKit)
    @Published var profileUIImage = UIImage(systemName: "person.fill") {
        didSet {
            guard !isSettingProfilePictureForFirstTime else {
                return
            }
            hasPendingProfilePictureSave = true
        }
    }
#endif
    private(set) var alertMessage = "All changes saved successfully!"

    private var contact: OCKContact?
    private var isSettingProfilePictureForFirstTime = true
    private var hasPendingProfilePictureSave = false
    private var profilePictureVerificationMessage = ""

    var patient: OCKPatient? {
        willSet {
            firstName = newValue?.name.givenName ?? ""
            lastName = newValue?.name.familyName ?? ""
            birthday = newValue?.birthday ?? Date()
            allergies = newValue?.allergies?.first ?? ""
        }
    }

    func updatePatient(_ patient: OCKAnyPatient) {
        guard let patient = patient as? OCKPatient,
              patient.uuid != self.patient?.uuid else {
            return
        }
        self.patient = patient

#if canImport(UIKit)
        Task {
            do {
                try await fetchProfilePicture()
            } catch {
                Logger.profile.error("Failed to fetch profile picture: \(error.localizedDescription)")
            }
        }
#endif
    }

    func updateContact(_ contact: OCKAnyContact) {
        guard let currentPatient = self.patient,
              let contact = contact as? OCKContact,
              contact.id == currentPatient.id,
              contact.uuid != self.contact?.uuid else {
            return
        }
        self.contact = contact
        street = contact.address?.street ?? ""
        city = contact.address?.city ?? ""
        state = contact.address?.state ?? ""
        zipcode = contact.address?.postalCode ?? ""
        country = contact.address?.country ?? ""
        emailAddress = contact.emailAddresses?.first?.value ?? ""
        messagingNumber = contact.messagingNumbers?.first?.value ?? ""
        phoneNumber = contact.phoneNumbers?.first?.value ?? ""
        otherContactInfo = contact.otherContactInfo?.first?.value ?? ""
    }

#if canImport(UIKit)
    private func fetchProfilePicture() async throws {
        guard let currentUser = try? await User.current().fetch() else {
            Logger.profile.error("User is not logged in")
            hasPendingProfilePictureSave = false
            isSettingProfilePictureForFirstTime = false
            return
        }

        if let pictureFile = currentUser.profilePicture {
            do {
                let profilePicture = try await pictureFile.fetch()
                guard let path = profilePicture.localURL?.relativePath else {
                    Logger.profile.error("Could not find relative path for profile picture.")
                    hasPendingProfilePictureSave = false
                    isSettingProfilePictureForFirstTime = false
                    return
                }
                profileUIImage = UIImage(contentsOfFile: path)
            } catch {
                Logger.profile.error("Could not fetch profile picture: \(error.localizedDescription).")
            }
        }
        hasPendingProfilePictureSave = false
        isSettingProfilePictureForFirstTime = false
    }
#endif

    func saveProfile() async {
        alertMessage = "All changes saved successfully!"
        do {
#if canImport(UIKit)
            try await saveProfilePictureIfNeeded()
#endif
            try await savePatient()
            try await saveContact()
        } catch {
            alertMessage = "Could not save profile: \(error)"
            isShowingSaveAlert = true
            return
        }

        Utility.synchronizeStoreIfRemoteEnabled()
        if !profilePictureVerificationMessage.isEmpty {
            alertMessage += "\n\(profilePictureVerificationMessage)"
        }
        isShowingSaveAlert = true
    }

#if canImport(UIKit)
    private func saveProfilePictureIfNeeded() async throws {
        guard hasPendingProfilePictureSave else {
            return
        }

        guard var currentUser = try? await User.current() else {
            Logger.profile.error("User is not logged in")
            throw AppError.errorString("The user currently is not logged in")
        }

        guard let inputImage = profileUIImage,
              let imageData = inputImage.jpegData(compressionQuality: 0.25) else {
            Logger.profile.error("Could not compress profile picture.")
            throw AppError.errorString("Could not prepare profile picture for upload")
        }

        let uploadedProfilePicture = try await ParseFile(
            name: "profile-\(UUID().uuidString).jpg",
            data: imageData,
            mimeType: "image/jpeg"
        ).save()

        currentUser = currentUser.mergeable
        currentUser = currentUser.set(\.profilePicture, to: uploadedProfilePicture)
        let savedUser = try await currentUser.save()
        let refreshedUser = try await savedUser.fetch(includeKeys: ["profilePicture"])

        guard refreshedUser.profilePicture?.name == uploadedProfilePicture.name else {
            Logger.profile.error("Profile picture save could not be verified on _User.")
            throw AppError.errorString("Could not verify profile picture on Parse user")
        }

        hasPendingProfilePictureSave = false
        profilePictureVerificationMessage =
            """
            Verified _User.objectId: \(refreshedUser.objectId ?? "unknown"), \
            profilePicture: \(uploadedProfilePicture.name)
            """
        Logger.profile.info(
            """
            Saved updated profile picture successfully. \
            name=\(refreshedUser.profilePicture?.name ?? "nil"), \
            url=\(refreshedUser.profilePicture?.url?.absoluteString ?? "nil")
            """
        )
    }
#endif

    func savePatient() async throws {
        if var patientToUpdate = patient {
            var patientHasBeenUpdated = false

            if patient?.name.givenName != firstName {
                patientHasBeenUpdated = true
                patientToUpdate.name.givenName = firstName
            }

            if patient?.name.familyName != lastName {
                patientHasBeenUpdated = true
                patientToUpdate.name.familyName = lastName
            }

            if patient?.birthday != birthday {
                patientHasBeenUpdated = true
                patientToUpdate.birthday = birthday
            }

            let updatedAllergies = singleStringArray(allergies)
            if patient?.allergies != updatedAllergies {
                patientHasBeenUpdated = true
                patientToUpdate.allergies = updatedAllergies
            }

            if patientHasBeenUpdated,
               let anyPatient = try await AppDelegateKey.defaultValue?.store.updateAnyPatient(patientToUpdate),
               let updatedPatient = anyPatient as? OCKPatient {
                self.patient = updatedPatient
                Logger.profile.info("Successfully updated patient")
            }

        } else {
            guard let remoteUUID = (try? await Utility.getRemoteClockUUID())?.uuidString else {
                Logger.profile.error("The user currently is not logged in")
                throw AppError.errorString("The user currently is not logged in")
            }

            var newPatient = OCKPatient(
                id: remoteUUID,
                givenName: firstName,
                familyName: lastName
            )
            newPatient.birthday = birthday
            newPatient.allergies = singleStringArray(allergies)

            if let anyPatient = try await AppDelegateKey.defaultValue?.store.addAnyPatient(newPatient),
               let savedPatient = anyPatient as? OCKPatient {
                patient = savedPatient
            }
            Logger.profile.info("Succesffully saved new patient")
        }
    }

    func saveContact() async throws {
        let potentialAddress = OCKPostalAddress(
            street: street,
            city: city,
            state: state,
            postalCode: zipcode,
            country: country
        )
        let potentialEmail = singleLabeledValue(emailAddress, label: "email")
        let potentialMessaging = singleLabeledValue(messagingNumber, label: "message")
        let potentialPhone = singleLabeledValue(phoneNumber, label: "phone")
        let potentialOtherInfo = singleLabeledValue(otherContactInfo, label: "other")

        if var contactToUpdate = contact {
            var contactHasBeenUpdated = false

            if let patientName = patient?.name,
               contact?.name != patientName {
                contactHasBeenUpdated = true
                contactToUpdate.name = patientName
            }

            if contact?.address != potentialAddress {
                contactHasBeenUpdated = true
                contactToUpdate.address = potentialAddress
            }

            if contact?.emailAddresses != potentialEmail {
                contactHasBeenUpdated = true
                contactToUpdate.emailAddresses = potentialEmail
            }

            if contact?.messagingNumbers != potentialMessaging {
                contactHasBeenUpdated = true
                contactToUpdate.messagingNumbers = potentialMessaging
            }

            if contact?.phoneNumbers != potentialPhone {
                contactHasBeenUpdated = true
                contactToUpdate.phoneNumbers = potentialPhone
            }

            if contact?.otherContactInfo != potentialOtherInfo {
                contactHasBeenUpdated = true
                contactToUpdate.otherContactInfo = potentialOtherInfo
            }

            if contactHasBeenUpdated,
               let anyContact = try await AppDelegateKey.defaultValue?.store.updateAnyContact(contactToUpdate),
               let updatedContact = anyContact as? OCKContact {
                contact = updatedContact
                Logger.profile.info("Successfully updated contact")
            }

        } else {
            guard let remoteUUID = (try? await Utility.getRemoteClockUUID())?.uuidString else {
                Logger.profile.error("The user currently is not logged in")
                throw AppError.errorString("The user currently is not logged in")
            }

            let patientName = patient?.name ?? PersonNameComponents(givenName: firstName, familyName: lastName)
            var newContact = OCKContact(
                id: remoteUUID,
                name: patientName,
                carePlanUUID: nil
            )
            newContact.address = potentialAddress
            newContact.emailAddresses = potentialEmail
            newContact.messagingNumbers = potentialMessaging
            newContact.phoneNumbers = potentialPhone
            newContact.otherContactInfo = potentialOtherInfo

            if let anyContact = try await AppDelegateKey.defaultValue?.store.addAnyContact(newContact),
               let savedContact = anyContact as? OCKContact {
                contact = savedContact
            }
            Logger.profile.info("Succesffully saved new contact")
        }
    }

}

extension ProfileViewModel {
    private func singleStringArray(_ value: String) -> [String]? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : [trimmed]
    }

    private func singleLabeledValue(_ value: String, label: String) -> [OCKLabeledValue]? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : [OCKLabeledValue(label: label, value: trimmed)]
    }

    static func queryPatient() -> OCKPatientQuery {
        OCKPatientQuery(for: Date())
    }

    static func queryContacts() -> OCKContactQuery {
        OCKContactQuery(for: Date())
    }
}
