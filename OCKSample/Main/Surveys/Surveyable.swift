//
//  Surveyable.swift
//  OCKSample
//

import Foundation
import CareKitStore
#if canImport(ResearchKit)
import ResearchKit
#endif

protocol Surveyable {
    static var surveyType: Survey { get }
    static func identifier() -> String
    #if canImport(ResearchKit)
    func createSurvey() -> ORKTask
    func extractAnswers(_ result: ORKTaskResult) -> [OCKOutcomeValue]?
    #endif
}

extension Surveyable {
    static func identifier() -> String {
        surveyType.rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    func identifier() -> String {
        Self.identifier()
    }
}
