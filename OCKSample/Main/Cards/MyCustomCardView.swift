//
//  MyCustomCardView.swift
//  OCKSample
//
//  Created by Corey Baker on 3/10/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import SwiftUI
import ResearchKitSwiftUI
#if canImport(ResearchKit) && canImport(ResearchKitUI)
import ResearchKit
import ResearchKitUI
#endif

private struct GridTileView: View {
	let title: String
	let value: String

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title.uppercased())
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
			Text(value)
				.font(.subheadline.weight(.medium))
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(Color(uiColor: .secondarySystemBackground))
		)
	}
}

private struct MeasurementSurveyView: View {
	@Environment(\.dismiss) private var dismiss

	let initialResponse: MeasurementSurveyResponse
	let onSave: (MeasurementSurveyResponse) -> Void

	@State private var systolicText: String
	@State private var diastolicText: String

	init(
		initialResponse: MeasurementSurveyResponse,
		onSave: @escaping (MeasurementSurveyResponse) -> Void
	) {
		self.initialResponse = initialResponse
		self.onSave = onSave
		_systolicText = State(initialValue: String(Int(initialResponse.systolic)))
		_diastolicText = State(initialValue: String(Int(initialResponse.diastolic)))
	}

	var body: some View {
		NavigationStack {
			Form {
				TextField("Systolic (mmHg)", text: $systolicText)
					.keyboardType(.numberPad)

				TextField("Diastolic (mmHg)", text: $diastolicText)
					.keyboardType(.numberPad)
			}
			.navigationTitle("Blood Pressure Check")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						guard let response else { return }
						onSave(response)
						dismiss()
					}
					.disabled(response == nil)
				}
			}
		}
	}

	private var response: MeasurementSurveyResponse? {
		guard
			let systolic = Double(systolicText),
			let diastolic = Double(diastolicText)
		else {
			return nil
		}

		return MeasurementSurveyResponse(
			systolic: systolic,
			diastolic: diastolic
		)
	}
}

struct LinkView: View {
	let event: OCKAnyEvent
	let url: URL

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			InformationHeaderView(
				title: Text(event.title),
				information: event.detailText,
				event: event
			)

			event.instructionsText
				.fixedSize(horizontal: false, vertical: true)

			SwiftUI.Link(destination: url) {
				HStack {
					Text("Open Hypertension Resource")
					Spacer()
					Image(systemName: "arrow.up.right.square")
				}
				.fontWeight(.semibold)
				.padding()
				.frame(maxWidth: .infinity)
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(Color.accentColor.opacity(0.15))
				)
			}
			.buttonStyle(NoHighlightStyle())
		}
	}
}

struct OCKFeaturedContentView: View {
	let event: OCKAnyEvent
	let message: String
	let status: String
	let action: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			InformationHeaderView(
				title: Text(event.title),
				information: event.detailText,
				event: event
			)

			event.instructionsText
				.fixedSize(horizontal: false, vertical: true)

			Text(message)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(Color.accentColor)

			Text(status)
				.foregroundStyle(.secondary)

                Button(action: action) {
                    Text("Start Daily Walking Check")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
					.background(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.fill(Color.accentColor)
					)
			}
			.buttonStyle(NoHighlightStyle())
		}
	}
}

#if canImport(ResearchKit) && canImport(ResearchKitUI)
private struct ResearchTaskSheet: UIViewControllerRepresentable {
	let task: ORKTask
	let onFinish: (ORKTaskViewController, ORKTaskFinishReason, Error?) -> Void

	func makeUIViewController(context: Context) -> ORKTaskViewController {
		let controller = ORKTaskViewController(task: task, taskRun: UUID())
		controller.delegate = context.coordinator
		return controller
	}

	func updateUIViewController(_ uiViewController: ORKTaskViewController, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(onFinish: onFinish)
	}

	final class Coordinator: NSObject, ORKTaskViewControllerDelegate {
		let onFinish: (ORKTaskViewController, ORKTaskFinishReason, Error?) -> Void

