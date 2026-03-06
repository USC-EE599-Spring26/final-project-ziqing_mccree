//
//  CareViewController+Cards.swift
//  OCKSample
//
//  Dynamic card rendering by stored card type (CareKitCard).
//  Uses only UIKit task view controllers and a plain SwiftUI placeholder for SwiftUI card types.
//

import CareKit
import CareKitStore
import CareKitUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private struct TaskCardPlaceholderView: View {
    let title: String
    let subtitle: String
    let assetName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let name = assetName, !name.isEmpty {
                Image(systemName: name)
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .allowsHitTesting(false)
    }
}

extension CareViewController {

    /// Subtitle string for SwiftUI placeholder cards (labeledValue, link, featured).
    private static func subtitleForSwiftUICardType(_ cardType: CareKitCard) -> String {
        switch cardType {
        case .labeledValue: return "Labeled Value"
        case .link: return "Link"
        case .featured: return "Featured Content"
        case .instruction, .simple, .checklist, .button, .grid, .numericProgress: return ""
        }
    }

    /// Creates view controllers for an OCKTask based on its stored card type.
    /// Returns nil if the task has no card or the card type is unknown.
    func makeControllersForCardType(
        task: OCKTask,
        query: OCKEventQuery
    ) -> [UIViewController]? {
        var taskQuery = query
        taskQuery.taskIDs = [task.id]

        let cardType = task.card
        #if canImport(UIKit) && canImport(CareKitUI)
        switch cardType {
        case .instruction:
            let viewController = OCKInstructionsTaskViewController(query: taskQuery, store: store)
            return [viewController]

        case .simple:
            let viewController = OCKSimpleTaskViewController(query: taskQuery, store: store)
            return [viewController]

        case .checklist:
            let viewController = OCKChecklistTaskViewController(query: taskQuery, store: store)
            return [viewController]

        case .button:
            let viewController = OCKButtonLogTaskViewController(query: taskQuery, store: store)
            return [viewController]

        case .grid:
            let viewController = OCKSimpleTaskViewController(query: taskQuery, store: store)
            return [viewController]

        case .numericProgress:
            let viewController = OCKSimpleTaskViewController(query: taskQuery, store: store)
            return [viewController]

        case .labeledValue, .link, .featured:
            let subtitle = Self.subtitleForSwiftUICardType(cardType)
            let view = TaskCardPlaceholderView(
                title: task.title ?? "Task",
                subtitle: subtitle,
                assetName: task.asset
            )
            let hosting = UIHostingController(rootView: view)
            hosting.view.backgroundColor = .clear
            hosting.view.isUserInteractionEnabled = false
            return [hosting]
        }
        #else
        let view = TaskCardPlaceholderView(
            title: task.title ?? "Task",
            subtitle: "Task",
            assetName: task.asset
        )
        return [UIHostingController(rootView: view)]
        #endif
    }

    func makeInstructionsFallbackCard(
        task: OCKTask
    ) -> [UIViewController] {
        #if canImport(UIKit) && canImport(CareKitUI)
        let title = task.title ?? "Hypertension Self-Management"

        let label = UILabel()
        label.text = title
        label.textAlignment = .center
        label.numberOfLines = 0

        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        label.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor)
        ])

        return [viewController]
        #else
        let title = task.title ?? "Hypertension Self-Management"
        let view = TaskCardPlaceholderView(title: title, subtitle: "", assetName: task.asset)
        return [UIHostingController(rootView: view)]
        #endif
    }
}
