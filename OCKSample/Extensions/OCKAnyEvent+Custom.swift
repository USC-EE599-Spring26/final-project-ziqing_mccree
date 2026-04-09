//
//  OCKAnyEvent+Custom.swift
//  OCKSample
//

import CareKitStore
import Foundation

extension OCKAnyOutcome {
    var stringValuesOnly: [String] {
        values.compactMap(\.stringValue)
    }
}

extension OCKAnyEvent {
    func answer(kind: String) -> Double {
        let values = outcome?.values ?? []
        let match = values.first(where: { $0.kind == kind })
        return match?.doubleValue ?? 0
    }

    func textAnswer(kind: String) -> String {
        let values = outcome?.values ?? []
        let match = values.first(where: { $0.kind == kind })
        return match?.stringValue ?? ""
    }

    var outcomeStrings: [String] {
        outcome?.stringValuesOnly ?? []
    }

    var scheduleSummary: String {
        let start = scheduleEvent.start
        let end = scheduleEvent.end
        let calendar = Calendar.current

        if calendar.isDate(start, inSameDayAs: end),
           calendar.component(.hour, from: start) == 0,
           calendar.component(.minute, from: start) == 0,
           end.timeIntervalSince(start) >= 60 * 60 * 23 {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: start)
    }
}