		init(onFinish: @escaping (ORKTaskViewController, ORKTaskFinishReason, Error?) -> Void) {
			self.onFinish = onFinish
		}

		func taskViewController(
			_ taskViewController: ORKTaskViewController,
			didFinishWith reason: ORKTaskFinishReason,
			error: Error?
		) {
			onFinish(taskViewController, reason, error)
		}
	}
}
#endif

// We use `CareKitEssentialView` to help us with saving new events.
struct MyCustomCardView: CareKitEssentialView {
	@Environment(\.careStore) var store
	@Environment(\.customStyler) var style
	@Environment(\.isCardEnabled) private var isCardEnabled

    let event: OCKAnyEvent
    @State private var isPresentingMeasurementSurvey = false
    @State private var isPresentingResearchTask = false

	var body: some View {
		CardView {
			VStack(alignment: .leading) {
				cardBody
			}
			.padding(isCardEnabled ? [.all] : [])
		}
		.careKitStyle(style)
		.frame(maxWidth: .infinity)
		.padding(.vertical)
		.sheet(isPresented: $isPresentingMeasurementSurvey) {
			MeasurementSurveyView(initialResponse: measurementResponse) { response in
				saveMeasurementResponse(response)
			}
		}
			#if canImport(ResearchKit) && canImport(ResearchKitUI)
			.sheet(isPresented: $isPresentingResearchTask) {
				ResearchTaskSheet(task: featuredResearchTask) { controller, reason, _ in
					Task { @MainActor in
						controller.dismiss(animated: true)
						isPresentingResearchTask = false
					guard reason == .completed else { return }
					await saveActiveTaskOutcome()
				}
			}
		}
		#endif
	}

