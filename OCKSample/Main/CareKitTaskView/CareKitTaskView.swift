//
//  CareKitTaskView.swift
//  OCKSample
//
//  Created by Corey Baker on 2/26/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import SwiftUI

struct CareKitTaskView: View {

	@State var isShowingAlert = false
	@State var isAddingTask = false

	@StateObject var viewModel = CareKitTaskViewModel()
	@State var title = ""
	@State var instructions = ""
	@State var asset = ""
	@State var linkURL = ""
	@State var featuredMessage = ""
	@State var startDate = Date()
	@State var selectedCard: CareKitCard = .checklist
	@State var selectedTaskKind: TaskCreationKind = .task
	@State var selectedHealthKitQuantity: HealthKitQuantityChoice = .heartRate

	var body: some View {
		NavigationView {
			Form {
				Picker("Create", selection: $selectedTaskKind) {
					ForEach(TaskCreationKind.allCases) { kind in
						Text(kind.rawValue).tag(kind)
					}
				}
				.pickerStyle(.segmented)

				TextField("Title", text: $title)
				TextField("Instructions", text: $instructions)
				TextField("Asset (SF Symbol)", text: $asset)
				DatePicker(
					"Start Date & Time",
					selection: $startDate,
					displayedComponents: [.date, .hourAndMinute]
				)

				if selectedTaskKind == .healthKitTask {
					Picker("HealthKit Type", selection: $selectedHealthKitQuantity) {
						ForEach(HealthKitQuantityChoice.allCases) { item in
							Text(item.rawValue).tag(item)
						}
					}
				}

				Picker("Card View", selection: $selectedCard) {
					ForEach(availableCards) { item in
						Text(item.rawValue).tag(item)
					}
				}

				if selectedTaskKind == .task && selectedCard == .link {
					TextField("Resource URL", text: $linkURL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
				}

				if selectedTaskKind == .task && selectedCard == .featured {
					TextField("Featured Message", text: $featuredMessage)
				}

				Section(selectedTaskKind.rawValue) {
					Button("Add") {
						addTask {
							if selectedTaskKind == .task {
								await viewModel.addTask(
									title,
									instructions: instructions,
									cardType: selectedCard,
									asset: asset,
									startDate: startDate,
									linkURL: linkURL,
									featuredMessage: featuredMessage
								)
							} else {
								await viewModel.addHealthKitTask(
									title,
									instructions: instructions,
									cardType: selectedCard,
									asset: asset,
									startDate: startDate,
									quantityChoice: selectedHealthKitQuantity
								)
							}
						}
					}
					.alert(
						"\(selectedTaskKind.rawValue) has been added",
						isPresented: $isShowingAlert
					) {
						Button("OK") {
							isShowingAlert = false
						}
					}
					.disabled(isAddingTask)
				}

				Section("Created Tasks") {
					if viewModel.customTasks.isEmpty {
						Text("No custom tasks yet.")
							.foregroundStyle(.secondary)
					} else {
						ForEach(viewModel.customTasks) { item in
							HStack(alignment: .top, spacing: 12) {
								VStack(alignment: .leading, spacing: 4) {
									Text(item.title)
										.font(.headline)
									Text(item.detail)
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								Spacer()
								Button("Delete", role: .destructive) {
									Task {
										await viewModel.deleteTask(item)
									}
								}
							}
						}
					}
				}
			}
			.navigationTitle("Add Task")
		}
		.task {
			await viewModel.reloadCustomTasks()
		}
		.onAppear {
			if !availableCards.contains(selectedCard) {
				selectedCard = availableCards.first ?? .checklist
			}
		}
		.onChange(of: selectedTaskKind) { _ in
			if !availableCards.contains(selectedCard) {
				selectedCard = availableCards.first ?? .checklist
			}
		}
		.alert(
			viewModel.error?.localizedDescription ?? "Could not save task",
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

	private var availableCards: [CareKitCard] {
		switch selectedTaskKind {
		case .task:
			return [.button, .checklist, .featured, .grid, .instruction, .link, .simple, .survey, .uiKitSurvey, .custom]
		case .healthKitTask:
			return [.numericProgress, .labeledValue]
		}
	}

	func addTask(_ task: @escaping (() async -> Void)) {
		guard !isAddingTask else {
			return
		}
		isAddingTask = true
		Task {
			defer {
				isAddingTask = false
			}
			await task()
			if viewModel.error == nil {
				isShowingAlert = true
			}
		}
	}
}

#Preview {
	CareKitTaskView()
}
