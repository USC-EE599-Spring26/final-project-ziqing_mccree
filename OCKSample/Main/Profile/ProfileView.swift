//
//  ProfileView.swift
//  OCKSample
//
//  Created by Corey Baker on 11/24/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitStore
import CareKitUI
import os.log
import SwiftUI

struct ProfileView: View {
    @CareStoreFetchRequest(query: ProfileViewModel.queryPatient()) private var patients
    @CareStoreFetchRequest(query: ProfileViewModel.queryContacts()) private var contacts
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject var loginViewModel: LoginViewModel
    @State var isPresentingAddTask = false

    var body: some View {
        NavigationView {
            VStack {
                VStack {
#if os(iOS)
                    ProfileImageView(viewModel: viewModel)
#endif
                    Form {
                        Section(header: Text("About")) {
                            TextField("First Name", text: $viewModel.firstName)
                            TextField("Last Name", text: $viewModel.lastName)
                            DatePicker(
                                "Birthday",
                                selection: $viewModel.birthday,
                                displayedComponents: [DatePickerComponents.date]
                            )
                            TextField("Allergies", text: $viewModel.allergies)
                        }

                        Section(header: Text("Contact")) {
                            TextField("Street", text: $viewModel.street)
                            TextField("City", text: $viewModel.city)
                            TextField("State", text: $viewModel.state)
                            TextField("Postal code", text: $viewModel.zipcode)
                            TextField("Country", text: $viewModel.country)
                            TextField("Email", text: $viewModel.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                            TextField("Messaging number", text: $viewModel.messagingNumber)
                                .keyboardType(.phonePad)
                            TextField("Phone number", text: $viewModel.phoneNumber)
                                .keyboardType(.phonePad)
                            TextField("Other contact info", text: $viewModel.otherContactInfo)
                        }
                    }
                }

                Button(action: {
                    Task {
                        await viewModel.saveProfile()
                    }
                }, label: {
                    Text("Save Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 300, height: 50)
                })
                .background(Color(.green))
                .cornerRadius(15)

                Button(action: {
                    Task {
                        await loginViewModel.logout()
                    }
                }, label: {
                    Text("Log Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 300, height: 50)
                })
                .background(Color(.red))
                .cornerRadius(15)
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("My Contact") {
                        viewModel.isPresentingContact = true
                    }
                    .sheet(isPresented: $viewModel.isPresentingContact) {
                        MyContactView()
                    }
                }
#endif
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Task") {
                        isPresentingAddTask = true
                    }
                    .sheet(isPresented: $isPresentingAddTask) {
                        CareKitTaskView()
                    }
                }
            }
#if os(iOS)
            .sheet(isPresented: $viewModel.isPresentingImagePicker) {
                ImagePicker(image: $viewModel.profileUIImage)
            }
#endif
            .alert(isPresented: $viewModel.isShowingSaveAlert) {
                Alert(
                    title: Text("Update"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("Ok"), action: {
                        viewModel.isShowingSaveAlert = false
                    })
                )
            }
        }
        .onReceive(patients.publisher) { publishedPatient in
            viewModel.updatePatient(publishedPatient.result)
        }
        .onReceive(contacts.publisher) { publishedContact in
            viewModel.updateContact(publishedContact.result)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(loginViewModel: .init())
            .accentColor(Color.accentColor)
            .environment(\.careStore, Utility.createPreviewStore())
    }
}
