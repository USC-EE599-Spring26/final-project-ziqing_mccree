//
//  ManageTasksView.swift
//  OCKSample
//
//  Lists all tasks and allows swipe/tap delete with confirmation.
//

import CareKitStore
import SwiftUI

struct ManageTasksView: View {

    @StateObject private var viewModel: ManageTasksViewModel
    @Environment(\.dismiss) private var dismiss

    init(store: OCKStore, healthKitStore: OCKHealthKitPassthroughStore? = nil) {
        _viewModel = StateObject(wrappedValue: ManageTasksViewModel(store: store, healthKitStore: healthKitStore))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading tasks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.tasks.isEmpty {
                Text("No tasks yet.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.tasks, id: \.id) { task in
                        ManageTaskRow(
                            task: task,
                            onDelete: {
                                viewModel.confirmDelete(task)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.confirmDelete(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadTasks()
        }
        .alert("Delete Task?", isPresented: Binding(
            get: { viewModel.taskToConfirmDelete != nil },
            set: { if !$0 { viewModel.clearDeleteConfirmation() } }
        )) {
            Button("Cancel", role: .cancel) {
                viewModel.clearDeleteConfirmation()
            }
            Button("Delete", role: .destructive) {
                guard let task = viewModel.taskToConfirmDelete else { return }
                viewModel.clearDeleteConfirmation()
                Task {
                    await viewModel.deleteTask(task)
                }
            }
        } message: {
            if let task = viewModel.taskToConfirmDelete {
                Text("“\(task.title ?? task.id)” will be removed. This cannot be undone.")
            }
        }
        .alert(
            viewModel.error?.localizedDescription ?? "Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK") {
                viewModel.clearError()
            }
        }
    }
}

private struct ManageTaskRow: View {
    let task: OCKAnyTask
    let onDelete: () -> Void

    private var title: String {
        if let ockTask = task as? OCKTask { return ockTask.title ?? task.id }
        if let hkTask = task as? OCKHealthKitTask { return hkTask.title ?? task.id }
        return task.id
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(task.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
