//
//  AddTaskView.swift
//  OCKSample
//
//  Created for EE599 midterm – hypertension tasks.
//

import CareKitStore
import SwiftUI

struct AddTaskView: View {

    // MARK: Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: View model

    @StateObject private var viewModel: AddTaskViewModel

    // MARK: Init

    init(store: OCKStore, healthKitStore: OCKHealthKitPassthroughStore? = nil) {
        _viewModel = StateObject(wrappedValue: AddTaskViewModel(store: store, healthKitStore: healthKitStore))
    }

    // MARK: Body

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Instructions", text: $viewModel.instructions)
                    TextField("SF Symbol (optional)", text: $viewModel.asset)
                }

                Section("Task Kind") {
                    Picker("Kind", selection: $viewModel.taskKind) {
                        ForEach(AddTaskKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    if viewModel.taskKind == .healthKit {
                        Picker("HealthKit Quantity", selection: $viewModel.healthKitQuantity) {
                            ForEach(HealthKitQuantityChoice.allCases) { choice in
                                Text(choice.rawValue).tag(choice)
                            }
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker(
                        "Start Date & Time",
                        selection: $viewModel.startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Card Type") {
                    Picker("Card Type", selection: $viewModel.selectedCardType) {
                        ForEach(TaskCardType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            let succeeded = await viewModel.saveTask()
                            if succeeded {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save Task")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(
                viewModel.error?.localizedDescription ?? "Error",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.error = nil } }
                )
            ) {
                Button("OK") {
                    viewModel.error = nil
                }
            }
        }
    }
}
