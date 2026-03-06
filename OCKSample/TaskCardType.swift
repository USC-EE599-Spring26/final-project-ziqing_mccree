//
//  TaskCardType.swift
//  OCKSample
//
//  Created for EE599 midterm – hypertension tasks.
//

import Foundation

/// High‑level card types exposed to SwiftUI.
/// Internally, these map to the existing `CareKitCard` enum
/// which is persisted on `OCKTask` via `userInfo[Constants.card]`.
enum TaskCardType: CaseIterable, Identifiable {

    case instructions
    case simple
    case checklist
    case buttonLog
    case grid
    case numericProgress
    case labeledValueSwiftUI
    case linkSwiftUI
    case featuredContent

    var id: Self { self }

    var displayName: String {
        switch self {
        case .instructions:
            return "Instructions"
        case .simple:
            return "Simple"
        case .checklist:
            return "Checklist"
        case .buttonLog:
            return "Button Log"
        case .grid:
            return "Grid"
        case .numericProgress:
            return "Numeric Progress"
        case .labeledValueSwiftUI:
            return "Labeled Value (SwiftUI)"
        case .linkSwiftUI:
            return "Link (SwiftUI)"
        case .featuredContent:
            return "Featured Content"
        }
    }

    /// Bridge to the underlying `CareKitCard` used by the store extensions.
    var careKitCard: CareKitCard {
        switch self {
        case .instructions:
            return .instruction
        case .simple:
            return .simple
        case .checklist:
            return .checklist
        case .buttonLog:
            return .button
        case .grid:
            return .grid
        case .numericProgress:
            return .numericProgress
        case .labeledValueSwiftUI:
            return .labeledValue
        case .linkSwiftUI:
            return .link
        case .featuredContent:
            return .featured
        }
    }
}
