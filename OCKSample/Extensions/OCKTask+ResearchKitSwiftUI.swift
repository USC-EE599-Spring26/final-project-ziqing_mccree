//
//  OCKTask+ResearchKitSwiftUI.swift
//  OCKSample
//

import CareKitStore
import Foundation

extension OCKTask {
    var uiKitSurvey: Survey? {
        get {
            guard let surveyInfo = userInfo?[Constants.uiKitSurvey],
                  let surveyType = Survey(rawValue: surveyInfo) else {
                return nil
            }
            return surveyType
        }
        set {
            if userInfo == nil {
                userInfo = .init()
            }
            userInfo?[Constants.uiKitSurvey] = newValue?.rawValue
        }
    }

    var linkURL: String? {
        get { userInfo?[Constants.linkURL] }
        set {
            if userInfo == nil {
                userInfo = .init()
            }
            userInfo?[Constants.linkURL] = newValue
        }
    }

    var featuredMessage: String? {
        get { userInfo?[Constants.featuredMessage] }
        set {
            if userInfo == nil {
                userInfo = .init()
            }
            userInfo?[Constants.featuredMessage] = newValue
        }
    }
}