	@ViewBuilder
	private var cardBody: some View {
		switch cardType {
		case .grid:
			VStack(alignment: .leading, spacing: 12) {
				InformationHeaderView(
					title: Text(event.title),
					information: event.detailText,
					event: event
				)

					event.instructionsText
						.fixedSize(horizontal: false, vertical: true)

					LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
						GridTileView(title: "Systolic", value: formattedBloodPressureValue(for: .systolicValue))
						GridTileView(title: "Diastolic", value: formattedBloodPressureValue(for: .diastolicValue))
						GridTileView(title: "Status", value: isComplete ? "Recorded today" : "Awaiting reading")
						GridTileView(title: "Scheduled", value: event.scheduleSummary)
					}

				Button(action: {
					isPresentingMeasurementSurvey = true
				}) {
					RectangularCompletionView(isComplete: isComplete) {
						Spacer()
						Text(isComplete ? "Update Reading" : "Log Reading")
							.foregroundColor(isComplete ? .accentColor : .white)
							.frame(maxWidth: .infinity)
							.padding()
						Spacer()
					}
				}
				.buttonStyle(NoHighlightStyle())
			}

		case .link:
			if let task = event.task as? OCKTask,
			   let rawURL = task.linkURL,
			   let url = URL(string: rawURL) {
				LinkView(event: event, url: url)
			} else {
				fallbackView
			}

		case .featured:
				OCKFeaturedContentView(
					event: event,
					message: (event.task as? OCKTask)?.featuredMessage
						?? "Use this guided walking check to capture how activity feels today.",
					status: event.outcomeStrings.first ?? "No daily walking check saved yet.",
					action: {
						#if canImport(ResearchKit) && canImport(ResearchKitUI)
						isPresentingResearchTask = true
					#else
					toggleEventCompletion()
					#endif
				}
			)

		default:
			VStack(alignment: .leading) {
				InformationHeaderView(
					title: Text(event.title),
					information: event.detailText,
					event: event
				)

				event.instructionsText
					.fixedSize(horizontal: false, vertical: true)
					.padding(.vertical)

				Button(action: {
					toggleEventCompletion()
				}) {
					RectangularCompletionView(isComplete: isComplete) {
						Spacer()
						Text(buttonText)
							.foregroundColor(foregroundColor)
							.frame(maxWidth: .infinity)
							.padding()
						Spacer()
					}
				}
				.buttonStyle(NoHighlightStyle())
			}
		}
	}

	private var cardType: CareKitCard {
		if let task = event.task as? OCKTask {
			return task.card
		}
		if let task = event.task as? OCKHealthKitTask {
			return task.card
		}
		return .custom
	}

	private var isComplete: Bool {
		event.isComplete
	}

	private var buttonText: LocalizedStringKey {
		isComplete ? "COMPLETED" : "START_TASK"
	}

	private var foregroundColor: Color {
		isComplete ? .accentColor : .white
	}

	private var fallbackView: some View {
		VStack(alignment: .leading) {
			InformationHeaderView(
				title: Text(event.title),
				information: event.detailText,
				event: event
			)
			event.instructionsText
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private var measurementResponse: MeasurementSurveyResponse {
		MeasurementSurveyResponse(
			systolic: bloodPressureValue(for: .systolicValue) ?? MeasurementSurveyResponse.empty.systolic,
			diastolic: bloodPressureValue(for: .diastolicValue) ?? MeasurementSurveyResponse.empty.diastolic
		)
	}

	private func saveMeasurementResponse(_ response: MeasurementSurveyResponse) {
		Task {
			do {
				var systolicValue = OCKOutcomeValue(response.systolic)
				systolicValue.kind = MeasurementSurveyKind.systolicValue.rawValue
				systolicValue.units = "mmHg"

				var diastolicValue = OCKOutcomeValue(response.diastolic)
				diastolicValue.kind = MeasurementSurveyKind.diastolicValue.rawValue
				diastolicValue.units = "mmHg"

				_ = try await saveOutcomeValues(
					[systolicValue, diastolicValue],
					event: event
				)
				NotificationCenter.default.post(
					name: Notification.Name(rawValue: Constants.shouldRefreshView),
					object: nil
				)
			} catch {
				Logger.careKitTask.info("Error saving measurement response: \(error)")
			}
		}
	}

	private func bloodPressureValue(for kind: MeasurementSurveyKind) -> Double? {
		let value = event.answer(kind: kind.rawValue)
		return value > 0 ? value : nil
	}

	private func formattedBloodPressureValue(for kind: MeasurementSurveyKind) -> String {
		guard let value = bloodPressureValue(for: kind) else {
			return "--"
		}
		return "\(Int(value.rounded())) mmHg"
	}

	private func saveActiveTaskOutcome() async {
		do {
			let updatedOutcome = try await saveOutcomeValues(
				[OCKOutcomeValue("Completed daily walking check")],
				event: event
			)
			Logger.careKitTask.info(
				"Updated walk assessment outcome: \(updatedOutcome.values)"
			)
			NotificationCenter.default.post(
				name: Notification.Name(rawValue: Constants.shouldRefreshView),
				object: nil
			)
		} catch {
			Logger.careKitTask.info("Error saving active task outcome: \(error)")
		}
	}

	#if canImport(ResearchKit) && canImport(ResearchKitUI)
	private var featuredResearchTask: ORKTask {
		if let task = event.task as? OCKTask,
		   let survey = task.uiKitSurvey {
			return survey.type().createSurvey()
		}
		return RangeOfMotion().createSurvey()
	}
	#endif

	private func toggleEventCompletion() {
		Task {
			do {
				guard event.isComplete == false else {
					let updatedOutcome = try await saveOutcomeValues([], event: event)
					Logger.careKitTask.info(
						"Updated event by removing outcome values: \(updatedOutcome.values)"
					)
					NotificationCenter.default.post(
						name: Notification.Name(rawValue: Constants.shouldRefreshView),
						object: nil
					)
					return
				}

				let newOutcomeValue = OCKOutcomeValue(true)
				let updatedOutcome = try await saveOutcomeValues(
					[newOutcomeValue],
					event: event
				)
				Logger.careKitTask.info(
					"Updated event by setting outcome values: \(updatedOutcome.values)"
				)
				NotificationCenter.default.post(
					name: Notification.Name(rawValue: Constants.shouldRefreshView),
					object: nil
				)
			} catch {
				Logger.careKitTask.info("Error saving value: \(error)")
			}
		}
	}
}

#if !os(watchOS)
extension MyCustomCardView: EventViewable {
	public init?(
		event: OCKAnyEvent,
		store: any OCKAnyStoreProtocol
	) {
		self.init(event: event)
	}
}
#endif

struct MeasurementResearchCareForm<Content: View>: CareKitEssentialView {
	@Environment(\.careStore) var store
	@Environment(\.dismiss) private var dismiss

	let event: OCKAnyEvent
	@ViewBuilder let steps: () -> Content

	var body: some View {
		ResearchForm(
			id: event.id,
			steps: steps,
			onResearchFormCompletion: { completion in
				switch completion {
				case .completed(let results), .saved(let results):
					save(results)
				case .discarded:
					dismiss()
				default:
					dismiss()
				}
			}
		)
	}

	init(
		event: OCKAnyEvent,
		steps: @escaping () -> Content
	) {
		self.event = event
		self.steps = steps
	}

	private func save(_ results: ResearchFormResult) {
		let outcomeValues = createOutcomeValues(from: results)

		Task {
			do {
				_ = try await saveOutcomeValues(outcomeValues, event: event)
				NotificationCenter.default.post(
					name: Notification.Name(rawValue: Constants.shouldRefreshView),
					object: nil
				)
				dismiss()
			} catch {
				Logger.careKitTask.error("Could not save blood pressure survey results: \(error)")
				dismiss()
			}
		}
	}

	private func createOutcomeValues(from results: ResearchFormResult) -> [OCKOutcomeValue] {
		results
			.compactMap { result -> [OCKOutcomeValue]? in
				do {
					return try result.convertToOCKOutcomeValues()
				} catch {
					Logger.careKitTask.error("Cannot convert result to blood pressure outcomes: \(error)")
					return nil
				}
			}
			.flatMap { $0 }
			.map { value in
				var updatedValue = value
				if updatedValue.kind == MeasurementSurveyKind.systolicValue.rawValue
					|| updatedValue.kind == MeasurementSurveyKind.diastolicValue.rawValue {
					updatedValue.units = "mmHg"
				}
				return updatedValue
			}
	}
}

#if !os(watchOS)
extension MeasurementResearchCareForm: EventWithContentViewable {
	init?(
		event: OCKAnyEvent,
		store: any OCKAnyStoreProtocol,
		content: @escaping () -> Content
	) {
		self.init(event: event, steps: content)
	}
}
#endif

private struct MeasurementResearchSurveyView<Content: View>: View {
	@Environment(\.careKitStyle) private var style
	@Environment(\.isCardEnabled) private var isCardEnabled
	@State private var isPresented = false

	let event: OCKAnyEvent
	@ViewBuilder let form: () -> Content

	var body: some View {
		CardView {
			VStack(alignment: .leading) {
				InformationHeaderView(
					title: Text(event.title),
					information: event.detailText,
					event: event
				)

				event.instructionsText
					.fixedSize(horizontal: false, vertical: true)

				if !outcomeSummary.isEmpty {
					VStack(alignment: .leading, spacing: 6) {
						ForEach(outcomeSummary, id: \.self) { line in
							Text(line)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
					.padding(.top, 12)
				}

				VStack(alignment: .center) {
					Button(action: {
						isPresented.toggle()
					}) {
						RectangularCompletionView(isComplete: event.isComplete) {
							HStack {
								Spacer()
								Text(event.isComplete ? "Completed" : "Start Survey")
									.foregroundColor(event.isComplete ? .accentColor : .white)
									.frame(maxWidth: .infinity)
								Spacer()
							}
							.padding()
						}
					}
					.buttonStyle(NoHighlightStyle())
				}
				.padding(.vertical)
			}
			.padding(isCardEnabled ? [.all] : [])
		}
		.careKitStyle(style)
		.frame(maxWidth: .infinity)
		.sheet(isPresented: $isPresented) {
			MeasurementResearchCareForm(
				event: event,
				steps: form
			)
		}
	}

	init(
		event: OCKAnyEvent,
		form: @escaping () -> Content
	) {
		self.event = event
		self.form = form
	}

	private var outcomeSummary: [String] {
		guard event.isComplete else {
			return []
		}

		let systolicText = bloodPressureSummary(
			kind: MeasurementSurveyKind.systolicValue,
			label: "Systolic"
		)
		let diastolicText = bloodPressureSummary(
			kind: MeasurementSurveyKind.diastolicValue,
			label: "Diastolic"
		)

		return [
			systolicText,
			diastolicText
		].compactMap { $0 }
	}

	private func bloodPressureSummary(
		kind: MeasurementSurveyKind,
		label: String
	) -> String? {
		let value = event.answer(kind: kind.rawValue)
		guard value > 0 else {
			return nil
		}
		return "\(label): \(Int(value.rounded())) mmHg"
	}
}

#if !os(watchOS)
extension MeasurementResearchSurveyView: EventWithContentViewable {
	init?(
		event: OCKAnyEvent,
		store: any OCKAnyStoreProtocol,
		content: @escaping () -> Content
	) {
		self.init(event: event, form: content)
	}
}
#endif

private enum HealthKitCardState {
	case permissionRequired
	case noDataYet
	case readFromAppleHealth

	var title: String {
		switch self {
		case .permissionRequired:
			return "Permission Required"
		case .noDataYet:
			return "No Data Yet"
		case .readFromAppleHealth:
			return "Read from Apple Health"
		}
	}

	var color: Color {
		switch self {
		case .permissionRequired:
			return .orange
		case .noDataYet:
			return .secondary
		case .readFromAppleHealth:
			return .accentColor
		}
	}

	var detail: String {
		switch self {
		case .permissionRequired:
			return "Allow Apple Health access to show today's heart data in this card."
		case .noDataYet:
			return "No matching Apple Health reading is available for today yet."
		case .readFromAppleHealth:
			return "This card is displaying the latest reading available from Apple Health."
		}
	}
}

private struct HealthKitStatusBadge: View {
	let state: HealthKitCardState

	var body: some View {
		Text(state.title)
			.font(.caption.weight(.semibold))
			.foregroundStyle(state.color)
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(
				Capsule(style: .circular)
					.fill(state.color.opacity(0.12))
			)
	}
}

struct NumericProgressStatusCardView: View {
	let event: OCKAnyEvent

	private var state: HealthKitCardState {
		healthKitCardState(for: event)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HealthKitStatusBadge(state: state)
			Text(state.detail)
				.font(.footnote)
				.foregroundStyle(.secondary)
			NumericProgressTaskView(event: event)
		}
	}
}

struct LabeledValueStatusCardView: View {
	let event: OCKAnyEvent

	private var state: HealthKitCardState {
		healthKitCardState(for: event)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HealthKitStatusBadge(state: state)
			Text(state.detail)
				.font(.footnote)
				.foregroundStyle(.secondary)
			LabeledValueTaskView(event: event)
		}
	}
}

#if !os(watchOS)
extension NumericProgressStatusCardView: EventViewable {
	public init?(
		event: OCKAnyEvent,
		store: any OCKAnyStoreProtocol
	) {
		self.init(event: event)
	}
}

extension LabeledValueStatusCardView: EventViewable {
	public init?(
		event: OCKAnyEvent,
		store: any OCKAnyStoreProtocol
	) {
		self.init(event: event)
	}
}
#endif

private func healthKitCardState(for event: OCKAnyEvent) -> HealthKitCardState {
	let hasRequestedPermissions = UserDefaults.standard.bool(
		forKey: Constants.healthPermissionsRequestedKey
	)

	guard hasRequestedPermissions else {
		return .permissionRequired
	}

	guard let outcome = event.outcome, outcome.values.isEmpty == false else {
		return .noDataYet
	}

	return .readFromAppleHealth
}

struct ResearchSurveyCardView: View {
	@Environment(\.careKitStyle) private var style
	@Environment(\.isCardEnabled) private var isCardEnabled

	let event: OCKAnyEvent
	@State private var isPresented = false

	var body: some View {
		CardView {
			VStack(alignment: .leading) {
				InformationHeaderView(
					title: Text(event.title),
					information: event.detailText,
					event: event
				)

				event.instructionsText
					.fixedSize(horizontal: false, vertical: true)

				if !outcomeSummary.isEmpty {
					VStack(alignment: .leading, spacing: 6) {
						ForEach(outcomeSummary, id: \.self) { line in
							Text(line)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
					.padding(.top, 12)
				}

				VStack(alignment: .center) {
					Button(action: {
						isPresented = true
					}) {
						RectangularCompletionView(isComplete: event.isComplete) {
							HStack {
								Spacer()
								Text(event.isComplete ? "Completed" : "Start Survey")
									.foregroundColor(event.isComplete ? .accentColor : .white)
									.frame(maxWidth: .infinity)
								Spacer()
							}
							.padding()
						}
					}
					.buttonStyle(NoHighlightStyle())
				}
				.padding(.vertical)
			}
			.padding(isCardEnabled ? [.all] : [])
		}
		.careKitStyle(style)
		.frame(maxWidth: .infinity)
		.fixedSize(horizontal: false, vertical: true)
		.padding(.vertical)
		.sheet(isPresented: $isPresented) {
			if let task = event.task as? OCKTask,
			   let steps = task.surveySteps {
				if event.task.id == AppTaskID.bpMeasurement {
					MeasurementResearchCareForm(event: event) {
						ForEach(steps) { step in
							ResearchFormStep(
								title: task.title ?? task.id,
								subtitle: task.instructions
							) {
								ForEach(step.questions) { question in
									question.view()
								}
							}
						}
					}
				} else {
					ResearchCareForm(event: event) {
						ForEach(steps) { step in
							ResearchFormStep(
								title: task.title ?? task.id,
								subtitle: task.instructions
							) {
								ForEach(step.questions) { question in
									question.view()
								}
							}
						}
					}
				}
			}
		}
	}

	private var outcomeSummary: [String] {
		if event.task.id == AppTaskID.bpMeasurement {
			guard event.isComplete else {
				return []
			}
			let systolicText = bloodPressureSummary(
				kind: MeasurementSurveyKind.systolicValue,
				label: "Systolic"
			)
			let diastolicText = bloodPressureSummary(
				kind: MeasurementSurveyKind.diastolicValue,
				label: "Diastolic"
			)

			return [
				systolicText,
				diastolicText
			].compactMap { $0 }
		}
		return event.outcomeStrings
	}

	private func bloodPressureSummary(
		kind: MeasurementSurveyKind,
		label: String
	) -> String? {
		let value = event.answer(kind: kind.rawValue)
		guard value > 0 else {
			return nil
		}
		return "\(label): \(Int(value.rounded())) mmHg"
	}
}

#if !os(watchOS)
extension ResearchSurveyCardView: EventViewable {
	public init?(
		event: OCKAnyEvent,
		store: any OCKAnyStoreProtocol
	) {
		self.init(event: event)
	}
}
#endif

struct MyCustomCardView_Previews: PreviewProvider {
	static var store = Utility.createPreviewStore()
	static var query: OCKEventQuery {
		var query = OCKEventQuery(for: Date())
		query.taskIDs = [AppTaskID.bpMeasurement]
		return query
	}

	static var previews: some View {
		VStack {
			@CareStoreFetchRequest(query: query) var events
			if let event = events.latest.first {
				MyCustomCardView(event: event.result)
			}
		}
		.environment(\.careStore, store)
		.padding()
	}
}
