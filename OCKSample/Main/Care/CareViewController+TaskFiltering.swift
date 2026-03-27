//
//  CareViewController+TaskFiltering.swift
//  OCKSample
//
//  Filters out demo/education tasks (e.g. "Benefits of exercising" gym card).
//  Target: OCKSample, OCKVisionSample only (not OCKWatchSample).
//

import CareKitStore
import Foundation

extension CareViewController {

    /// Removes OCKSample demo/education tasks; keeps hypertension and custom tasks.
    func filterOutDemoTasks(_ tasks: [any OCKAnyTask]) -> [any OCKAnyTask] {
        tasks.filter { !Self.isDemoOrEducationTask($0) }
    }

    /// Exclude tasks whose id/title match demo/education keywords.
    private static func isDemoOrEducationTask(_ task: any OCKAnyTask) -> Bool {
        let id = task.id.lowercased()
        let title = ((task as? OCKTask)?.title ?? "").lowercased()
        if title.contains("benefits of exercising") || title.contains("benefits of exercise") {
            return true
        }
        let keywords = ["benefits", "tips", "education", "pregnancy"]
        return keywords.contains(where: { id.contains($0) || title.contains($0) })
    }
}
