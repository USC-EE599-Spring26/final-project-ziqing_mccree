//
//  DailyTaskListViewController.swift
//  OCKSample
//

import CareKitStore
import SwiftUI
import UIKit

final class DailyTaskListViewController: UIViewController {

    struct Row: Identifiable {
        let id: String
        let title: String
        let detail: String?
    }

    private let rows: [Row]

    init(tasks: [any OCKAnyTask]) {
        self.rows = tasks.map { anyTask in
            let id = anyTask.id
            if let task = anyTask as? OCKTask {
                let title = task.title ?? id
                let detail = task.instructions
                return Row(id: id, title: title, detail: detail)
            } else {
                return Row(id: id, title: id, detail: nil)
            }
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear

        let hosting = UIHostingController(
            rootView: DailyTaskListView(
                title: "Hypertension Self-Management",
                rows: rows
            )
        )

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hosting.didMove(toParent: self)
    }
}

private struct DailyTaskListView: View {

    let title: String
    let rows: [DailyTaskListViewController.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)

            if rows.isEmpty {
                Text("No tasks for this day.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.body)
                            .bold()
                        if let detail = row.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)

                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}
