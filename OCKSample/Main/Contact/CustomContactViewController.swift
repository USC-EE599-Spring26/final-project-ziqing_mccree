//
//  CustomContactViewController.swift
//  OCKSample
//
//  Created by Corey Baker on 4/2/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

#if os(iOS)
import CareKit
import CareKitStore
import Contacts
import ContactsUI
import ParseCareKit
import ParseSwift
import UIKit
import os.log

class CustomContactViewController: OCKListViewController, @unchecked Sendable {

    fileprivate var allContacts = [OCKContact]()
    var contacts: [CareStoreFetchedResult<OCKAnyContact>]? {
        didSet {
            reloadView()
        }
    }

    fileprivate let store: OCKAnyStoreProtocol
    fileprivate let viewSynchronizer: OCKSimpleContactViewSynchronizer

    init(
        store: OCKAnyStoreProtocol,
        contacts: [CareStoreFetchedResult<OCKAnyContact>]? = nil,
        viewSynchronizer: OCKSimpleContactViewSynchronizer
    ) {
        self.store = store
        self.contacts = contacts
        self.viewSynchronizer = viewSynchronizer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.searchBarStyle = UISearchBar.Style.prominent
        searchController.searchBar.placeholder = " Search Contacts"
        searchController.searchBar.showsCancelButton = true
        searchController.searchBar.delegate = self
        navigationItem.searchController = searchController
        definesPresentationContext = true

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(presentContactsListViewController)
        )

        reloadView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadView()
    }

    @objc private func presentContactsListViewController() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        contactPicker.predicateForEnablingContact = NSPredicate(
            format: "phoneNumbers.@count > 0 || emailAddresses.@count > 0"
        )
        present(contactPicker, animated: true, completion: nil)
    }

    func clearAndKeepSearchBar() {
        clear()
    }

    func reloadView() {
        Task {
            try? await updateContacts()
        }
    }

    @MainActor
    func updateContacts() async throws {
        guard (try? await User.current()) != nil else {
            Logger.contact.error("User not logged in")
            return
        }

        guard let personUUIDString = (try? await Utility.getRemoteClockUUID())?.uuidString else {
            Logger.contact.error("Could not get logged in personUUID")
            return
        }

        guard let contacts = contacts else {
            Logger.contact.error("No contacts to display")
            return
        }

        let filteredContacts = contacts.filter { convertedContact in
            Logger.contact.info("Contact filtered: \(convertedContact.id)")
            return convertedContact.id != personUUIDString
        }

        clearAndKeepSearchBar()
        allContacts = filteredContacts.compactMap { $0.result as? OCKContact }
        displayContacts(allContacts)
    }

    @MainActor
    func displayContacts(_ contacts: [OCKAnyContact]) {
        for contact in contacts {
            var query = OCKContactQuery(for: Date())
            query.ids = [contact.id]
            query.limit = 1
            let contactViewController = OCKSimpleContactViewController(
                query: query,
                store: store,
                viewSynchronizer: viewSynchronizer
            )
            appendViewController(contactViewController, animated: false)
        }
    }

    func convertDeviceContacts(_ contact: CNContact) -> OCKAnyContact {
        var convertedContact = OCKContact(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            carePlanUUID: nil
        )
        convertedContact.title = contact.jobTitle

        var emails = [OCKLabeledValue]()
        contact.emailAddresses.forEach {
            emails.append(OCKLabeledValue(label: $0.label ?? "email", value: $0.value as String))
        }
        convertedContact.emailAddresses = emails.isEmpty ? nil : emails

        var phoneNumbers = [OCKLabeledValue]()
        contact.phoneNumbers.forEach {
            phoneNumbers.append(
                OCKLabeledValue(label: $0.label ?? "phone", value: $0.value.stringValue)
            )
        }
        convertedContact.phoneNumbers = phoneNumbers.isEmpty ? nil : phoneNumbers
        convertedContact.messagingNumbers = phoneNumbers.isEmpty ? nil : phoneNumbers

        var otherContactInfo = [OCKLabeledValue]()
        if !contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            otherContactInfo.append(
                OCKLabeledValue(label: "organization", value: contact.organizationName)
            )
        }
        if !contact.jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            otherContactInfo.append(
                OCKLabeledValue(label: "jobTitle", value: contact.jobTitle)
            )
        }
        convertedContact.otherContactInfo = otherContactInfo.isEmpty ? nil : otherContactInfo

        if let address = contact.postalAddresses.first {
            convertedContact.address = OCKPostalAddress(
                street: address.value.street,
                city: address.value.city,
                state: address.value.state,
                postalCode: address.value.postalCode,
                country: address.value.country
            )
        }

        return convertedContact
    }
}

extension CustomContactViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        Logger.contact.debug("Searching text is '\(searchText)'")

        if searchBar.text?.isEmpty != false {
            clearAndKeepSearchBar()
            displayContacts(allContacts)
            return
        }

        clearAndKeepSearchBar()
        let query = searchText.lowercased()
        let filteredContacts = allContacts.filter { contact in
            let givenName = contact.name.givenName?.lowercased() ?? ""
            let familyName = contact.name.familyName?.lowercased() ?? ""
            let fullName = "\(givenName) \(familyName)"
            let title = (contact.title ?? "").lowercased()
            return givenName.contains(query)
                || familyName.contains(query)
                || fullName.contains(query)
                || title.contains(query)
        }
        displayContacts(filteredContacts)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clearAndKeepSearchBar()
        displayContacts(allContacts)
    }
}

extension CustomContactViewController: @MainActor CNContactPickerDelegate {
    func contactPicker(
        _ picker: CNContactPickerViewController,
        didSelect contact: CNContact
    ) {
        let contactToAdd = convertDeviceContacts(contact)
        let allContacts = self.allContacts

        Task {
            guard (try? await User.current()) != nil else {
                Logger.contact.error("User not logged in")
                return
            }

            if !allContacts.contains(where: { $0.id == contactToAdd.id }) {
                do {
                    _ = try await store.addAnyContact(contactToAdd)
                } catch {
                    Logger.contact.error("Could not add contact: \(error.localizedDescription)")
                }
            }
        }
    }

    func contactPicker(
        _ picker: CNContactPickerViewController,
        didSelect contacts: [CNContact]
    ) {
        let newContacts = contacts.compactMap {
            convertDeviceContacts($0)
        }
        let allContacts = self.allContacts

        Task {
            guard (try? await User.current()) != nil else {
                Logger.contact.error("User not logged in")
                return
            }

            var contactsToAdd = [OCKAnyContact]()
            for newContact in newContacts where allContacts.first(where: { $0.id == newContact.id }) == nil {
                contactsToAdd.append(newContact)
            }

            do {
                _ = try await store.addAnyContacts(contactsToAdd)
            } catch {
                Logger.contact.error("Could not add contacts: \(error.localizedDescription)")
            }
        }
    }
}
#endif
